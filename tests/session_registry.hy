(import hy-nrepl.session [Session SessionRegistry])

(defn test-create-and-get []
  (let [registry (SessionRegistry)
        s1 (.create registry)
        s2 (.create registry)]
    (assert (isinstance s1 Session))
    (assert (isinstance s2 Session))
    (assert (= (.get registry s1.id) s1))
    (assert (= (.get registry s2.id) s2))
    (assert (= (set (.list-ids registry)) #{s1.id s2.id}))))

(defn test-get-missing []
  (let [registry (SessionRegistry)]
    (assert (is (.get registry "missing") None))))

(defn test-remove []
  (let [registry (SessionRegistry)
        s1 (.create registry)
        s2 (.create registry)]
    (.remove registry s1.id)
    (assert (is (.get registry s1.id) None))
    (assert (= (set (.list-ids registry)) #{s2.id}))))

(defn test-list-ids []
  (let [registry (SessionRegistry)
        s1 (.create registry)
        s2 (.create registry)]
    (assert (= (set (.list-ids registry)) #{s1.id s2.id}))
    (assert (= (len (.list-ids registry)) 2))))
