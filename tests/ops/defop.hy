(import sys)
(import toolz [first second nth])
(import HyREPL.ops.utils [ops find-op])
(require HyREPL.ops.utils [defop])

(defclass MockSession []
  (defn __init__ [self]
    (setv self.messages [])
    None)

  (defn write [self msg transport]
    (.append self.messages msg)))
  
(defn test-defop-verify-message []
  (let [s (MockSession)]
    (defop "vtest1-requires" [session msg transport]
      {"requires" {"foo" "the foo parameter(require)"}}
      (.write session (.get msg "foo") transport))

    ;; missing required parameter
    ((find-op "vtest1-requires")
      s {} None)
    (assert (= (first s.messages) {"status" ["done"]
                                   "id" None
                                   "missing" "foo"}))

    ;; return foo parameter value
    ((find-op "vtest1-requires")
      s {"foo" 'bar} None)
    (assert (= (second s.messages) 'bar))))

(defn test-defop-optional-parameter []
  (let [s (MockSession)]
    (defop "vtest2-optionals" [session msg transport]
      {"requires" {}
       "optional" {"foo" "the foo parameter(optional)"}}
      (.write session (.get msg "foo") transport))

    ;; missing optional parameter
    ((find-op "vtest2-optionals")
      s {} None)
    (assert (= (first s.messages) None))

    ;; return foo parameter value
    ((find-op "vtest2-optionals")
      s {"foo" 'bar} None)
    (assert (= (second s.messages) 'bar))

    ;; unpermitted parameters are just ignored
    ((find-op "vtest2-optionals")
      s {"baz" 'quz} None)
    (assert (= (nth 2 s.messages) None))))

(defn test-defop-success []
  (defop o1 [] {})
  (defop o2 [a] {})
  (defop o3 [] {"doc" "I'm a docstring!"})
  (defop "o4-something.foo" [] {})

  (assert (in "o1" ops))
  (assert (in "o2" ops))
  (assert (in "o3" ops))
  (assert (in "o4-something.foo" ops))
  (assert (= (get ops "o3" :desc) {"doc" "I'm a docstring!"})))

(defmacro macroexpand-multi-assert-fail [#* macros]
  (let [s (lfor m macros
                `(try
                   (hy.macroexpand ~m)
                   (except [e hy.errors.HyMacroExpansionError])
                   (else
                     (assert False (.format "Compiling {} should have failed" ~m)))))]
    `(do ~s)))

(defn test-defop-fail []
  (macroexpand-multi-assert-fail
    '(defop op1 "no" {})
    '(defop op1 [] "maybe")))
