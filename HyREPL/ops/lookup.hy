(import sys inspect logging types)
(import hy.models [Symbol])
(import hy.reader.mangling [mangle])
(import HyREPL.ops.utils [ops])
(require HyREPL.ops.utils [defop])
(import toolz [first second nth])

(defn resolve-module [sym]
  (setv m (re.match r"(\S+(\.[\w-]+)*)\.([\w-]*)$" sym))
  (setv groups (.group m 1 3))
  groups)

(defn split-string-by-first-dot [input-string]
  (input-string.split "." 1))

(defn contain-dot? [input-string]
  (in "." input-string))

(defn is-module? [obj]
  (isinstance obj types.ModuleType))

(defn %resolve-symbol [m sym]
  (if (contain-dot? sym)
      (let [parts (split-string-by-first-dot sym)
            result (eval (Symbol (mangle (get parts 0))) (. m __dict__))]
        (logging.debug "%resolve-symbol: parts= %s, result= %s" parts result)
        (if (is-module? result)
            (%resolve-symbol result (get parts 1))
            (eval (mangle sym) (. m __dict__))))
      (eval (Symbol (mangle sym)) (. m __dict__))))

(defn resolve-symbol [m sym]
  (try
    (%resolve-symbol m sym)
    (except [e NameError]
      (try
        (get _hy_macros (mangle sym))
        (except [e KeyError]
          None)))))

(defn get-info [session symbol-name]
  (let [symbol (resolve-symbol session.module symbol-name)
        doc (inspect.getdoc symbol)
        comment (inspect.getcomments symbol)
        sig (and (callable symbol) (inspect.signature symbol))
        result {}]
    (logging.debug "get-info: Got object %s for symbol %s" symbol symbol-name)
    (when (is-not s None)
      (update result
              {"doc" (or doc comment "No doc string")
               "static" "true"
               "ns" (or (. (inspect.getmodule symbol) __name__) "Hy")
               "name" symbol-name})
      ;; get definition position
      (try
        (.update result
                 {"file" (inspect.getfile symbol)
                  "line" (second (inspect.getsourcelines requests.get))})
        (except [e TypeError]))
      (when sig
        (.update result {"arglists-str" (str sig)})))
    result))

(defop lookup [session msg transport]
  {"doc" "Lookup symbol info"
   "requires" {"sym" "The symbol to look up"}
   "returns" {"info" "A map of the symbol’s info."
              "status" "done"}}
  (logging.debug "lookup: msg=%s" msg)
  (let [info (get-info session (.get msg "sym"))]
    (.write session
            {"info" info
             "id" (.get msg "id")
             "status" ["done"]}
            transport)))
