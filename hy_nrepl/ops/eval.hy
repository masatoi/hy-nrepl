(import toolz [first second]
        hy-nrepl.backend_thread [ThreadEvalBackend InterruptibleEval]
        hy-nrepl.ops.utils [ops])

(require hy-nrepl.ops.utils [defop])


(defn ensure-backend [session]
  (when (is session.backend None)
    (setv session.backend (ThreadEvalBackend session))
    (setv session.backend-name "thread")))


(defop "eval" [session msg transport]
  {"doc" "Evaluates code."
   "requires" {"code" "The code to be evaluated"}
   "optional" {"session" (+ "The ID of the session in which the code will"
                           " be evaluated. If absent, a new session will"
                           " be generated")
               "id" "An opaque message ID that will be included in the response"}
   "returns" {"ex" "Type of the exception thrown, if any. If present, `value` will be absent."
              "ns" (+ "The current namespace after the evaluation of `code`."
                      " For hy-nrepl, this will always be `Hy`.")
              "root-ex" "Same as `ex`"
              "value" (+ "The values returned by `code` if execution was"
                         " successful. Absent if `ex` and `root-ex` are"
                         " present")}}
  (ensure-backend session)
  (.eval session.backend msg transport))


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
  (ensure-backend session)
  (let [status (.interrupt session.backend msg)]
    (.write session
            {"id" (.get msg "interrupt-id")
             "status" ["done" status]}
            transport)
    (.write session
            {"status" ["done"]
             "id" (.get msg "id")}
            transport)))
