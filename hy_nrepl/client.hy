;; Import necessary modules and functions
(import socket
        time
        uuid [uuid4])
(import hy-nrepl.bencode [encode decode])
(require hyrule [unless])

;;; --- nREPL Client ---

(defclass NreplClient []
  (defn __init__ [self host port [timeout 5] [sock None]]
    (setv self.host host
          self.port port
          self.timeout timeout
          self.socket (or sock
                          (socket.create_connection (tuple [host port])
                                                    :timeout timeout))
          self.buffer (bytearray))
    (print f"NreplClient connected to {host}:{port}"))

  (defn close [self]
    (when self.socket
      (print "Closing NreplClient connection.")
      (self.socket.close)
      (setv self.socket None)))

  (defn send [self op [params None] [msg-id (str (uuid4))]]
    (unless self.socket (raise (RuntimeError "Socket is not connected")))
    (let [base-request {"op" op "id" msg-id}
          request (if params {#** base-request #** params} base-request)
          encoded-request (encode request)]
      (print f"Sending: {request}")
      (try
        (.sendall self.socket encoded-request)
        (except [e OSError]
          (print f"Error sending request: {e}")
          (self.close)))))

  (defn receive [self [timeout None]]
    "Receives and decodes a single nREPL response, maintaining buffer state."
    (unless self.socket (raise (RuntimeError "Socket is not connected")))
    (setv timeout (or timeout self.timeout))
    (.settimeout self.socket timeout)
    (setv start-time (time.time))

    (while True ; Loop until one message can be decoded
      ;; 1. first try to decode from existing instance buffer
      (when (> (len self.buffer) 0)
        (try
          (let [[decoded-msg remaining-buffer] (decode (bytes self.buffer))]
            (print f"Received (from buffer): {decoded-msg}")
            (setv self.buffer (bytearray remaining-buffer))
            (return decoded-msg)) ; Decode succeeded, message returned
          (except [e ValueError]
            (print f"Incomplete data in buffer (len={(len self.buffer)}), need more data...")
            ;; Proceed to recv without breaking because of insufficient data
            None)
          (except [e Exception]
            (print f"Error decoding response from buffer: {e}")
            (.clear self.buffer)
            (return None))))

      ;; 2. timeout check
      (when (>= (- (time.time) start-time) timeout)
        (print f"No complete response received within timeout.")
        (return None))

      ;; 3. could not decode from buffer or received if buffer is empty
      (try
        (let [chunk (.recv self.socket 4096)]
          (unless chunk
            (print "Connection closed by server (received empty bytes).")
            (self.close)
            (return None))
          (print f"Received {(len chunk)} bytes from socket.")
          (.extend self.buffer chunk))
        (except [e socket.timeout]
          (print "Socket timeout during recv.")
          None)
        (except [e OSError]
          (print f"Socket error: {e}")
          (self.close)
          (return None))))
    (print "Exited receive loop unexpectedly.")
    (return None))

  (defn __enter__ [self] self)
  (defn __exit__ [self exc-type exc-val exc-tb] (self.close)))

;; (with [client (NreplClient "localhost" 7888)]
;;   (print client))
