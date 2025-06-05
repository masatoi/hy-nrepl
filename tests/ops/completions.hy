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

  ;; Test for completion of self-defined functions
  (eval-and-run "(do (defn add1 [x] (+ x 1))
                     (defn add2 [x] (+ x 2)))")
  (setv result (get-completions session "add"))
  (assert (= (lfor d result :if (= (.get d "candidate") "add1") d)
             [{"candidate" "add1" "type" "other"}]))
  (assert (= (lfor d result :if (= (.get d "candidate") "add2") d)
             [{"candidate" "add2" "type" "other"}]))

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
  ;; ensure private names (starting with "_") are listed last
  (setv cands (lfor d result (.get d "candidate")))
  (setv nonpriv (lfor c cands :if (not (.startswith (get (.split c ".") (- (len (.split c ".")) 1)) "_")) c))
  (setv priv (lfor c cands :if (.startswith (get (.split c ".") (- (len (.split c ".")) 1)) "_") c))
  (assert (= cands (+ nonpriv priv)))
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
             [{"candidate" "foo-bar.x" "type" "other"}])))
