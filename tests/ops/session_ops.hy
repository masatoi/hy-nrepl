(import hy-nrepl.session [SessionRegistry Session])
(import hy-nrepl.ops.utils [find-op ops])
(import hy-nrepl.bencode [decode])
(import pytest)
(import toolz [first])
(import hyrule [assoc])
(import hy.models [Keyword])

;; Dummy transport to capture sendall data
(defclass DummyTransport []
  (defn __init__ [self]
    (setv self.sent []))
  (defn sendall [self data]
    (.append self.sent data)))

(defn decode-msg [data]
  (first (decode data)))

(defn create-session-with-registry []
  (let [registry (SessionRegistry)
        sess (registry.create)
        transport (DummyTransport)]
    [registry sess transport]))

(defn test_clone_creates_new_session []
  (let [[registry sess transport] (create-session-with-registry)
        msg {"id" "1"}]
    ((find-op "clone") sess msg transport)
    ;; exactly one message was sent
    (assert (= (len transport.sent) 1))
    (let [response (decode-msg (get transport.sent 0))]
      ;; check status and id
      (assert (= (get response "status") ["done"]))
      (assert (= (get response "id") "1"))
      ;; new session id returned and stored in registry
      (setv new-id (get response "new-session"))
      (assert new-id)
      (assert (in new-id (registry.list-ids)))
      ;; ensure original session id in response session field
      (assert (= (get response "session") sess.id)))))

(defn test_close_removes_session []
  (let [registry (SessionRegistry)
        s1 (registry.create)
        s2 (registry.create)
        transport (DummyTransport)
        msg {"id" "close" "session" s1.id}]
    ((find-op "close") s1 msg transport)
    ;; message should indicate done and session id
    (let [resp (decode-msg (get transport.sent 0))]
      (assert (= (get resp "status") ["done"]))
      (assert (= (get resp "session") s1.id))
      (assert (= (get resp "id") "close")))
    ;; session should be removed
    (assert (is (registry.get s1.id) None))
    ;; other session still present
    (assert (= (registry.get s2.id) s2))))

(defn test_ls_sessions_lists_all []
  (let [registry (SessionRegistry)
        s1 (registry.create)
        s2 (registry.create)
        transport (DummyTransport)
        msg {"id" "ls"}]
    ((find-op "ls-sessions") s1 msg transport)
    (let [resp (decode-msg (get transport.sent 0))]
      (assert (= (get resp "status") ["done"]))
      ;; returned ids should contain both sessions
      (assert (= (set (get resp "sessions")) #{s1.id s2.id}))
      (assert (= (get resp "session") s1.id))
      (assert (= (get resp "id") "ls")))))

(defn test_describe_returns_ops []
  (let [[registry sess transport] (create-session-with-registry)
        msg {"id" "desc"}]
    ((find-op "describe") sess msg transport)
    (let [resp (decode-msg (get transport.sent 0))]
      (assert (= (get resp "status") ["done"]))
      (assert (in "ops" resp))
      (assert (in "versions" resp))
      (assert (in "clone" (.keys (get resp "ops")))))))

(defn test_load_file_delegates_to_eval []
  (let [[registry sess transport] (create-session-with-registry)
        old-eval (get ops "eval")
        old-f (get old-eval :f)]
    ;; stub eval op simply returns without side effects
    (assoc old-eval (Keyword "f") (fn [#* _] None))
    (let [msg {"id" "load" "file" "foo.clj  (print 3)"}]
      ((find-op "load-file") sess msg transport)
      ;; restore eval
      (assoc old-eval (Keyword "f") old-f)
      ;; verify msg transformed for eval
      (assert (= (get msg "code") "(print 3)"))
      (assert (not (in "file" msg)))))
)
