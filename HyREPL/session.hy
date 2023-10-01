(import sys
        uuid [uuid4]
        threading [Lock])
(import HyREPL.bencode [encode])
(import HyREPL.ops [find-op])
(require hyrule [assoc unless])
(import hy.repl)

(setv sessions {})

(defclass Session [object]
  (setv status "")
  (setv eval-id "")
  (setv repl None)
  (setv last-traceback None)
  (setv module None)
  (setv locals None)

  (defn __init__ [self]
    (print "Session.__init__") ; debug
    (setv self.uuid (str (uuid4)))
    (assoc sessions self.uuid self)
    (setv self.lock (Lock))
    (setv self.module hy.repl)
    (setv self.locals hy.repl.__dict__)
    None)

  (defn __str__ [self]
    self.uuid)

  (defn __repr__ [self]
    self.uuid)

  (defn write [self msg transport]
    (assert (in "id" msg))
    (unless (in "session" msg)
      (assoc msg "session" self.uuid))
    (print "DEBUG[Session.write]: out:" msg :flush True)
    (print "out:" msg :file sys.stderr)
    (try
      (do
        (print "=== in session.write ==========================")
        (print (encode msg) :flush True)
        (.sendall transport (encode msg)))
      (except [e OSError]
        (print (.format "DEBUG[Session.write] Client gone: {}" e) :flush True) ; debug
        (print (.format "Client gone: {}" e) :file sys.stderr)
        (setv self.status "client_gone"))))
  (defn handle [self msg transport]
    (print (.format "DEBUG[Session.handle]: msg: {}, transport: {}" msg transport) :flush True) ; debug
    (print "in:" msg :file sys.stderr)
    ((find-op (.get msg "op")) self msg transport)))
