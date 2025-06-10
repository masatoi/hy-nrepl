(import toolz [first second])
(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])

(defop close [session msg transport]
  {"doc" "Closes the specified session"
   "requires" {"session" "The session to close"}
   "optional" {}
   "returns" {}}
  (.write session
          {"status" ["done"]
           "id" (.get msg "id")
           "session" session.id}
          transport)
  ;; XXX: Imported here to avoid circ. dependency
  (import HyREPL.server [session-registry])
  (try
    (let [sid (.get msg "session" "")]
      (session-registry.remove sid))
    (except [e KeyError])))
