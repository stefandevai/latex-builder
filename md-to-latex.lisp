;;;; md-to-latex.lisp

(in-package #:md-to-latex)

;; =============================================================================
;; MARKDOWN
;; =============================================================================
(defun parse-header (header-str)
  "Parse content within markdown's header"
  (setf (author     *article*) (parse-header-param "author" header-str))
  (setf (date       *article*) (parse-header-param "date" header-str))
  (setf (location   *article*) (parse-header-param "location" header-str)))

(defun parse-header-param (param header-str)
  "Parse a single parameter in markdown's header with a format: param: \"content\""
  (let* ((param-start (1+ (search "\"" header-str :start2 (search (str:concat param ":") header-str))))
         (param-end   (search "\"" header-str :start2 param-start)))
    (str:substring param-start param-end header-str)))

(defun parse-body (body-str)
  "Parse content in markdown's body"
  (setf (body *article*) (remove nil (mapcar 'parse-body-line (str:lines body-str)))))

(defun parse-body-line (str)
  "Parse a single line in markdown's body"
  (if (not (str:empty? (str:trim str)))
    (list :line-type (body-line-type str) :content str) (body *article*)))

(defun body-line-type (str)
  "Defines a type for a markdown line. If it starts by #, it is a heading; if it starts by ## it is a section; otherwise it is a paragraph."
  (if (>= (length str) 2)
    (let ((begin-str (str:substring 0 2 str)))
      (cond ((equal begin-str "##")   ':section)        ; if (starts by "##")
            ((equal begin-str "# ")   ':heading)        ; else if (starts by "# ")
            (t                        ':paragraph)))))  ; else

(defun parse-markdown (md-str)
  "Receives a markdown string and return a list with parsed contents"
  (let* ((header-start (1+ (search '(#\Newline) md-str)))
         (header-end   (search "---" md-str :start2 header-start)))
    (parse-header (str:substring header-start header-end md-str))
    (parse-body   (str:substring (+ header-end 4) nil md-str))))

;; =============================================================================
;; LATEX
;; =============================================================================
(defvar *linebreak* "\\linebreak~%"
  "Default linebreak sintax in Latex")

(defmacro surround-string (str1 str2 &body body)
  "Surround strings from `body' with `str1' and `str2'."
  `(str:concat ,str1 ,@body ,str2))

(defmacro latex-element (element-string newline &body body)
  "Facilitate the creation of a Latex element string."
  `(surround-string (str:concat "\\" ,element-string "{")
       (if ,newline "}~%" "}")
                    ,@body))

(defmacro bold (&body body)
  "Surround strings with `\textbf{}' directive in Latex."
  `(latex-element "textbf" nil ,@body))

(defmacro emph (&body body)
  "Emphasizes strings with `\emph{}' directive in Latex."
  `(latex-element "emph" nil ,@body))

(defmacro noindent (&body body)
  "Surround strings with `\noindent{}' directive in Latex."
  `(latex-element "noindent" nil ,@body))

(defmacro uppercase (&body body)
  "Surround strings with `\uppercase{}' directive in Latex."
  `(latex-element "uppercase" nil ,@body))

(defmacro section (&body body)
  "Surround strings with `\section{}' directive in Latex."
  `(latex-element "section*" t ,@body))

(defmacro begin-end (arg &body body)
  "Surround strings with `\begin{ arg }' and `\end{ arg }'."
  `(surround-string (latex-element "begin" t ,arg)
       (latex-element "end" t ,arg)
       ,@body))

;; =============================================================================
;; MAIN
;; =============================================================================
;; Holds article's parsed content
(defclass article ()
  ((author    :initform nil :accessor author)
   (location  :initform nil :accessor location)
   (date      :initform nil :accessor date)
   (body      :initform nil :accessor body)))

;; Article's main instance
(defparameter *article* (make-instance 'article))

(defun create-latex-article ()
  "Creates a Latex string from *article* instance"
  (let ((begin-str    "\\documentclass[12pt]{article}~%\\usepackage{crimson}~%\\usepackage[T1]{fontenc}~%\\usepackage[french]{babel}~%\\usepackage{geometry}~%\\geometry{a4paper, margin=1in}~%~%\\renewcommand{\\tiny}{\\normalsize}~%\\renewcommand{\\footnotesize}{\\normalsize}~%\\renewcommand{\\small}{\\normalsize}~%\\renewcommand{\\large}{\\normalsize}~%\\renewcommand{\\Large}{\\normalsize}~%\\renewcommand{\\LARGE}{\\normalsize}~%\\renewcommand{\\huge}{\\normalsize}~%\\renewcommand{\\Huge}{\\normalsize}~%~%\\begin{document}~%~%")
        (end-str      "\\end{document}~%"))
    (str:concat begin-str (str:concat (make-latex-header) (create-latex-body)) end-str)))

(defun make-latex-header ()
  (begin-end "flushright"
    (if (author *article*) (make-latex-header-item (author *article*)))
    (if (location *article*) (make-latex-header-item (location *article*)))
    (if (date *article*) (make-latex-header-item (date *article*)))))

(defun make-latex-header-item (item)
  (str:concat (bold item) "~%"  *linebreak*))

(defun create-latex-body ()
  (reduce #'str:concat (mapcar 'create-latex-body-line (body *article*))))

(defun create-latex-body-line (line)
  (ecase (getf line :line-type) (:paragraph (create-latex-paragraph (getf line :content)))
                                (:section   (create-latex-section (getf line :content)))
                                (:heading   (create-latex-heading (getf line :content)))))

(defun create-latex-paragraph (string)
  (str:concat
    (create-latex-emphasis (create-latex-bold string))
    "~%~%"))

(defun create-latex-section (string)
  (section (str:trim (str:substring 2 nil string))))

(defun create-latex-heading (string)
  (str:concat (noindent (bold (uppercase (str:trim (str:substring 1 nil string)))))
              "~%~%"))

(defun create-latex-bold (text)
  (ppcre:regex-replace-all "\\*\\*([^\\*]\\S(.*?\\S)?)\\*\\*" text "\\textbf{\\1}"))

(defun create-latex-emphasis (text)
  (ppcre:regex-replace-all "\\*([^\\*]\\S(.*?\\S)?)\\*" text "\\emph{\\1}"))

(defun write-to-file (str file-path)
  "Receives a string and a filepath and writes the string to the file"
  (with-open-file (out
                   file-path
                   :direction :output
                   :if-exists :supersede
                   :external-format :utf-8)
    (format out str)))

(defun create (input-path output-path)
  "Receives a Markdown (.md) file as input and outputs a Latex (.tex) file."
  (parse-markdown (uiop:read-file-string input-path))
  (write-to-file (create-latex-article) output-path))

(defun unknown-option (condition)
  (format t "warning: ~s option is unknown!~%" (opts:option condition))
  (invoke-restart 'opts:skip-option))

(defmacro when-option ((options opt) &body body)
  `(let ((it (getf ,options ,opt)))
     (when it
       ,@body)))

(defun main ()
  (opts:define-opts
    (:name :help
           :description "show this help text"
           :short #\h
           :long "help")
    (:name :out
           :description "the output latex file name"
           :short #\o
           :long "output"
           :arg-parser #'identity
           :meta-var "FILE"))

  (multiple-value-bind (options free-args)
      (handler-case
          (handler-bind ((opts:unknown-option #'unknown-option))
            (opts:get-opts))
        (opts:missing-arg (condition)
          (format t "fatal: option ~s needs an argument!~%"
                  (opts:option condition)))
        (opts:arg-parser-failed (condition)
          (format t "fatal: cannot parse ~s as argument of ~s~%"
                  (opts:raw-arg condition)
                  (opts:option condition)))
        (opts:missing-required-option (con)
          (format t "fatal: ~a~%" con)
          (opts:exit 1)))

    (when-option (options :help)
      (opts:describe
       :prefix "example of how it works"
       :suffix "so thats it"
       :usage-of "usage.sh"
       :args "[FREE-ARGS]"))

    (if (first free-args)
	(and
	 (let ((output-file nil))
         (when-option (options :out) (setf output-file (getf options :out)))
         (if (not output-file) (setf output-file "./article.tex"))
         (create (first free-args) output-file))))))
