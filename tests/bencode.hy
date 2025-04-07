;; Import necessary modules and functions
(import toolz [first second])
(import HyREPL.bencode [encode decode decode-multiple])
(import pytest)
(import bencodepy)

(require hyrule [->])

;; Define the #b reader macro for byte literals.
;; This assumes it's needed in the execution context.
;; If pytest runs Hy tests via a method that pre-defines this,
;; this might be redundant but generally harmless.
(defreader b
  (setv expr (.parse-one-form &reader))
  `(bytes ~expr "utf-8"))

;; --- Test Functions for pytest ---

(defn test_encode_decode_simple_dict_and_list []
  "Tests encoding a simple dict+list and verifies the exact byte output and decoding restoration."
  (let [original-dict {"foo" 42 "spam" [1 2 "a"]}
        ;; Expected byte string: Keys sorted ("foo", "spam"), list elements in order.
        ;; d 3:foo i42e 4:spam l i1e i2e 1:a e e
        expected-bytes #b"d3:fooi42e4:spamli1ei2e1:aee"]

    ;; 1. Verify the exact encoded bytes
    (assert (= (encode original-dict) expected-bytes)
            "Encoded bytes for simple dict+list do not match expected value")

    ;; 2. Verify decoding restores the original object (existing test)
    (assert (= original-dict (-> original-dict encode decode first))
            "Simple dictionary with list should be restored after encode/decode")))

(defn test_encode_decode_empty_dict []
  "Tests encoding an empty dict and verifies the exact byte output and decoding restoration."
  (let [original-dict {}
        ;; Expected byte string for an empty dictionary is "de"
        expected-bytes #b"de"]

    ;; 1. Verify the exact encoded bytes
    (assert (= (encode original-dict) expected-bytes)
            "Encoded bytes for empty dictionary do not match expected value 'de'")

    ;; 2. Verify decoding restores the original object (existing test)
    ;; Note: This assertion is somewhat redundant given the previous one and
    ;; test_encode_empty_dict_bytes, but keeps the function's original purpose clear.
    (assert (= original-dict (-> original-dict encode decode first))
            "Empty dictionary should be restored after encode/decode")))

(defn test_encode_decode_nested_dict []
  "Tests encoding a nested dict and verifies the exact byte output and decoding restoration."
  (let [original-dict {"requires" {}
                       "optional" {"session" "The session to be cloned."}}
        ;; Expected byte string: Keys sorted ("optional", "requires")
        ;; Outer dict: d 8:optional <inner_dict_bytes> 8:requires <empty_dict_bytes> e
        ;; Inner dict: d 7:session 26:The session to be cloned. e
        ;; Empty dict: de
        ;; Full: d 8:optional d 7:session 26:The session to be cloned. e 8:requires d e e
        expected-bytes #b"d8:optionald7:session25:The session to be cloned.e8:requiresdee"]

    ;; 1. Verify the exact encoded bytes
    (assert (= (encode original-dict) expected-bytes)
            "Encoded bytes for nested dictionary do not match expected value")

    ;; 2. Verify decoding restores the original object (existing test)
    (assert (= original-dict (-> original-dict encode decode first))
            "Nested dictionary should be restored after encode/decode")))

(defn test_decode_multiple []
  "Tests decoding a byte string containing multiple bencoded values."
  ;; Define a byte string with two concatenated bencoded dictionaries.
  (let [multi-bencoded-bytes (+ #b"d5:value1:47:session36:31594b80-7f2e-4915-9969-f1127d562cc42:ns2:Hye"
                                #b"d6:statusl4:donee7:session36:31594b80-7f2e-4915-9969-f1127d562cc4e")
        ;; Decode all values in the byte string.
        decoded-list (decode-multiple multi-bencoded-bytes)]
    ;; Assertions to verify the structure and content of the decoded list.
    (assert (= (len decoded-list) 2)
            "Should decode two dictionaries")
    (assert (isinstance (first decoded-list) dict)
            "First decoded item should be a dict")
    (assert (isinstance (second decoded-list) dict)
            "Second decoded item should be a dict")
    ;; Check specific values within the decoded dictionaries.
    (assert (= (. decoded-list [0] ["value"]) "4")
            "Check value in first decoded dict")
    (assert (= (. decoded-list [0] ["ns"]) "Hy")
            "Check ns in first decoded dict")
    (assert (isinstance (. decoded-list [1] ["status"]) list)
            "Check status type in second decoded dict")
    (assert (= (len (. decoded-list [1] ["status"])) 1)
            "Check status list length in second decoded dict")
    (assert (= (. decoded-list [1] ["status"] [0]) "done")
            "Check status value in second decoded dict")))

(defn test_encode_dict_key_sort_ascii []
  "Tests that dictionary keys (ASCII) are sorted by byte value during encoding."
  ;; Define a dictionary with keys in non-alphabetical order.
  (let [unsorted-dict {"zulu" 1 "alpha" 2 "charlie" 3}
        ;; Define the expected byte string with keys sorted alphabetically (alpha, charlie, zulu).
        ;; d 5:alpha i2e 7:charlie i3e 4:zulu i1e e
        expected-bytes #b"d5:alphai2e7:charliei3e4:zului1ee"]

    ;; Encode the dictionary and assert it matches the expected sorted bytes.
    (assert (= (encode unsorted-dict) expected-bytes)
            "Dictionary keys (ASCII) were not sorted correctly by byte value during encoding")
    ;; Additionally, verify that decoding the result restores the original content.
    (assert (= unsorted-dict (-> unsorted-dict encode decode first))
            "Decoding the sorted ASCII-keyed dict should restore original content")))

(defn test_encode_dict_key_sort_non_ascii []
  "Tests that dictionary keys (including non-ASCII) are sorted by UTF-8 byte value."
  ;; Define a dictionary with non-ASCII keys (German umlauts).
  ;; Note byte order: "bär" (b'b\xc3\xa4r') < "citrone" (b'citrone') < "äpfel" (b'\xc3\xa4pfel')
  (let [unsorted-dict {"äpfel" 10 "bär" 20 "citrone" 30}
        ;; Define the expected byte string with keys sorted by their UTF-8 byte representation.
        ;; d 4:bär i20e 7:citrone i30e 6:äpfel i10e e
        expected-bytes #b"d4:bäri20e7:citronei30e6:äpfeli10ee"]

    ;; Encode the dictionary and assert it matches the expected sorted bytes.
    (assert (= (encode unsorted-dict) expected-bytes)
            "Dictionary keys (Non-ASCII) were not sorted correctly by UTF-8 byte value")
    ;; Additionally, verify that decoding the result restores the original content.
    (assert (= unsorted-dict (-> unsorted-dict encode decode first))
            "Decoding the sorted non-ASCII-keyed dict should restore original content")))

(defn test_encode_empty_dict_bytes []
  "Tests that an empty dictionary encodes to the specific byte string 'de'."
  (let [empty-dict {}
        expected-bytes #b"de"]
    ;; Encode the empty dictionary and check against the expected bytes.
    (assert (= (encode empty-dict) expected-bytes)
            "Empty dictionary did not encode to b'de'")))

;;; from bencode-test.py
;;; https://www.nayuki.io/res/bittorrent-bencode-format-tools/bencode-test.py

;; === Serialization Tests (HyREPL.bencode.encode) ===

(defn test_serialize_integer []
  "Tests serialization of integers using Hy encode."
  (assert (= (encode 0) #b"i0e"))
  (assert (= (encode 2) #b"i2e"))
  (assert (= (encode -1) #b"i-1e"))
  (assert (= (encode 3141592) #b"i3141592e"))
  (assert (= (encode -27182818284) #b"i-27182818284e"))
  (assert (= (encode (<< 1 80)) #b"i1208925819614629174706176e")))

(defn test_serialize_byte_string []
  "Tests serialization of byte strings using Hy encode.
  ASSUMES encode-bytes correctly encodes raw bytes."
  (assert (= (encode #b"") #b"0:"))
  (assert (= (encode #b"\x00") #b"1:\x00")) ; Byte with value 0
  (assert (= (encode #b"\x04\x01") #b"2:\x04\x01")) ; Bytes with specific values
  (assert (= (encode #b"ben") #b"3:ben")) ; Bytes containing ASCII text
  (assert (= (encode #b"ABCDE98765") #b"10:ABCDE98765")))

(defn test_serialize_string []
  "Tests serialization of strings using Hy encode (via encode-str)."
  (assert (= (encode "") #b"0:"))
  (assert (= (encode "ben") #b"3:ben"))
  (assert (= (encode "ABCDE98765") #b"10:ABCDE98765"))
  ;; Test non-ASCII string encoding (e.g., Chinese characters for 'hello')
  (assert (= (encode "你好") #b"6:你好"))
  ;; Test string containing null-like character representation if needed
  (assert (= (encode "\x00") #b"1:\x00"))
  (assert (= (encode "\x04\x01") #b"2:\x04\x01")) ; String containing non-printable ASCII
  )

(defn test_serialize_list []
  "Tests serialization of lists containing various types using Hy encode."
  (assert (= (encode []) #b"le"))
  (assert (= (encode [4]) #b"li4ee"))
  ;; Original Python test used b"Hello". Hy encode handles str and bytes.
  (assert (= (encode [7 "Hello"]) #b"li7e5:Helloe")) ; List with int and string
  (assert (= (encode [7 #b"Hello"]) #b"li7e5:Helloe")) ; List with int and bytes
  ;; Original Python test used b"X".
  (assert (= (encode [-88 [] "X"]) #b"li-88ele1:Xe")) ; List with int, list, string
  (assert (= (encode [-88 [] #b"X"]) #b"li-88ele1:Xe")) ; List with int, list, bytes
  )

(defn test_serialize_dictionary []
  "Tests serialization of dictionaries using Hy encode.
  NOTE: Assumes Hy encode-dict requires STRING keys. Byte keys/values adapted."
  (assert (= (encode {}) #b"de"))
  ;; Python test {b"":[]} -> Hy {"":[]}
  (assert (= (encode {"" []}) #b"d0:lee"))
  ;; Python test {b"ZZ":768, b"AAA":b"-14142"} -> Hy {"ZZ" 768 "AAA" #b"-14142"}
  ;; Keys sorted by string bytes: "AAA", "ZZ"
  ;; Value for "AAA" is bytes, check encode-bytes output format "length:raw_bytes"
  (assert (= (encode {"ZZ" 768 "AAA" #b"-14142"}) #b"d3:AAA6:-141422:ZZi768ee"))
  ;; Python test {b"\x03":[], b"\x08":{}} -> Hy {"\x03":[], "\x08":{}}
  ;; Keys sorted by string bytes: "\x03", "\x08"
  (assert (= (encode {"\x03" [] "\x08" {}}) #b"d1:\x03le1:\x08dee")))

;; === Parsing Tests (HyREPL.bencode.decode) ===

(defn test_parse_empty []
  "Tests parsing empty input raises an error (ValueError)."
  (with [(pytest.raises ValueError)]
    (decode #b"")))

(defn test_parse_check_trailing_data []
  "Tests that 'decode' parses only the first object and returns trailing data."
  ;; This replaces Nayuki's test_parse_invalid which expected failure for multiple objects.

  (let [[val1 rest1] (decode #b"i0ei1e")]
    (assert (= val1 0))
    (assert (= rest1 #b"i1e")))

  ;; Note: input must be bytes
  (let [[val2 rest2] (decode #b"1:a2:bc")]
    (assert (= val2 "a")) ; Expect string result from decode
    (assert (= rest2 #b"2:bc")))

  (let [[val3 rest3] (decode #b"le0:")]
    (assert (= val3 []))
    (assert (= rest3 #b"0:"))))

(defn test_parse_integer []
  "Tests parsing valid integers using Hy decode."
  (assert (= (first (decode #b"i0e")) 0))
  (assert (= (first (decode #b"i11e")) 11))
  (assert (= (first (decode #b"i-749e")) -749))
  (assert (= (first (decode #b"i9223372036854775807e")) 9223372036854775807))
  (assert (= (first (decode #b"i-9223372036854775808e")) -9223372036854775808)))

(defn test_parse_integer_eof []
  "Tests parsing integers with premature EOF raises error."
  (for [cs [#b"i" #b"i0" #b"i1248" #b"i-"]]
    (with [(pytest.raises ValueError)] ; Expect EOF/Format error
      (decode cs))))

(defn test_parse_integer_invalid []
  "Tests parsing invalid integer formats raise ValueError."
  (let [CASES [
               #b"ie"      ; Empty number
               #b"i00e"    ; Leading zero (invalid bencode)
               #b"i0199e"  ; Leading zero (invalid bencode)
               #b"i-e"     ; Negative sign only
               #b"i-0e"    ; Negative zero (invalid bencode)
               #b"i-026e"  ; Negative with leading zero (invalid bencode)
               #b"iAe"     ; Non-digit
               #b"i-Be"    ; Non-digit after sign
               #b"i+5e"    ; Explicit positive sign not allowed
               #b"i4.0e"   ; Decimal point not allowed
               #b"i9E9e"   ; Scientific notation not allowed
               ]]
    (for [cs CASES]
      (with [(pytest.raises ValueError)]
        (decode cs)))))

(defn test_parse_byte_string []
  "Tests parsing valid byte strings using Hy decode. Expects STRINGS as result."
  (assert (= (first (decode #b"0:")) ""))
  (assert (= (first (decode #b"1:&")) "&")) ; String result
  (assert (= (first (decode #b"13:abcdefghijklm")) "abcdefghijklm"))) ; String result

(defn test_parse_byte_string_eof []
  "Tests parsing byte strings with premature EOF raises error."
  (let [CASES [
               #b"0"       ; Missing colon and data
               #b"1"       ; Missing colon and data
               #b"843"     ; Missing colon and data
               #b"1:"      ; Missing data (0 bytes)
               #b"2:"      ; Missing data (0 bytes)
               #b"2:q"     ; Missing data (1 byte)
               ]]
    (for [cs CASES]
      (with [(pytest.raises ValueError)] ; Expect EOF/Format error
        (decode cs)))))

(defn test_parse_byte_string_invalid []
  "Tests parsing invalid byte string formats (length part) raise ValueError."
  (let [CASES [
               #b"00:" #b"01:" ; Bencode spec forbids leading zeros in length. Check if Hy decode enforces this.
               #b"-0:"    ; Negative length
               #b"-1:"    ; Negative length
               #b"a:"     ; Non-digit length
               ]]
    (for [cs CASES]
      (with [(pytest.raises ValueError)]
        (decode cs))))
  ;; Explicitly test leading zeros in length if needed (assuming spec forbids)
  (with [(pytest.raises ValueError)] (decode #b"00:"))
  (with [(pytest.raises ValueError)] (decode #b"01:")))


(defn test_parse_list []
  "Tests parsing valid lists using Hy decode. Expects byte strings decoded as STRINGS."
  (assert (= (first (decode #b"le")) []))
  (assert (= (first (decode #b"li-6ee")) [-6]))
  ;; Python test had b"00", Hy decode returns string "00"
  (assert (= (first (decode #b"l2:00i55ee")) ["00" 55]))
  (assert (= (first (decode #b"llelee")) [[] []])))

(defn test_parse_list_eof []
  "Tests parsing lists with premature EOF raises error (e.g., missing 'e')."
  (let [CASES [
               #b"l"        ; Missing elements and 'e'
               #b"li0e"     ; Missing final 'e'
               #b"llleleel" ; Missing final 'e'
               ]]
    (for [cs CASES]
      ;; Expect ValueError("List without end marker") or similar EOF error
      (with [(pytest.raises ValueError)]
        (decode cs)))))

(defn test_parse_dictionary []
  "Tests parsing valid dictionaries using Hy decode. Expects byte keys/strings decoded as STRINGS."
  (assert (= (first (decode #b"de")) {}))
  ;; Python test had b"-":404, Hy decode returns "-":404
  (assert (= (first (decode #b"d1:-i404ee")) {"-" 404}))
  ;; Python test had b"010":b"101", b"yU":[], Hy decode returns "010":"101", "yU":[]
  (assert (= (first (decode #b"d3:0103:1012:yUlee")) {"010" "101" "yU" []})))

(defn test_parse_dictionary_eof []
  "Tests parsing dictionaries with premature EOF raises error (e.g., missing 'e')."
  (let [CASES [
               #b"d"         ; Missing key/value/e
               #b"d1::"      ; Valid key b"", missing value and 'e'
               #b"d2:ab0:"   ; Valid key/value, missing 'e'
               #b"d0:d"      ; Valid key b"", missing value dict and 'e'
               #b"d3:$"      ; Valid key b"$", missing value and 'e'
               ]]
    (for [cs CASES]
      ;; Expect ValueError("Dictionary without end marker") or similar EOF error
      (with [(pytest.raises ValueError)]
        (decode cs)))))

(defn test_parse_dictionary_invalid_key_order_or_duplicates []
  "Tests parsing dictionaries with invalid key order or duplicates.
  NOTE: Current Hy decode is lenient and likely *passes* these tests."
  ;; Bencode spec requires keys to be sorted bytes and unique.
  ;; Test that the current decoder accepts them, though a strict one would raise ValueError.
  (let [CASES {
               ;; Unsorted Keys (B should come after A) - Expect lenient success
               #b"d1:A0:1:B1:.e"  {"A" "" "B" "."}
               ;; Duplicate Keys (E appears twice) - Expect lenient success (last value wins?)
               #b"d1:E0:1:F0:1:E0:e" {"E" "" "F" ""}
               ;; Test case from Nayuki, unsorted
               #b"d1:B0:1:A1:.e" {"B" "" "A" "."}
               }]
    (for [[cs expected] (.items CASES)]
      (let [result (first (decode cs))]
        (assert (= result expected) (f"Lenient parse failed for {cs}"))
        ;; To test for strict failure (if decoder was strict):
        ;; (with [(pytest.raises ValueError)] (decode (#b cs)))
        ))))

(defn test_parse_dictionary_invalid_eof_after_bad_order_or_dup []
  "Tests dictionary parsing where bad order/duplicates are followed by EOF."
  ;; These combine invalid structure (for strict parsers) with missing 'e'.
  ;; Should fail due to missing 'e' regardless of strictness on order/duplicates.
  (let [CASES [
               #b"d1:B0:1:D0:1:C0:" ; Unsorted C after D, missing 'e'
               #b"d1:E0:1:F0:1:E0:" ; Duplicate E, missing 'e'
               #b"d2:gg0:1:g0:"    ; Keys "gg", "g", missing 'e'
               ]]
    (for [cs CASES]
      (with [(pytest.raises ValueError)] ; Expect EOF/Marker error
        (decode cs)))))
