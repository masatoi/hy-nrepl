(import hy-nrepl.ops.utils [ops])
(require hy-nrepl.ops.utils [defop])

(defop "ls-sessions" [session msg transport]
  {"doc" "Lists running sessions"
   "requires" {}
   "optional" {}
   "returns" {"sessions" "A list of running sessions"}}
  ;; registry is stored on the current session
  (.write session
          {"status" ["done"]
           "sessions" (session.registry.list-ids)
           "id" (.get msg "id")
           "session" session.id}
          transport))
