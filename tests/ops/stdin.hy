(import HyREPL.session [Session])
(import HyREPL.ops.utils [find-op])
(import queue [Queue])
(import uuid [uuid4])
(import sys)

(defn test-stdin-op []
  (let [session (Session)
        fake-stdin (Queue)
        msg {"id" (str (uuid4))
             "stdin" "sample input"}
        old-stdin sys.stdin]
    (setv sys.stdin fake-stdin)
    (try
      ;; Call the op
      ((find-op "stdin") session msg None)
      ;; Verify session stdin-id updated
      (assert (= session.stdin-id (.get msg "id")))
      ;; Verify the queued stdin value
      (assert (= (.get fake-stdin False) "sample input"))
      (finally
        ;; Restore original stdin
        (setv sys.stdin old-stdin)))))
