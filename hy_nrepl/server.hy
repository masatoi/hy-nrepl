(import sys
        threading
        time
        logging
        socketserver [ThreadingMixIn TCPServer BaseRequestHandler]
        hy-nrepl.session [SessionRegistry]
        hy-nrepl.bencode [decode]
        toolz [last])

;; TODO: move these includes somewhere else
;; (import hy-nrepl.ops [eval complete info])
(import hy-nrepl.ops)

(import hyrule [inc])
(require hyrule [defmain unless])


;; When this file is executed as a script (e.g. via `hy -m hy-nrepl.server`),
;; Python registers the module under the name `__main__`.  Other modules
;; import it using the package name `hy-nrepl.server`, which would normally
;; create a second instance of this module.  To ensure a single shared
;; instance, register this module under its package name when running as
;; `__main__`.
(when (= __name__ "__main__")
  (setv (get sys.modules "hy-nrepl.server") (get sys.modules __name__)))

(defclass ReplServer [TCPServer ThreadingMixIn]
  (setv allow-reuse-address True)

  (defn __init__ [self addr handler]
    (.__init__ (super) addr handler)
    (setv self.session_registry (SessionRegistry))))

(defclass ReplRequestHandler [BaseRequestHandler]
  (defn handle [self]
    (print "New client" :file sys.stderr)

    ;; Initializes instance session
    (setv self.session None)

    (try
      (let [buf (bytearray)
            tmp None
            msg #()]
        (while True
          (try
            (setv tmp (.recv self.request 1024))
            (except [e OSError]
              (break)))
          (when (= (len tmp) 0)
            (break))
          (.extend buf tmp)
          (try
            (do
              (setv m (decode buf))
              (.clear buf)
              (.extend buf (get m 1)))
            (except [e Exception]
              (print e :file sys.stderr)
              (continue)))

          (logging.debug "message=%s" m)
          (setv req (get m 0))
          (setv sid (.get req "session"))
          (logging.debug "sid=%s" sid)

          ;; Create session if not exist
          (unless self.session
            (when sid
              (setv self.session (self.server.session_registry.get sid)))
            (unless self.session
              (logging.debug "session not found and created: finding session id=%s" sid)
              (setv self.session (self.server.session_registry.create))))
          (when self.session
            (setv self.session.registry self.server.session_registry))

          ;; Switch requested session
          (when (and sid (not (= self.session.uuid sid)))
            (setv self.session (self.server.session_registry.get sid))
            (when self.session
              (setv self.session.registry self.server.session_registry)))

          (logging.debug "create or found session=%s" self.session)

          (try
            (self.session.handle req self.request)
            (except [e Exception]
              (logging.exception "Error handling request: %s" req)
              (break)))
        )
      )
      (except [e Exception]
          (logging.exception "Unhandled exception in request handler"))
        (finally
          ;; The handler thread exits here, but serve-forever keeps running
          ;; so the server will continue accepting new clients.
          (logging.info "Client gone")))))

(defn start-server [[ip "127.0.0.1"] [port 7888]]
  (let [s (ReplServer #(ip port) ReplRequestHandler)
        t (threading.Thread
            :target (fn []
                      (try
                        (s.serve-forever)
                        (except [e Exception]
                          (logging.exception "Server thread crashed")))))]
    (setv t.daemon True)
    (.start t)
    #(t s)))

(defmain [#* args]

  ;; Show usage
  (when (or (in "-h" args)
            (in "--help" args))
    (print "Usage:
  hy-nrepl [-d | --debug] [-h | --help] [<port>]

Options:
  -h, --help      Show this usage
  -d, --debug     Debug mode (true/false) [default: false]
  <port>          Port number [default: 7888]")
    (return 0))

  ;; Settings for logging
  (logging.basicConfig
    :level (if (or (in "-d" args)
                   (in "--debug" args))
               logging.DEBUG
               logging.WARNING)
    :format "%(levelname)s:%(module)s: %(message)s (at %(filename)s:%(lineno)d in %(funcName)s)")

  (logging.debug "Starting hy-nrepl: args=%s" args)

  (setv port
        (if (> (len args) 0)
            (try
              (int (last args))
              (except [_ ValueError]
                7888))
            7888))
  (while True
    (try
       (start-server "127.0.0.1" port)
       (except [e OSError]
         (setv port (inc port)))
       (else
         (print (.format "Listening on {}" port) :file sys.stderr)
         (while True
           (time.sleep 1))))))
