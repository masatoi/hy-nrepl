(import
  sys
  threading
  time
  socketserver [ThreadingMixIn TCPServer BaseRequestHandler])

(import HyREPL.session [sessions Session])
(import HyREPL.bencode [decode])
(import toolz [last])

;; TODO: move these includes somewhere else
(import HyREPL.middleware [test eval complete info])

(import hyrule [inc])
(require hyrule [defmain])

(defclass ReplServer [TCPServer] ; ThreadingMixIn 
  (setv allow-reuse-address True))

(defclass ReplRequestHandler [BaseRequestHandler]
  (setv session None)
  (defn handle [self]
    (print "New client" :file sys.stderr)
    (let [buf (bytearray)
          tmp None
          msg #()]
      (while True
        (try
          (setv tmp (.recv self.request 1024))
          (except [e OSError]
            (break)))
        (print (.format "DEBUG ReplRequestHandler.handle tmp: {}" tmp)) ; debug
        (when (= (len tmp) 0)
          (break))
        (.extend buf tmp)
        (print (.format "DEBUG ReplRequestHandler.handle buf: {}" buf)) ; debug
        (try
          (do
            (print "before decode") ; debug
            (setv m (decode buf))
            (print (.format "DEGUB ReplRequestHandler.handle m: {}" m)) ; debug
            (.clear buf)
            (.extend buf (get m 1)))
          (except [e Exception]
            (print e :file sys.stderr)
            (continue)))
        (print (.format "DEBUG self.session: {}" self.session)) ; debug

        ;; Create session if not exist
        (when (is self.session None)
          (print (.format "DEBUG sessions: {}" sessions)) ; debug
          (setv self.session (.get sessions (.get (get m 0) "session")))
          (when (is self.session None)
            (print "DEBUG ReplRequestHandler.handle: session is None, create new Session") ; debug
            (setv self.session (Session))))

        (print (.format "DEBUG: self.session: {}, (get m 0): {}, self.request: {}"
                        self.session (get m 0) self.request)
               :flush True) ; debug
        
        (print (.format "DEBUG call session.handle: self.session.handle: {}, (get m 0): {}, self.request: {}"
                        self.session.handle (get m 0) self.request)
               :flush True) ; debug

        (self.session.handle (get m 0) self.request))
      (print "Client gone" :file sys.stderr))))

(defn start-server [[ip "127.0.0.1"] [port 1337]]
  (let [s (ReplServer #(ip port) ReplRequestHandler)
        t (threading.Thread :target s.serve-forever)]
    (setv t.daemon True)
    (.start t)
    #(t s)))

(defmain [#* args]
  (setv port
        (if (> (len args) 0)
            (try
              (int (last args))
              (except [_ ValueError]
                1337))
            1337))
  (while True
    (try
       (start-server "127.0.0.1" port)
       (except [e OSError]
         (setv port (inc port)))
       (else
         (print (.format "Listening on {}" port) :file sys.stderr)
         (while True
           (time.sleep 1))))))
