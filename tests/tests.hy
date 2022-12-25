(import os queue socket sys threading time)
(import io [StringIO]
        socketserver [ThreadingMixIn UnixStreamServer])

(import HyREPL.bencode [encode decode decode-multiple])
(import HyREPL.server [ReplRequestHandler])
(import toolz [first second nth])
(require hyrule [->])

(defreader b
  (setv expr (.parse-one-form &reader))
  `(bytes ~expr "utf-8"))

(defmacro assert-multi [#*cases]
  (let [s (lfor c cases `(assert ~c))]
    `(do ~s)))

(setv sock "/tmp/HyREPL-test")

(defclass ReplUnixStreamServer [ThreadingMixIn UnixStreamServer])
(defclass TestServer []
  (defn __init__ [self]
    (print "in TestServer __init__")
    (try
      (os.unlink sock)
      (except [e FileNotFoundError]))
    (setv self.o sys.stderr)
    (setv self.s (ReplUnixStreamServer sock ReplRequestHandler))
    (setv self.t (threading.Thread :target (. self s serve-forever)))
    (setv (. self t daemon) True)
    (setv sys.stderr (StringIO))
    None)
  (defn __enter__ [self]
    (print "in TestServer __enter__")
    (.start self.t)
    self)
  (defn __exit__ [self &rest args]
    (print "in TestServer __exit__")
    (.shutdown self.s)
    (setv sys.stderr self.o)
    (.join self.t)
    ))


(defn soc-send [message [return-reply True]]
  ;; (print (.format "DEBUG[soc-send] message: {}" message) :flush True)
  (let [s (socket.socket :family socket.AF-UNIX)
        r []]
    (.connect s sock)
    (.sendall s (encode message))
    ;; (print (.format "DEBUG[soc-send] after sendall, message: {}" (encode message))  :flush True) ; debug 
    (when return-reply
      (.setblocking s False)
      ;; (print "DEBUG soc-send: after setblocking" :flush True) ; debug 
      (let [buf #b ""]
        (while True
          (try
            (+= buf (.recv s 1024))
            (except [e BlockingIOError]))

          ;; (print "DEBUG[soc-send] after exit first try" :flush True) ; debug 

          ;; 1byteずつ読み取って毎回decodeをtryする、失敗すればcontinueするので常に失敗してると終わらない
          (try
            (setv #(resp rest) (decode buf))
            ;; (print (.format "DEBUG soc-send: resp: {}, rest: {}" resp rest) :flush True) ; debug 
            (except [e Exception]
              ;; (print (.format "DEBUG[soc-send] e: {}" e) :flush True) ; debug
              ;; (print (.format "DEBUG[soc-send] buf: {}" buf) :flush True) ; debug 
              (continue)))
          (setv buf rest)
          (.append r resp)
          (when (in "done" (.get resp "status" []))
            (break)))))
    (.close s)
    r))


;; これがdecodeできていない？
;; (setv msg1 #b"d6:statusl4:donee2:id0:8:versionsd5:nrepld5:majori0e5:minori2e11:incrementali7e14:version-string5:0.2.7e4:javad5:majori0e5:minori0e11:incrementali0e14:version-string5:0.0.0e7:clojured5:majori0e5:minori0e11:incrementali0e14:version-string5:0.0.0ee3:opsd5:cloned3:doc16:Clones a session8:requiresde8:optionald7:session76:The session to be cloned. If this is left out, the current session is clonede7:returnsd11:new-session25:The ID of the new sessionee5:closed3:doc28:Closes the specified session8:requiresd7:session20:The session to closee8:optionalde7:returnsdee8:described3:doc27:Describe available commands8:requiresde8:optionald8:verbose?45:True if more verbose information is requestede7:returnsd3:aux21:Map of auxiliary data3:ops48:Map of operations supported by this nREPL server8:versions87:Map containing version maps, for example of the nREPL protocol supported by this serveree5:stdind3:doc20:Feeds value to stdin8:requiresd5:value16:value to feed ine8:optionalde7:returnsd6:status36:\"need-input\" if more input is neededee11:ls-sessionsd3:doc22:Lists running sessions8:requiresde8:optionalde7:returnsd8:sessions26:A list of running sessionsee11:client.initd3:doc27:Inits the Lighttable client8:requiresde8:optionalde7:returnsd8:encoding3:edn4:data31:Data about supported middlewareee4:testd3:doc14:Test operation8:requiresde8:optionalde7:returnsd4:test11:Test stringee4:evald3:doc15:Evaluates code.8:requiresd4:code24:The code to be evaluatede8:optionald7:session101:The ID of the session in which the code will be evaluated. If absent, a new session will be generated2:id58:An opaque message ID that will be included in the responsee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value99:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are presentee15:editor.eval.cljd3:doc15:Evaluates code.8:requiresd4:data24:The code to be evaluatede8:optionald7:session101:The ID of the session in which the code will be evaluated. If absent, a new session will be generated2:id58:An opaque message ID that will be included in the responsee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value129:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are\n                              presentee9:interruptd3:doc24:Interrupt a running eval8:requiresd7:session55:The session id used to start the eval to be interruptede8:optionald12:interrupt-id31:The ID of the eval to interrupte7:returnsd6:status237:\"interrupted\" if an eval was interrupted, \"session-idle\" if the session is not evaluating code at  the moment, \"interrupt-id-mismatch\" if the session is currently evaluating code with a different ID than thespecified \"interrupt-id\" valueee9:load-filed3:doc41:Loads a body of code. Delegates to `eval`8:requiresd4:file17:full body of codee8:optionald9:file-name51:name of the source file, for example for exceptions9:file-path23:path to the source filee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value99:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are presentee8:completed3:doc66:Returns a list of symbols matching the specified (partial) symbol.8:requiresd6:prefix21:The symbol to look up7:session19:The current sessione8:optionald7:context18:Completion context14:extra-metadata27:List of additional metadatae7:returnsd11:completions30:A list of possible completionsee4:infod3:doc30:Provides information on symbol8:requiresd6:symbol21:The symbol to look upe7:returnsd6:status4:doneeee7:session0:e")

;; (try (decode msg1)
;;      (except [e Exception]
;;        (print (.format "DEBUG soc-send: e: {}" e) :flush True)))

;; DEBUG soc-send: e: invalid literal for int() with base 10: 'e8'

;; (encode {"requires" {}  "optional" {"session" "The session to be cloned. If this is left out, the current session is cloned"}})

;; b"d8:requiresde8:optionald7:session76:The session to be cloned. If this is left out, the current session is clonedee"


;; 受信できてるように見える。これがdecodeできてない
;; DEBUG soc-send: buf: b'd6:statusl4:donee2:id0:8:versionsd5:nrepld5:majori0e5:minori2e11:incrementali7e14:version-string5:0.2.7e4:javad5:majori0e5:minori0e11:incrementali0e14:version-string5:0.0.0e7:clojured5:majori0e5:minori0e11:incrementali0e14:version-string5:0.0.0ee3:opsd5:cloned3:doc16:Clones a session8:requiresde8:optionald7:session76:The session to be cloned. If this is left out, the current session is clonede7:returnsd11:new-session25:The ID of the new sessionee5:closed3:doc28:Closes the specified session8:requiresd7:session20:The session to closee8:optionalde7:returnsdee8:described3:doc27:Describe available commands8:requiresde8:optionald8:verbose?45:True if more verbose information is requestede7:returnsd3:aux21:Map of auxiliary data3:ops48:Map of operations supported by this nREPL server8:versions87:Map containing version maps, for example of the nREPL protocol supported by this serveree5:stdind3:doc20:Feeds value to stdin8:requiresd5:value16:value to feed ine8:optionalde7:returnsd6:status36:"need-input" if more input is neededee11:ls-sessionsd3:doc22:Lists running sessions8:requiresde8:optionalde7:returnsd8:sessions26:A list of running sessionsee11:client.initd3:doc27:Inits the Lighttable client8:requiresde8:optionalde7:returnsd8:encoding3:edn4:data31:Data about supported middlewareee4:testd3:doc14:Test operation8:requiresde8:optionalde7:returnsd4:test11:Test stringee4:evald3:doc15:Evaluates code.8:requiresd4:code24:The code to be evaluatede8:optionald7:session101:The ID of the session in which the code will be evaluated. If absent, a new session will be generated2:id58:An opaque message ID that will be included in the responsee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value99:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are presentee15:editor.eval.cljd3:doc15:Evaluates code.8:requiresd4:data24:The code to be evaluatede8:optionald7:session101:The ID of the session in which the code will be evaluated. If absent, a new session will be generated2:id58:An opaque message ID that will be included in the responsee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value129:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are\n                              presentee9:interruptd3:doc24:Interrupt a running eval8:requiresd7:session55:The session id used to start the eval to be interruptede8:optionald12:interrupt-id31:The ID of the eval to interrupte7:returnsd6:status237:"interrupted" if an eval was interrupted, "session-idle" if the session is not evaluating code at  the moment, "interrupt-id-mismatch" if the session is currently evaluating code with a different ID than thespecified "interrupt-id" valueee9:load-filed3:doc41:Loads a body of code. Delegates to `eval`8:requiresd4:file17:full body of codee8:optionald9:file-name51:name of the source file, for example for exceptions9:file-path23:path to the source filee7:returnsd2:ex73:Type of the exception thrown, if any. If present, `value` will be absent.2:ns91:The current namespace after the evaluation of `code`. For HyREPL, this will always be `Hy`.7:root-ex12:Same as `ex`5:value99:The values returned by `code` if execution was successful. Absent if `ex` and `root-ex` are presentee8:completed3:doc66:Returns a list of symbols matching the specified (partial) symbol.8:requiresd6:prefix21:The symbol to look up7:session19:The current sessione8:optionald7:context18:Completion context14:extra-metadata27:List of additional metadatae7:returnsd11:completions30:A list of possible completionsee4:infod3:doc30:Provides information on symbol8:requiresd6:symbol21:The symbol to look upe7:returnsd6:status4:doneeee7:session0:e'

(defn test-bencode []
  (let [d {"foo" 42 "spam" [1 2 "a"]}]
    (assert (= d (-> d encode decode first))))

  (let [d {}]
    (assert (= d (-> d encode decode first))))

  (let [d {"requires" {}
           "optional" {"session" "The session to be cloned."}}]
    (assert (= d (-> d encode decode first))))

  (let [d (decode-multiple (+
                             #b"d5:value1:47:session36:31594b80-7f2e-4915-9969-f1127d562cc42:ns2:Hye"
                             #b"d6:statusl4:donee7:session36:31594b80-7f2e-4915-9969-f1127d562cc4e"))]
    (assert-multi
      (= (len d) 2)
      (isinstance (first d) dict)
      (isinstance (second d) dict)
      (= (. d [0] ["value"]) "4")
      (= (. d [0] ["ns"]) "Hy")
      (isinstance (. d [1] ["status"]) list)
      (= (len (. d [1] ["status"])) 1)
      (= (. d [1] ["status"] [0]) "done"))))


(defn test-describe []
  "simple eval
  Example output from the server:
  [{'session': '0361c419-ef89-4a86-ae1a-48388be56041', 'ns': 'Hy', 'value': '4'}, 
               {'status': ['done'], 'session': '0361c419-ef89-4a86-ae1a-48388be56041'}]
  "
  (with [(TestServer)]
    (print "DEBUG[test-describe] after with in test-describe(before soc-send)")
    (let [req {"op" "describe"}
          ret (soc-send req)
          status (first (.get (first ret) "status"))]

      (print (.format "DEBUG[test-describe] req: {}" req) :flush True)
      (print (.format "DEBUG[test-describe] ret: {}" ret) :flush True)
      (print (.format "DEBUG[test-describe] status: {}" status) :flush True)
      
      (assert (= status "done")))))

(defn test-code-eval []
  "simple eval
  Example output from the server:
  [{'session': '0361c419-ef89-4a86-ae1a-48388be56041', 'ns': 'Hy', 'value': '4'}, 
   {'status': ['done'], 'session': '0361c419-ef89-4a86-ae1a-48388be56041'}]
  "
  (with [(TestServer)]
    (let [code {"op" "eval" "code" "(+ 2 2)"}
          ret (soc-send code)
          value (first ret)
          status (second ret)]

      (print (.format "DEBUG[test-code-eval] code: {}" code) :flush True)
      (print (.format "DEBUG[test-code-eval] ret: {}" ret) :flush True)
      (print (.format "DEBUG[test-code-eval] status: {}" status) :flush True))))

      ;; (assert-multi
      ;;   (= (len ret) 2)
      ;;   (= (. value ["value"]) "4")
      ;;   (in "done" (. status ["status"]))
      ;;   (= (. value ["session"]) (. status ["session"]))))


(defn test-stdout-eval []
  "stdout eval
  Example output from the server:
  [{'session': '2d6b48d8-4a3e-49a6-9131-3321a11f70d4', 'ns': 'Hy', 'value': 'None'},
               {'session': '2d6b48d8-4a3e-49a6-9131-3321a11f70d4', 'out': 'Hello World\n'},
               {'status': ['done'], 'session': '2d6b48d8-4a3e-49a6-9131-3321a11f70d4'}]
  "
  (with [(TestServer)]
    (let [code {"op" "eval" "code" "(print \"Hello World\")"}
          ret (soc-send code)
          value (first ret)
          out (second ret)
          status (nth 2 ret)]
      (assert-multi
            (= (len ret) 3)
            (= (. value ["value"]) "None")
            (= (. out ["out"]) "Hello World\n")
            (in "done" (. status ["status"]))
            (= (. value ["session"]) (. out ["session"]) (. status ["session"]))))))


(defn stdin-send [code my-queue]
  (.put my-queue (soc-send code)))


(defn test-stdin-eval []
    "stdin eval
    The current implementation will send all the responses back
    into the first thread which dispatched the (def...), so we throw
    it into a thread and add a Queue to get it.
    Bad hack. But it works.

    Example output from the server:
        [{'status': ['need-input'], 'session': 'ec100813-8e76-4d69-9116-6460c1db4428'},
         {'session': 'ec100813-8e76-4d69-9116-6460c1db4428', 'ns': 'Hy', 'value': 'test'},
         {'status': ['done'], 'session': 'ec100813-8e76-4d69-9116-6460c1db4428'}]
    "
    (with [(TestServer)]
      (let [my-queue (queue.Queue)
            code {"op" "eval" "code" "(def a (input))"}
            t (threading.Thread :target stdin-send :args [code my-queue])]
            (.start t)
            ; Might encounter a race condition where
            ; we send stdin before we eval (input)
            (time.sleep 0.5)

            (soc-send {"op" "stdin" "value" "test"} :return-reply False)

            (.join t)

        (let [ret (.get my-queue)
              input-request (first ret)
              value (second ret)
              status (nth 2 ret)]
          (assert-multi
            (= (len ret) 3)
            (= (. value ["value"]) "test")
            (= (. input-request ["status"]) ["need-input"])
            (in "done" (. status ["status"]))
            (= (. value ["session"]) (. input-request ["session"]) (. status ["session"])))))))
