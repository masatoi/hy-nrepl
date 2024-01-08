(import sys inspect logging types)
(import hy.models [Symbol])
(import hy.reader.mangling [mangle])
(import HyREPL.ops [ops])
(require HyREPL.ops [defop])
(import toolz [first second nth])

;; ;;; debug-print
;; (defreader >
;;   (setv code (.parse-one-form &reader))
;;   `(do (print (hy.core.hy-repr.hy-repr '~code) " => " ~code) ~code))

;; (defreader slice
;;   (defn parse-node []
;;     (let [node (when (!= ":" (.peekc &reader))
;;                  (.parse-one-form &reader))]
;;       (if (= node '...) 'Ellipse node)))

;;   (with [(&reader.end-identifier ":")]
;;     (let [nodes []]
;;       (&reader.slurp-space)
;;       (nodes.append (parse-node))
;;       (while (&reader.peek-and-getc ":")
;;         (nodes.append (parse-node)))

;;       `(slice ~@nodes))))

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

(defn get-info [session symbol]
  (let [s (resolve-symbol session.module symbol)
        d (inspect.getdoc s)
        c (inspect.getcomments s)
        sig (and (callable s) (inspect.signature s))
        rv {}]
    (logging.debug "get-info: Got object %s for symbol %s" s symbol)
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
             "status" (if (= info {}) ["no-info" "done"] ["done"])}
            transport)))

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
             "status" (if (= info {}) ["no-info" "done"] ["done"])}
            transport)))
