(import sys)

(import HyREPL.ops [ops find-op])
(require HyREPL.ops [defop])

;; These are needed after the macro expansion of defops so need import here.
(require hyrule [unless])
(import toolz [first second nth])

(defmacro assert-multi [#* cases]
  (let [s (lfor c cases `(assert ~c))]
    `(do ~s)))

(defclass MockSession []
  (defn __init__ [self]
    (setv self.messages [])
    None)

  (defn write [self msg transport]
    (.append self.messages msg)))
  
(defn test-defop-verify-message []
  (let [s (MockSession)
        msg-local None]
    (defop "vtest1-requires" [session msg transport]
      {"requires" {"foo" "the foo"}}
      (.write session (.get msg "foo") transport))
    ((find-op "vtest1-requires")
      s {} None)
    ((find-op "vtest1-requires")
      s {"foo" 'bar} None)
    (assert-multi (= (len s.messages) 2)
                  (= (first s.messages) {"status" ["done"]
                                         "id" None
                                         "missing" "foo"})
                  (= (second s.messages) 'bar))))

(defn test-defop-verify-message-eval []
  (let [s (MockSession)]
    (defop eval1 [session msg transport]
      {"doc" "Evaluates code."
       "requires" {"code" "The code to be evaluated"}
       "optional" {"session" (+ "The ID of the session in which the code will"
                                " be evaluated. If absent, a new session will"
                                " be generated")
                   "id" "An opaque message ID that will be included in the response"}
       "returns" {"ex" "Type of the exception thrown, if any. If present, `value` will be absent."
                  "ns" (+ "The current namespace after the evaluation of `code`."
                          " For HyREPL, this will always be `Hy`.")
                  "root-ex" "Same as `ex`"
                  "value" (+ "The values returned by `code` if execution was"
                             " successful. Absent if `ex` and `root-ex` are"
                             " present")}}
      (print (.format "msg: {}" (get msg "code")) :flush True)
      (.write session (.get msg "code") transport)
      (.write session (.get msg "session") transport))

    ((find-op "eval1")
      s {"code" "(+ 2 2)" "session" 'bar} None)

    (print (.format "message: {}" s.messages) :flush True)))

(defn test-defop-success []
  (defop o1 [] {})
  (defop o2 [a] {})
  (defop o3 [] {"doc" "I'm a docstring!"})
  (defop "o4-something.foo" [] {})

  (assert-multi
    (in "o1" ops)
    (in "o2" ops)
    (in "o3" ops)
    (in "o4-something.foo" ops)
    (= (get ops "o3" :desc) {"doc" "I'm a docstring!"})))

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
