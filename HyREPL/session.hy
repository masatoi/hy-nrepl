(import sys
        logging
        uuid [uuid4]
        threading [Lock])
(import HyREPL.bencode [encode])
(import HyREPL.ops.utils [find-op])
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

  (defn __init__ [self [module hy.repl]]
    (setv self.uuid (str (uuid4)))
    (assoc sessions self.uuid self)
    (setv self.lock (Lock))
    (setv self.module module)
    (setv self.locals module.__dict__)
    None)

  (defn __str__ [self]
    self.uuid)

  (defn __repr__ [self]
    self.uuid)

  (defn write [self msg transport]
    (assert (in "id" msg))
    (unless (in "session" msg)
      (assoc msg "session" self.uuid))
    (logging.info "out: %s" msg)
    (try
      (.sendall transport (encode msg))
      (except [e OSError]
        (print (.format "Client gone: {}" e) :file sys.stderr)
        (setv self.status "client_gone"))))

  (defn handle [self msg transport]
    (logging.info "in: %s" msg)
    ((find-op (.get msg "op")) self msg transport)))
