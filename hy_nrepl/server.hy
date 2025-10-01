(import sys
        threading
        time
        logging
        argparse
        socketserver [ThreadingMixIn TCPServer BaseRequestHandler]
        hy-nrepl.session [SessionRegistry]
        hy-nrepl.bencode [decode]
        hy-nrepl.backends [make-backend-factory]
        toolz [first last])

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

  (defn __init__ [self addr handler [backend-factory None] [backend-name "process"]]
    (.__init__ (super) addr handler)
    (setv self.session_registry (SessionRegistry backend-factory backend-name))))

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

(defn start-server [[ip "127.0.0.1"] [port 7888] [backend-factory None] [backend-name "process"]]
  (let [s (ReplServer #(ip port) ReplRequestHandler backend-factory backend-name)
        t (threading.Thread
            :target (fn []
                      (try
                        (s.serve-forever)
                        (except [e Exception]
                          (logging.exception "Server thread crashed")))))]
    (setv t.daemon True)
    (.start t)
    #(t s)))

(defn parse-args [argv]
  (let [parser (argparse.ArgumentParser :prog "hy-nrepl")]
    (.add_argument parser "-d" "--debug" :action "store_true" :dest "debug")
    (.add_argument parser "--eval-backend" :choices ["thread" "process"] :default "process")
    (.add_argument parser "port" :nargs "?" :default 7888 :type int)
    (.parse_args parser argv)))


(defmain [#* args]
  (setv argv (list args))
  (when (and (> (len argv) 0)
             (.endswith (first argv) ".hy"))
    (setv argv (list (cut argv 1 None))))
  (setv parsed (parse-args argv))

  (logging.basicConfig
    :level (if parsed.debug logging.DEBUG logging.WARNING)
    :format "%(levelname)s:%(module)s: %(message)s (at %(filename)s:%(lineno)d in %(funcName)s)")

  (logging.debug "Starting hy-nrepl: args=%s" args)

  (setv backend-name parsed.eval_backend)
  (setv backend-factory (make-backend-factory backend-name))
  (setv port parsed.port)
  (while True
    (try
       (start-server "127.0.0.1" port backend-factory backend-name)
       (except [e OSError]
         (setv port (inc port)))
       (else
         (print (.format "Listening on {}" port) :file sys.stderr)
         (while True
           (time.sleep 1))))))
