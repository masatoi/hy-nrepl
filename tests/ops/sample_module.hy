;;; sample module for testing lookup op

(defn hello [name]
  (print (.format "Hello, {}!" name)))

(defn add1 [n]
  "This is docstring"
  (+ n 1))

(defclass Foo [object]
  "Sample class Foo"
  (defn __init__ [self x]
    (setv self.x x))

  (defn get-x [self]
    self.x))
