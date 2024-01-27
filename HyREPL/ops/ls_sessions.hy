(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])

(defop "ls-sessions" [session msg transport]
  {"doc" "Lists running sessions"
   "requires" {}
   "optional" {}
   "returns" {"sessions" "A list of running sessions"}}
  (import HyREPL.session [sessions]) ; Imported here to avoid circ. dependency
  (.write session
          {"status" ["done"]
           "sessions" (lfor s (.values sessions) s.uuid)
           "id" (.get msg "id")
           "session" session.uuid}
          transport))
