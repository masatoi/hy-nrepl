;; https://github.com/clojure/tools.nrepl/blob/34093111923031888f8bf6da457aaebc3381d67e/doc/ops.md
;; Incomplete ops:
;; - load-file (file name not handled)

(import logging
        hy.models
        toolz [first second nth])
(require hyrule [unless defmacro/g!])

(setv ops {})

(defmacro/g! defop [name args desc #* body]
  (unless (or (isinstance name hy.models.String)
              (isinstance name hy.models.Symbol))
    (raise (TypeError "Name must be a symbol or a string.")))
  (unless (isinstance args hy.models.List)
    (raise (TypeError "Arguments must be a list.")))
  (unless (isinstance desc hy.models.Dict)
    (raise (TypeError "Description must be a dictionary.")))
  (setv fn-checked
        `(fn [~@args]
           (setv g!failed False)
           (for [g!r (.keys (.get ~desc "requires" {}))]
             (if (in g!r (second ~args))
                 None
                 (do
                   (.write (first ~args)
                           {"status" ["done"]
                            "id" (.get (second ~args) "id")
                            "missing" (str g!r)} (nth 2 ~args))
                   (setv g!failed True)
                   (break))))
           (if g!failed
               None
               (do ~@body))))
  (setv n (str name))
  (setv o {:f fn-checked :desc desc})
  `(setv (get ops ~n) ~o))

(defn find-op [op]
  (if (in op ops)
    (get ops op :f)
    (fn [s m t]
      (logging.error "Unknown op: %s" op)
      (.write s {"status" ["done"] "id" (.get m "id")} t))))
