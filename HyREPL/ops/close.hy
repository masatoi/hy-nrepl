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
           "session" session.uuid}
          transport)
  (import HyREPL.session [sessions]) ; Imported here to avoid circ. dependency
  (try
    (del (get sessions (.get msg "session" "")))
    (except [e KeyError])))
