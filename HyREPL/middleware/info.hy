(import sys inspect)

(import HyREPL.ops [ops])
(require HyREPL.ops [defop])

(defn resolve-symbol [session sym]
  (try
    (eval (HySymbol sym) (. session.module __dict__))
    (except [e NameError]
      (try
        (get __macros__ (mangle sym))
        (except [e KeyError]
          None)))))

(defn get-info [session symbol]
  (let [s (resolve-symbol symbol)
        d (inspect.getdoc s)
        c (inspect.getcomments s)
        sig (and (callable s) (inspect.signature s))
        rv {}]
    (print "Got object " s " for symbol " symbol)
    (when (is-not s None)
      (.update rv {"doc" (or d c "No doc string")
                   "static" "true"
                   "ns" (or (. (inspect.getmodule s) __name__) "Hy")
                   "name" symbol})
      (try
        (.update rv
                 "file" (inspect.getfile s))
        (except [e TypeError]))
      (when sig
        (.update rv  {"arglists-str" (str sig)})))
    rv))

(defop info [session msg transport]
  {"doc" "Provides information on symbol"
   "requires" {"symbol" "The symbol to look up"}
   "returns" {"status" "done"}}
  (print msg :file sys.stderr)
  (let [info (get-info session (.get msg "symbol"))]
    (.write session
            {"value" info
             "id" (.get msg "id")
             "status" (if (empty? info) ["no-info" "done"] ["done"])}
            transport)))
