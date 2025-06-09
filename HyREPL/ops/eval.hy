(import io
        types
        sys
        threading
        ctypes
        traceback
        logging
        queue [Queue]
        io [StringIO]
        hy.reader [HyReader]
        hy.reader.exceptions [LexException]
        hy.core.hy-repr [hy-repr]
        hy.errors [hy-exc-filter]
        toolz [first second last]
        hyrule [assoc]
        HyREPL.ops.utils [ops find-op])

(require HyREPL.ops.utils [defop])

(defclass HyReplSTDIN [Queue]
  ;; """This is hack to override sys.stdin."""
  (defn __init__ [self write]
    (.__init__ (super))
    (setv self.writer write)
    None)

  (defn readline [self]
    (self.writer {"status" ["need-input"]})
    (.join self)
    (.get self)))

(defn async-raise [tid exc]
  ;; https://zenn.dev/bluesilvercat/articles/c492339d1cd20c
  (logging.debug "InterruptibleEval.async-raise: tid=%s, exc=%s" tid exc)
  (let [res (ctypes.pythonapi.PyThreadState-SetAsyncExc (ctypes.c-long tid)
                                                        (ctypes.py-object exc))]
    (cond
      (= res 0) (raise (ValueError (.format "Thread ID does not exist: {}" tid)))
      (> res 1)
      (do
        (ctypes.pythonapi.PyThreadState-SetAsyncExc tid 0)
        (raise (SystemError "PyThreadState-SetAsyncExc failed"))))))

(defclass StreamingOut [io.TextIOBase]
  "A file-like object that streams writes to an nREPL client."
  (defn __init__ [self writer]
    "Initializes with the writer function to send messages."
    (setv self.writer writer))

  (defn write [self text]
    "Writes text by sending it immediately through the writer."
    (when (> (len text) 0)
      ;; Send received text as an "out" message
      (self.writer {"out" text}))
    ;; Python's write method must return the number of bytes written
    (len text))

  (defn flush [self]
    "Flush is a no-op since writes are sent immediately."
    ;; Nothing to do with this implementation.
    None))

(defclass InterruptibleEval [threading.Thread]
  ;; """Repl simulation. This is a thread so hangs don't block everything."""
  (defn __init__ [self msg session writer]
    (.__init__ (super))
    (setv self.reader (HyReader))
    (setv self.writer writer)
    (setv self.msg msg)
    (setv self.session session)
    (setv sys.stdin (HyReplSTDIN writer))
    ;; we're locked under self.session.lock, so modification is safe
    (setv self.session.eval-id (.get msg "id"))
    None)

  (defn raise-exc [self exc]
    (logging.debug "InterruptibleEval.raise-exc: exc=%s, threads=%s" exc (threading.enumerate))
    (assert (.is-alive self) "Trying to raise exception on dead thread!")
    (for [tobj (threading.enumerate)]
      (when (is tobj self)
        (async-raise (. tobj ident) exc)
        (break))))

  (defn terminate [self]
    (.raise-exc self SystemExit))

  (defn tokenize [self code]
    (setv gen (self.reader.parse (StringIO code)))
    (setv exprs (lfor expr gen expr))
    (if (= (len exprs) 1)
        (get exprs 0)
        ;; When the input contains multiple expressions, implicitly wrap them in a do macro
        (do
          (exprs.insert 0 'do)
          (hy.models.Expression exprs))))

  (defn run [self]
    (let [code (get self.msg "code")
          oldout sys.stdout]
      (try
        (setv self.expr (.tokenize self code))
        (except [e Exception]
          (.format-excp self (sys.exc-info))
          (self.writer {"status" ["done"] "id" (.get self.msg "id")}))
        (else
          (let [p (StringIO)]
            (try
              (setv sys.stdout (StreamingOut self.writer))
              (logging.debug "InterruptibleEval.run: msg=%s, expr=%s"
                             self.msg (hy-repr self.expr))
              (.write p (str (hy-repr (hy.eval self.expr
                                               :locals self.session.locals
                                               :module self.session.module))))
              (except [e Exception]
                ;; Reset standard output even in the event of an error
                (setv sys.stdout oldout)
                (.format-excp self (sys.exc-info)))
              (else
                (self.writer {"value" (.getvalue p)
                              "ns" (.get self.msg "ns" "Hy")}))))
          ;; Reset standard output even on normal termination
          (setv sys.stdout oldout)
          (self.writer {"status" ["done"]})))))

  (defn format-excp [self trace]
    (let [exc-type (first trace)
          exc-value (second trace)
          exc-traceback (get trace 2)]
      (setv self.session.last-traceback exc-traceback)
      (self.writer {"status" ["eval-error"]
                    "ex" (. exc-type __name__)
                    "root-ex" (. exc-type __name__)
                    "id" (.get self.msg "id")})
      (when (isinstance exc-value LexException)
        (logging.debug "InterruptibleEval.format-excp : text=`%s`, msg=%s" exc-value.text exc-value.msg)
        (when (is exc-value.text None)
          (setv exc-value.text ""))
        (setv exc-value (.format "LexException: {}" exc-value.msg)))
      (self.writer {"err" (hy-exc-filter #* trace)}))))

(defop "eval" [session msg transport]
  {"doc" "Evaluates code."
   "requires" {"code" "The code to be evaluated"}
   "optional" {"session" (+ "The ID of the session in which the code will"
                            " be evaluated. If absent, a new session will"
                            " be generated")
               "id" "An opaque message ID that will be included in the response"}
   "returns" {"ex" "Type of the exception thrown, if any. If present, `value` will be absent."
              "ns" (+ "The current namespace after the evaluation of `code`."
                      " For HyREPL, this will always be `Hy`.")
              "root-ex" "Same as `ex`"
              "value" (+ "The values returned by `code` if execution was"
                         " successful. Absent if `ex` and `root-ex` are"
                         " present")}}
  (logging.debug "eval op: session=%s, msg=%s, transport=%s" session msg transport)
  (with [session.lock]
    (when (and (is-not session.repl None) (.is-alive session.repl))
      (.join session.repl))
    (setv session.repl
          (InterruptibleEval msg session
            ;; writer
            (fn [message]
              (logging.debug "InterruptibleEval writer: message=%s, stdin-id=%s" message session.stdin-id)
              (if session.stdin-id
                  (do
                    (assoc message "id" session.stdin-id)
                    (setv session.stdin-id None))
                  (assoc message "id" (.get msg "id")))
              (.write session message transport))))
    (.start session.repl)))

(defop "interrupt" [session msg transport]
  {"doc" "Interrupt a running eval"
   "requires" {"session" "The session id used to start the eval to be interrupted"}
   "optional" {"interrupt-id" "The ID of the eval to interrupt"}
   "returns" {"status" (+ "\"interrupted\" if an eval was interrupted,"
                          " \"session-idle\" if the session is not"
                          " evaluating code at  the moment, "
                          "\"interrupt-id-mismatch\" if the session is"
                          " currently evaluating code with a different ID"
                          " than the" "specified \"interrupt-id\" value")}}
  (.write session
          {"id" (.get msg "interrupt-id")
           "status" (with [session.lock]
                      ["done"
                       (cond
                         (or (is session.repl None) (not (.is-alive session.repl)))
                         "session-idle"

                         (!= session.eval-id (.get msg "interrupt-id"))
                         "interrupt-id-mismatch"

                         True
                         (do
                           (.terminate session.repl)
                           (.join session.repl)
                           (logging.debug "interrupt: interrupted")
                           "interrupted"))])}
          transport)
  (.write session
          {"status" ["done"]
           "id" (.get msg "id")}
          transport))

(defop "load-file" [session msg transport]
  {"doc" "Loads a body of code. Delegates to `eval`"
   "requires" {"file" "full body of code"}
   "optional" {"file-name" "name of the source file, for example for exceptions"
               "file-path" "path to the source file"}
   "returns" (get ops "eval" :desc "returns")}
  (let [code (get (-> (get msg "file") (.split " " 2)) 2)]
    (print (.strip code) :file sys.stderr)
    (assoc msg "code" code)
    (del (get msg "file"))
    ((find-op "eval") session msg transport)))
