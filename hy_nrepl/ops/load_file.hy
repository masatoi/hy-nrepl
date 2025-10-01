(import hy-nrepl.ops.utils [find-op ops])
(import hyrule [assoc])
(import toolz [second])
(require hy-nrepl.ops.utils [defop])

(defn extract-code [file-content]
  (if (is file-content None)
      ""
      (do
        (setv stripped (.lstrip file-content))
        (if (.startswith stripped "(")
            stripped
            (do
              (setv result stripped)
              (for [separator ["\n" "  "]]
                (setv parts (.split stripped separator 1))
                (when (= (len parts) 2)
                  (setv result (.lstrip (get parts 1)))
                  (break)))
              result)))))

(defop "load-file" [session msg transport]
  {"doc" "Loads code from a file by delegating to the eval op"
   "requires" {"file" "The contents of the file to evaluate"}
   "optional" {"file-name" "The name of the file being evaluated"
               "file-path" "The path of the file being evaluated"}
   "returns" {"status" "done"}}
  (setv file-content (.get msg "file"))
  (setv code (extract-code file-content))
  (.pop msg "file" None)
  (assoc msg "code" code)
  ((find-op "eval") session msg transport))
