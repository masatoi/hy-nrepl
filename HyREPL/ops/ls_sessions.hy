(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])

(defop "ls-sessions" [session msg transport]
  {"doc" "Lists running sessions"
   "requires" {}
   "optional" {}
   "returns" {"sessions" "A list of running sessions"}}
  ;; XXX: Imported here to avoid circ. dependency
  (import HyREPL.server [session-registry])
  (.write session
          {"status" ["done"]
           "sessions" (session-registry.list-ids)
           "id" (.get msg "id")
           "session" session.id}
          transport))
