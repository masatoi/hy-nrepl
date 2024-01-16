(import HyREPL.session [Session])
(import HyREPL.middleware.eval [InterruptibleEval])
(import uuid [uuid4])
(import io [StringIO])

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

(defn test_eval []
  (testing "(print \"Hello, world!\")"
           [{"out" "Hello, world!\n"}
            {"value" "None"
             "ns" "Hy"}
            {"status" ["done"]}])

  (testing "(+ 2 2)"
           [{"value" "4"
             "ns" "Hy"}
            {"status" ["done"]}]))
