(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])
(import logging)

(defop clone [session msg transport]
  {"doc" "Clones a session"
   "requires" {}
   "optional" {"session" "The session to be cloned. If this is left out, the current session is cloned"}
   "returns" {"new-session" "The ID of the new session"}}
  (logging.info "[clone] before load Session")
  (import HyREPL.session [Session]) ; Imported here to avoid circ. dependency
  (let [s (Session)]
    (.write session {"status" ["done"] "id" (.get msg "id") "new-session" (str s)} transport)))
