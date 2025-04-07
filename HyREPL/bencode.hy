(import logging)
(import toolz [first second])
(import hyrule [inc assoc])

(defreader b
  (setv expr (.parse-one-form &reader))
  `(bytes ~expr "utf-8"))

(defn decode-multiple [thing]
  "Uses `decode` to decode all encoded values in `thing`."
  (let [r [] i #() t thing]
    (while (> (len t) 0)
      (setv i (decode t))
      (.append r (first i))
      (setv t (second i)))
    r))

;; Check if the first byte value is between ord('0') and ord('9')
(defn is-first-byte-digit [bytes]
  (and (> (len bytes) 0)
       (let [first-byte-val (get bytes 0)] ; Get the integer byte value
         (and (>= first-byte-val (ord "0")) ; ord gets ASCII value of char '0'
              (<= first-byte-val (ord "9")))))) ; ord gets ASCII value of char '9'

(defn decode [thing]
  "Decodes `thing` and returns the first parsed bencode value encountered
as well as the unparsed rest"

  (when (= (len thing) 0)
    (raise (ValueError "Invalid byte string (Empty byte string)")))

  (cond
    ;; Dictionary
    (.startswith thing #b"d")
    (decode-dict (cut thing 1 None))

    ;; List
    (.startswith thing #b"l")
    (decode-list (cut thing 1 None))

    ;; Integer
    (.startswith thing #b"i")
    (decode-int (cut thing 1 None))

    ;; Byte String (delegate to decode-str)
    ;; Check if the first character is a digit, which indicates a byte string.
    ;; This helps catch invalid starting characters earlier.
    (and (> (len thing) 0) (is-first-byte-digit thing))
    (decode-str thing)

    ;; --- Handle invalid starting characters ---
    True
    (raise (ValueError (+ "Invalid bencode starting character: " (repr (cut thing 0 1)))))))

(defn decode-str [thing]
  "Decodes a bencoded byte string from the beginning of 'thing'.
  Assumes 'thing' starts with the length prefix (e.g., '3:foo...').
  Returns a tuple (list in Hy) of #(decoded_utf8_string rest_bytes)."
  (let [delim (.find thing #b":")]

    ;; Check 1: Colon must exist.
    (when (= delim -1)
      (raise (ValueError (+ "Invalid byte string format (missing colon): " (repr thing)))))

    ;; Check 2: Length part cannot be empty.
    (when (= delim 0)
      (raise (ValueError (+ "Invalid byte string format (empty length part): " (repr thing)))))

    ;; Extract length part (as bytes)
    (let [size-bytes (cut thing 0 delim)]

      ;; Check 3: Bencode spec validation for length format (no leading zeros except for '0').
      (when (and (!= size-bytes #b"0")
                 (> (len size-bytes) 1)
                 (= (. size-bytes [0]) (ord #b"0")))
        (raise (ValueError (+ "Invalid byte string format (leading zero in length): " (repr size-bytes)))))

      ;; Try parsing the length, handle non-integer length.
      (try
        (let [size (int size-bytes 10)] ; Convert length bytes to int.

          ;; Check 4: Size must not be negative.
          (when (< size 0)
            (raise (ValueError (+ "Invalid byte string format (negative size specified): " (repr size-bytes)))))

          ;; Calculate expected data start and end indices.
          (let [data-start (inc delim)
                data-end (+ data-start size)]

            ;; Check 5: Ensure enough data exists (EOF check).
            (when (> data-end (len thing))
              (raise (ValueError (+ "Invalid byte string (unexpected EOF, data shorter than size " (str size) "): " (repr thing)))))

            ;; If all checks pass, extract data and rest.
            (let [data (cut thing data-start data-end)
                  rest (cut thing data-end None)]
              ;; Decode the extracted bytes as UTF-8 string for the result.
              #((.decode data "utf-8") rest)))) ; Return #(decoded_string, rest_bytes)

        ;; Catch errors during int(size-bytes) conversion (e.g., "abc:").
        (except [e ValueError]
          (raise (ValueError (+ "Invalid byte string format (non-integer size): " (repr size-bytes)))))))))

(defn decode-int [thing]
  (let [end (.find thing #b"e")]
    ;; Check if 'e' was found
    (when (= end -1)
      (raise (ValueError "Integer encoding not terminated by 'e'")))
    ;; Check for empty integer like 'ie'
    (when (= end 0)
      (raise (ValueError "Empty integer encoding 'ie' is invalid")))
    ;; Extract the numerical part
    (let [num-bytes (cut thing 0 end)]
      ;; --- Bencode specific format checks ---
      ;; 1. Check for invalid leading zeros (only "0" is allowed to start with 0)
      (when (and (!= num-bytes #b"0") ; Allow "0" itself
                 (> (len num-bytes) 1) ; Check only if longer than 1 char
                 (= (. num-bytes [0]) (ord #b"0"))) ; Starts with '0'
        (raise (ValueError (+ "Invalid integer format (leading zero): " (repr num-bytes)))))
      ;; 2. Check for invalid negative zero "-0"
      (when (= num-bytes #b"-0")
        (raise (ValueError "Invalid integer format (negative zero '-0')")))
      ;; 3. Check for invalid negative number with leading zero (e.g., "-01")
      (when (and (> (len num-bytes) 2) ; Must be at least "-0?"
                 (= (. num-bytes [0]) (ord #b"-"))
                 (= (. num-bytes [1]) (ord #b"0")))
        (raise (ValueError (+ "Invalid integer format (negative leading zero): " (repr num-bytes)))))
      ;; 4. Check for "-" only
      (when (= num-bytes #b"-")
        (raise (ValueError "Invalid integer format (just '-'): " (repr num-bytes))))

      ;; 5. Add check for explicit '+' sign (Invalid in Bencode)
      (when (and (> (len num-bytes) 0)
                 (= (. num-bytes [0]) (ord #b"+")))
        (raise (ValueError (+ "Invalid integer format (explicit '+'): " (repr num-bytes)))))
      ;; --- End of Bencode specific checks ---

      ;; Try converting to integer (catches other errors like non-digits)
      (try
        (let [num (int num-bytes 10)]
          ;; Return the integer and the rest of the bytes after 'e'
          #(num (cut thing (inc end) None)))
        (except [e ValueError]
          ;; Catch Python's ValueError during int conversion (e.g., "i--e", "iabe")
          (raise (ValueError (+ "Invalid integer format near: " (repr num-bytes)))))))))

(defn decode-list [thing]
  "Decodes a bencoded list from the beginning of 'thing'."
  ;; Check if it's an empty list right away ('e' follows the initial 'l')
  (if (.startswith thing #b"e")
      #([] (cut thing 1 None)) ; Return empty list and the rest after 'e'
      (let [rv [] ; Result list
            i #() ; Temporary tuple for decoded item and rest #(item rest-bytes)
            t thing] ; Remaining bytes to process
        (while True ; Loop until 'e' is found or an error occurs
          ;; Check for the end marker *before* trying to decode an item
          (when (.startswith t #b"e")
            (setv t (cut t 1 None)) ; Consume the 'e'
            (break)) ; Exit the loop successfully

          ;; Check for premature end of input (no 'e' found before bytes ran out)
          (when (= (len t) 0)
            (raise (ValueError "List ended unexpectedly without 'e' marker")))

          ;; Decode the next item in the list
          (setv i (decode t))
          (.append rv (first i)) ; Add decoded item to the result list
          (setv t (second i))) ; Update remaining bytes

        ;; Return the populated list and the rest of the bytes after the list
        #(rv t))))

(defn decode-dict [thing]
  (let [result {}
        key #()
        val #()]
    (while (> (len thing) 0)
      (when (.startswith thing #b"e")
        (break))
      (setv key (decode thing)) ; #(key rest)
      (setv val (decode (second key)))
      (setv thing (second val))
      (assoc result (first key) (first val)))
    (when (= (len thing) 0)
      (raise (ValueError "Dictionary without end marker")))
    #(result (cut thing 1 None))))

(defn encode [thing]
  "Returns a bencoded string that represents `thing`. Might throw all sorts
of exceptions if you try to encode weird things. Don't do that."
  (cond (isinstance thing int)
        (encode-int thing)

        (isinstance thing str)
        (encode-str thing)

        (isinstance thing bytes)
        (encode-bytes thing)

        (isinstance thing dict)
        (encode-dict thing)

        (is thing None)
        (encode-bytes #b"")

        True ; assume iterable
        (encode-list thing)))

(defn encode-int [thing]
  #b(.format "i{}e" thing))

(defn encode-str [thing]
  #b(.format "{}:{}" (len #b thing) thing))

(defn encode-bytes [thing]
  ;; Calculate length, encode length as utf-8 bytes, append colon and raw bytes
  (let [len-str (str (len thing))
        len-bytes (.encode len-str "utf-8")]
    (+ len-bytes #b":" thing))) ; Append original bytes `thing` directly

(defn encode-dict [thing]
  "Encodes a dictionary according to Bencode specification.
  Keys must be strings and are sorted based on their UTF-8 byte representation."
  (let [rv (bytearray #b"d")
        ;; Get keys as strings and sort them based on their UTF-8 byte representation
        ;; According to the Bencode spec, keys must be strings
        ;; Also, keys must be sorted lexicographically as byte strings
        sorted-keys (sorted (.keys thing) :key (fn [k] (.encode k "utf-8")))]
    (for [k sorted-keys]
      ;; Encode the key (string)
      ;; The encode function determines the type internally and calls encode-str for strings
      (.extend rv (encode k))
      ;; Encode the corresponding value
      (.extend rv (encode (get thing k))))
    (.extend rv #b"e")
    (bytes rv)))

(defn encode-list [thing]
  (let [rv (bytearray #b"l")]
    (for [i thing]
      (.extend rv (encode i)))
    (.extend rv #b"e")
    (bytes rv)))
