(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])
(import logging)

(defop clone [session msg transport]
  {"doc" "Clones a session"
   "requires" {}
   "optional" {"session" "The session to be cloned. If this is left out, the current session is cloned"}
   "returns" {"new-session" "The ID of the new session"}}
  (logging.info "[clone] before load Session")
  ;; XXX: Imported here to avoid circ. dependency
  (import HyREPL.server [session-registry])
  (let [s (session-registry.create)]
    (.write session {"status" ["done"]
                     "id" (.get msg "id")
                     "new-session" (str s)}
            transport)))
