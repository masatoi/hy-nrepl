(import HyREPL.session [Session])
(import HyREPL.ops.eval [InterruptibleEval])
(import uuid [uuid4])
(import HyREPL.ops.completions [get-completions])

(defn test-get-completions []
  (setv session (Session))
  (setv writer (fn [x])) ; mock writer

  (defn eval-and-run [code]
    (setv eval-instance (InterruptibleEval {"code" code "id" (str (uuid4))} session writer))
    (eval-instance.run))

  ;; Test for completion of self-defined functions and private names
  (eval-and-run "(do (defn add1 [x] (+ x 1))
                     (defn add2 [x] (+ x 2))
                     (defn _add0 [x] x))")
  (setv result (get-completions session "add"))
  (assert (= (lfor d result :if (= (.get d "candidate") "add1") d)
             [{"candidate" "add1" "type" "other"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "add2") d)
             [{"candidate" "add2" "type" "other"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "_add0") d) []))

  (setv result (get-completions session "_"))
  (assert (= (lfor d result :if (= (.get d "candidate") "_add0") d)
             [{"candidate" "_add0" "type" "other"}]))

  ;; Test for completion of os module functions
  (eval-and-run "(import os)")
  (setv result (get-completions session "os."))
  (assert (> (len result) 100))
  (assert (= (lfor d result :if (= (.get d "candidate") "os.getcwd") d)
             [{"candidate" "os.getcwd" "type" "builtin"}]))

  ;; Test for completion of sample module functions
  (eval-and-run "(import tests.ops.sample_module)")

  ;; Module
  (setv result (get-completions session "tests.ops."))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module") d)
             [{"candidate" "tests.ops.sample_module" "type" "module"}]))

  ;; Functions which could contain kebab-case symbol
  (setv result (get-completions session "tests.ops.sample_module."))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello") d)
             [{"candidate" "tests.ops.sample_module.hello" "type" "function"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello-world") d)
             [{"candidate" "tests.ops.sample_module.hello-world" "type" "function"}]))

  (setv result (get-completions session "tests.ops.sample_module.hel"))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello") d)
             [{"candidate" "tests.ops.sample_module.hello" "type" "function"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello-world") d)
             [{"candidate" "tests.ops.sample_module.hello-world" "type" "function"}]))

  (setv result (get-completions session "tests.ops.sample_module.hello-"))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello") d)
             []))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.hello-world") d)
             [{"candidate" "tests.ops.sample_module.hello-world" "type" "function"}]))

  ;; Class and object
  (setv result (get-completions session "tests.ops.sample_module.F"))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.Foo") d)
             [{"candidate" "tests.ops.sample_module.Foo" "type" "class"}]))

  (setv result (get-completions session "tests.ops.sample_module.Foo.get-"))
  (assert (= (lfor d result :if (= (.get d "candidate") "tests.ops.sample_module.Foo.get-x") d)
             [{"candidate" "tests.ops.sample_module.Foo.get-x" "type" "function"}]))

  ;; Instance of Foo
  (eval-and-run "(setv foo (tests.ops.sample_module.Foo 10))")

  (setv result (get-completions session "foo."))
  (assert (= (lfor d result :if (= (.get d "candidate") "foo.get-x") d)
             [{"candidate" "foo.get-x" "type" "method"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "foo.x") d)
             [{"candidate" "foo.x" "type" "other"}]))

  (eval-and-run "(setv foo-bar (tests.ops.sample_module.Foo 20))")

  (setv result (get-completions session "foo-bar."))
  (assert (= (lfor d result :if (= (.get d "candidate") "foo-bar.get-x") d)
             [{"candidate" "foo-bar.get-x" "type" "method"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "foo-bar.x") d)
             [{"candidate" "foo-bar.x" "type" "other"}]))

  ;; Private attributes should not be suggested without prefix "_"
  (eval-and-run "(defclass Baz []
                     (defn __init__ [self]
                       (setv self._y 1))
                     (defn _get-y [self] self._y)
                     (defn get-y [self] self._y))")
  (eval-and-run "(setv baz (Baz))")

  (setv result (get-completions session "baz."))
  (assert (= (lfor d result :if (= (.get d "candidate") "baz.get-y") d)
             [{"candidate" "baz.get-y" "type" "method"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "baz._get_y") d) []))

  (setv result (get-completions session "baz._"))
  (assert (= (lfor d result :if (= (.get d "candidate") "baz._get_y") d)
             [{"candidate" "baz._get_y" "type" "method"}])))

(defn test-get-completions-invalid-prefix []
  "Completions should not crash on non-Python-like input."
  (setv session (Session))
  (setv result (get-completions session "https://example.com/foo"))
  (assert (= result [])))
