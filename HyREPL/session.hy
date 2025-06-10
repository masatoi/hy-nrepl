(import sys
        logging
        uuid [uuid4]
        threading [Lock]
        types)
(import HyREPL.bencode [encode])
(import HyREPL.ops.utils [find-op])
(import hyrule [assoc])
(require hyrule [unless])

(defclass Session []
  (setv status "")
  (setv eval-id "")
  (setv stdin-id None)
  (setv repl None)
  (setv last-traceback None)
  (setv module None)
  (setv locals None)

  (defn __init__ [self [module None]]
    (setv self.id (str (uuid4)))
    ;; Keep backward compatibility with ``self.uuid`` used by server
    (setv self.uuid self.id)
    (setv self.lock (Lock))
    (when (is module None)
      (setv module (types.ModuleType f"hyrepl-session-{self.id}")))
    (setv self.module module)
    (setv self.locals module.__dict__)
    None)

  (defn __str__ [self]
    self.id)

  (defn __repr__ [self]
    self.id)

  (defn write [self msg transport]
    (assert (in "id" msg))
    (unless (in "session" msg)
      (assoc msg "session" self.id))
    (logging.info "out: %s" msg)
    (try
      (.sendall transport (encode msg))
      (except [e OSError]
        (print (.format "Client gone: {}" e) :file sys.stderr)
        (setv self.status "client_gone"))))

  (defn handle [self msg transport]
    (logging.info "in: %s" msg)
    ((find-op (.get msg "op")) self msg transport)))

(defclass SessionRegistry []
  (defn __init__ [self]
    (setv self._sessions {})
    (setv self._lock (Lock))
    None)

  (defn create [self]
    (with [self._lock]
      (let [sess (Session)]
        (setv sess.registry self)
        (setv (get self._sessions sess.id) sess)
        (logging.debug "create session: %s, _sessions: %s" sess self._sessions)
        sess)))

  (defn get [self sid]
    (with [self._lock]
      (logging.debug "_sessions: %s, sid: %s" self._sessions sid)
      (.get self._sessions sid)))

  (defn remove [self sid]
    (with [self._lock]
      (.pop self._sessions sid None)))

  (defn list-ids [self]
    (with [self._lock]
      (list (self._sessions.keys)))))

