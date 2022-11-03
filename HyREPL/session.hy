(import sys
        uuid [uuid4]
        threading [Lock])

(import HyREPL [bencode])
(import HyREPL.ops [find-op])

(setv sessions {})

(defclass Session [object]
  (setv status "")
  (setv eval-id "")
  (setv repl None)
  (setv last-traceback None)

  (defn --init-- [self]
    (setv self.uuid (str (uuid4)))
    (assoc sessions self.uuid self)
    (setv self.lock (Lock))
    None)
  (defn --str-- [self]
    self.uuid)
  (defn --repr-- [self]
    self.uuid)
  (defn write [self msg transport]
    (assert (in "id" msg))
    (unless (in "session" msg)
      (assoc msg "session" self.uuid))
    (print "out:" msg :file sys.stderr)
    (try
      (do
        (print "=== in session.write ==========================")
        (print (type transport))
        (print (dir transport))
        (print (bencode.encode msg) :flush True)
        (.sendall transport (bencode.encode msg)))
      (except [e OSError]
        (print (.format "Client gone: {}" e) :file sys.stderr))))
  (defn handle [self msg transport]
    (print "in:" msg :file sys.stderr)
    ((find-op (.get msg "op")) self msg transport)))
