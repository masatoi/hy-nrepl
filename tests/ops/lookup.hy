(import types)
(import HyREPL.session [Session])
(import HyREPL.ops.lookup [get-info resolve-module resolve-symbol])
(import tests.ops.sample_module)
(import tests.ops.sample_python_module)

(defn test-get-info []
  (let [test-module (types.ModuleType "test_module" "module for testing HyREPL")
        session (Session test-module)]

    ;; import sample_module
    (setv test-module.sample_module tests.ops.sample_module)

    ;; module
    (let [result (get-info session "sample_module")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_module"))
      (assert (= (get result "name") "sample_module"))
      (assert (= (get result "doc") "No doc string"))
      (assert (is (.get result "arglists-str") None))
      (assert (.startswith (get result "file") "file:/"))
      (assert (in "/HyREPL/tests/ops/sample_module.hy" (get result "file")))
      (assert (= (get result "line") 1))
      (assert (= (get result "language") "hylang"))
      (assert (= (get result "extension") ".hy")))

    ;; function
    (let [result (get-info session "sample_module.add1")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_module"))
      (assert (= (get result "name") "sample_module.add1"))
      (assert (= (get result "doc") "This is docstring"))
      (assert (= (get result "arglists-str") "(n)"))
      (assert (.startswith (get result "file") "file:/"))
      (assert (in "/HyREPL/tests/ops/sample_module.hy" (get result "file")))
      (assert (= (get result "line") 6))
      (assert (= (get result "language") "hylang"))
      (assert (= (get result "extension") ".hy")))

    ;; class
    (let [result (get-info session "sample_module.Foo")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_module"))
      (assert (= (get result "name") "sample_module.Foo"))
      (assert (= (get result "doc") "Sample class Foo"))
      (assert (= (get result "arglists-str") "(x)"))
      (assert (.startswith (get result "file") "file:/"))
      (assert (in "/HyREPL/tests/ops/sample_module.hy" (get result "file")))
      (assert (= (get result "line") 10))
      (assert (= (get result "language") "hylang"))
      (assert (= (get result "extension") ".hy")))

    ;; error cases

    ;; SyntaxError: case of reserved words are included
    (let [result (get-info session "sample_module.in")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    ;; AssertionError
    (let [result (get-info session "sample_module.")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    (let [result (get-info session ".Foo")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    (let [result (get-info session ".")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    (let [result (get-info session "from.Foo")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    (let [result (get-info session "")]
      (print (.format "result: {}" result))
      (assert (= result {})))

    ;; No signature case
    (let [result (get-info session "set")]
      (print (.format "result: {}" result))
      (assert (= (get result "name") "set"))
      (assert (get result "doc")))

    ;; No attribute case
    (let [result (get-info session "sample_module.Foo.y")]
      (print (.format "result: {}" result))
      (assert (= result {})))))

(defn test-get-info-from-python-module []
  (let [test-module (types.ModuleType "test_module" "module for testing HyREPL")
        session (Session test-module)]

    ;; import sample_python_module
    (setv test-module.sample_python_module tests.ops.sample_python_module)

    ;; module
    (let [result (get-info session "sample_python_module")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_python_module"))
      (assert (= (get result "name") "sample_python_module"))
      (assert (= (get result "doc") "No doc string"))
      (assert (is (.get result "arglists-str") None))
      (assert (in "/HyREPL/tests/ops/sample_python_module.py" (get result "file")))
      (assert (= (get result "line") 1))
      (assert (= (get result "language") "python"))
      (assert (= (get result "extension") ".py")))

    ;; function
    (let [result (get-info session "sample_python_module.add1_python")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_python_module"))
      (assert (= (get result "name") "sample_python_module.add1_python"))
      (assert (= (get result "doc") "This is docstring"))
      (assert (= (get result "arglists-str") "(n)"))
      (assert (in "/HyREPL/tests/ops/sample_python_module.py" (get result "file")))
      (assert (= (get result "line") 8))
      (assert (= (get result "language") "python"))
      (assert (= (get result "extension") ".py")))

    ;; class
    (let [result (get-info session "sample_python_module.Bar")]
      (print (.format "result: {}" result))
      (assert (= (get result "ns") "tests.ops.sample_python_module"))
      (assert (= (get result "name") "sample_python_module.Bar"))
      (assert (= (get result "doc") "Sample class Bar"))
      (assert (= (get result "arglists-str") "(x)"))
      (assert (in "/HyREPL/tests/ops/sample_python_module.py" (get result "file")))
      (assert (= (get result "line") 13))
      (assert (= (get result "language") "python"))
      (assert (= (get result "extension") ".py")))))
