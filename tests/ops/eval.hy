(import hy-nrepl.session [Session])
(import hy-nrepl.ops.eval [InterruptibleEval])
(import uuid [uuid4])
(import io [StringIO])
(import toolz [first])

(defn testing [code expected-result]
  (setv msg {"code" code
             "id" (str (uuid4))})
  (setv session (Session))
  (setv result [])
  (setv writer (fn [x]
                 (nonlocal result)
                 (.append result x))) ; mock writer
  (setv eval-instance  (InterruptibleEval msg session writer))
  (eval-instance.run)
  (print (.format "result: {}" result))
  (assert (= result expected-result)))

(defn test-eval []
  (testing "(print \"Hello, world!\")"
           [{"out" "Hello, world!"}
            {"out" "\n"}
            {"value" "None"
             "ns" "Hy"}
            {"status" ["done"]}])

  (testing "(+ 2 2)"
           [{"value" "4"
             "ns" "Hy"}
            {"status" ["done"]}]))

(defn test-multi-expression-eval []
  (testing ";; this is comment\n(print \"Hello, world!\")"
           [{"out" "Hello, world!"}
            {"out" "\n"}
            {"value" "None"
             "ns" "Hy"}
            {"status" ["done"]}]))

(defn test-multi-expression-eval2 []
  (testing ";; this is comment
(setv arr [])
(arr.append 1)
arr"
           [{"value" "[1]"
             "ns" "Hy"}
            {"status" ["done"]}]))

(defn test-multi-output []
  (testing ";; this is comment
(print 1)
(print 2)
(print 3)
4"
           [{"out" "1"}
            {"out" "\n"}
            {"out" "2"}
            {"out" "\n"}
            {"out" "3"}
            {"out" "\n"}
            {"value" "4"
             "ns" "Hy"}
            {"status" ["done"]}]))

(defn test-eval-with-exception []
  (setv msg {"code" "(/ 1 0)"
             "id" (str (uuid4))})
  (setv session (Session))
  (setv result [])
  (setv writer (fn [x]
                 (nonlocal result)
                 (.append result x))) ; mock writer
  (setv eval-instance  (InterruptibleEval msg session writer))
  (eval-instance.run)
  (print (.format "result: {}" result))
  (setv eval-error (first (filter (fn [dict] (= (.get dict "status" None) ["eval-error"])) result)))
  (assert (= (get eval-error "status") ["eval-error"]))
  (assert (= (get eval-error "ex") "ZeroDivisionError"))
  (assert (= (get eval-error "root-ex") "ZeroDivisionError")))

(defn test-eval-with-syntax-error []
  (setv msg {"code" "(define x (foo bar"
             "id" (str (uuid4))})
  (setv session (Session))
  (setv result [])
  (setv writer (fn [x]
                 (nonlocal result)
                 (.append result x)))
  (setv eval-instance (InterruptibleEval msg session writer))
  (eval-instance.run)
  (setv eval-error (first (filter (fn [d] (= (.get d "status") ["eval-error"])) result)))
  (assert eval-error)
  (assert (= (get eval-error "status") ["eval-error"]))
  (assert (in (get eval-error "ex") ["HyLanguageError" "LexException" "PrematureEndOfInput"]))
)

(defn test-eval-with-name-error []
  (setv msg {"code" "(this-is-not-defined)"
             "id" (str (uuid4))})
  (setv session (Session))
  (setv result [])
  (setv writer (fn [x]
                 (nonlocal result)
                 (.append result x)))
  (setv eval-instance (InterruptibleEval msg session writer))
  (eval-instance.run)
  (setv eval-error (first (filter (fn [d] (= (.get d "status") ["eval-error"])) result)))
  (assert eval-error)
  (assert (= (get eval-error "status") ["eval-error"]))
  (assert (= (get eval-error "ex") "NameError")))
