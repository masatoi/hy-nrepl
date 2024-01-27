(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])
(import sys)

(defop stdin [session msg transport]
  {"doc" "Feeds value to stdin"
   "requires" { "value" "value to feed in" }
   "optional" {}
   "returns" {"status" "\"need-input\" if more input is needed"}}
  (.put sys.stdin (get msg "value"))
  (.task-done sys.stdin))
