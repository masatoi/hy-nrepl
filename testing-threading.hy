(import HyREPL.session [Session])
(import HyREPL.middleware.eval [InterruptibleEval])

(setv sess1 (Session))
(setv msg1 {"op" "eval" "code" "(+ 2 2)"})

(setv t1
      (InterruptibleEval msg1 sess1
        (fn [x]
          (print (.format "DEBUG[writer] {}" x) :flush True))))

(print (.format "DEBUG[testing-threading.hy] before start t1: {}" t1) :flush True)

(.start t1)

(print (.format "DEBUG[testing-threading.hy] after start t1: {}" t1) :flush True)

;; evalでシンタックスエラー
;; eval(<python code>, <global namespace>, <local namespace>)
