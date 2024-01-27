(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])

(defn make-version [[major 0] [minor 0] [incremental 0]]
  {"major" major
   "minor" minor
   "incremental" incremental
   "version-string" (.join "." (map str [major minor incremental]))})

(defop describe [session msg transport]
  {"doc" "Describe available commands"
   "requires" {}
   "optional" {"verbose?" "True if more verbose information is requested"}
   "returns" {"aux" "Map of auxiliary data"
              "ops" "Map of operations supported by this nREPL server"
              "versions" "Map containing version maps, for example of the nREPL protocol supported by this server"}}
  ;; TODO: don't ignore verbose argument
  ;; TODO: more versions: Python, Hy
  (.write session
          {"status" ["done"]
           "id" (.get msg "id")
           "versions" {"nrepl" (make-version 0 2 7)
                       "java" (make-version)
                       "clojure" (make-version)}
           "ops" (dfor [k v] (.items ops) k (get v :desc))
           "session" (.get msg "session")}
          transport))
