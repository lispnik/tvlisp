;;;; tv2-main.lisp --- tvlisp running on the experimental tv2 CLOS kernel.
;;;;
;;;; The classic tvlisp IDE is built on the original `tvision' framework.  Every
;;;; tvlisp window has also been rebuilt on `tv2', the CLOS-native re-architecture
;;;; of the framework (see ../tvision/tv2/README.md).  This is the entry point
;;;; for that build: it launches the tv2 IDE shell (a menu of the ported
;;;; windows).  It lives in its own system (`tvlisp/tv2') so the classic build
;;;; and binary are untouched.

(defpackage #:tvlisp-tv2
  (:use #:cl)
  (:documentation "tvlisp on the tv2 kernel.")
  (:export #:main #:toplevel))

(in-package #:tvlisp-tv2)

(defun main ()
  "Run the tv2-based tvlisp IDE until the user quits the launcher."
  (tv2:run-app))

(defun toplevel ()
  "Dumped-executable entry point: run the IDE, report a fatal error cleanly, exit."
  (handler-case (main)
    (error (e) (format *error-output* "~&tvlisp-tv2: fatal: ~a~%" e)))
  (uiop:quit 0))
