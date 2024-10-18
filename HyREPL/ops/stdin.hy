(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])
(import sys)
(import toolz [first second nth])
(import logging)

(defop stdin [session msg transport]
  {"doc" "Feeds value to stdin"
   "requires" { "stdin" "value to feed in" }
   "optional" {}
   "returns" {"status" "\"need-input\" if more input is needed"}}
  (logging.debug "id=%s" (.get msg "id"))
  (setv session.stdin-id (.get msg "id"))
  (.put sys.stdin (get msg "stdin"))
  (.task-done sys.stdin))
