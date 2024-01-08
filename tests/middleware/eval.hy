(import unittest)
(import HyREPL.middleware.eval *)

(defclass TestListOps [unittest.TestCase]
  (defn test1 [self]
    (setv lst '(a b c))
    (self.assertEqual (car lst) 'a)
    (self.assertEqual (cdr lst) '(b c))
    (self.assertTrue (evenp 2))
    (self.assertTrue (oddp 3))))

(defclass TestNumberOps [unittest.TestCase]
  (defn test1 [self]
    (self.assertTrue (evenp 2))
    (self.assertTrue (oddp 3))))

(when (= __name__ "__main__")
  (unittest.main))
