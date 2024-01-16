(import toolz [first second])
(import HyREPL.bencode [encode decode decode-multiple])
(require hyrule [->])

(defreader b
  (setv expr (.parse-one-form &reader))
  `(bytes ~expr "utf-8"))

(defn test-bencode []
  (let [d {"foo" 42 "spam" [1 2 "a"]}]
    (assert (= d (-> d encode decode first))))

  (let [d {}]
    (assert (= d (-> d encode decode first))))

  (let [d {"requires" {}
           "optional" {"session" "The session to be cloned."}}]
    (assert (= d (-> d encode decode first))))

  (let [d (decode-multiple (+ #b"d5:value1:47:session36:31594b80-7f2e-4915-9969-f1127d562cc42:ns2:Hye"
                              #b"d6:statusl4:donee7:session36:31594b80-7f2e-4915-9969-f1127d562cc4e"))]
    (assert (= (len d) 2))
    (assert (isinstance (first d) dict))
    (assert (isinstance (second d) dict))
    (assert (= (. d [0] ["value"]) "4"))
    (assert (= (. d [0] ["ns"]) "Hy"))
    (assert (isinstance (. d [1] ["status"]) list))
    (assert (= (len (. d [1] ["status"])) 1))
    (assert (= (. d [1] ["status"] [0]) "done"))))
