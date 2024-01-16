(import unittest)
(import unittest.mock [patch])
(import HyREPL.session [Session])
(import HyREPL.middleware.eval [InterruptibleEval])
(import uuid [uuid4])
(import io [StringIO])

(defclass TestInterruptibleEval [unittest.TestCase]
  (defn setUp [self]
    (setv self.msg {"code" "(print \"Hello, world!\")"
                    "id" (str (uuid4))})
    (setv self.session (Session))
    (setv self.result None)
    (setv self.writer (fn [x] (setv self.result x) x)) ; mock writer
    (setv self.eval-instance  (InterruptibleEval self.msg self.session self.writer)))

  ;; (defn test_basic [self]
  ;;   (with [mock-stdout (patch "sys.stdout" :new-callable StringIO)]
  ;;     (self.eval-instance.run)
  ;;     (self.assertEqual (.getvalue mock-stdout) "Hello, world!")
  ;;     (self.assertEqual self.result {"status" ["done"]})
  ;;     ))

  (defn test_basic [self]
    (self.eval-instance.run)
    (self.assertEqual self.result {"status" ["done"]})
    ))

(when (= __name__ "__main__")
  (unittest.main))
