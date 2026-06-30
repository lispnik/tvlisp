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

;;; --- migration: reuse the classic tvlisp app's real logic on tv2 windows ----
;;; Stage 1: the editor's Lisp indentation.  tv2's editor calls *LISP-INDENTER*
;;; for a fresh line; we point it at tvlisp's actual indent engine
;;; (TVISION::%LISP-INDENT-AT), so the tv2 editor indents exactly like tvlisp.

(defun %line-offset (te line)
  "Char offset where LINE begins in TE's buffer."
  (loop for i below line sum (1+ (length (tv2::te-line te i)))))

(defun tvlisp-indent (te)
  "Indent a fresh line using the classic tvlisp Lisp indenter."
  (or (ignore-errors
       (funcall (find-symbol "%LISP-INDENT-AT" :tvision)
                (tv2:te-text te) (%line-offset te (tv2::te-cy te))))
      0))

;;; Stage 2: the REPL evaluator.  Replace tv2's hand-rolled eval loop with
;;; tvlisp's actual TVISION:REPL-BACKEND-EVAL — its read/eval/print, the per-
;;; listener CL history vars (-, +/++/+++, */**/***, ///), and sticky IN-PACKAGE
;;; — while keeping tv2's SLDB debugger as the error handler.

(defun tvlisp-repl-eval (win input)
  "Worker thread: evaluate INPUT for the tv2 REPL window WIN using tvlisp's
backend, then post output + results + new package back through tv2's UI bridge."
  (let* ((backend (find-symbol "REPL-BACKEND-EVAL" :tvision))
         (hist (tv2:repl-hist-vars win)))
    (multiple-value-bind (output results new-pkg errored new-hist)
        (restart-case
            (funcall backend input (tv2:repl-package win)
                     (lambda (e) (tv2::%repl-debug win e))    ; reuse tv2's cross-thread SLDB debugger
                     hist)
          (tv2::repl-abort () (values "" nil (tv2:repl-package win) t hist)))   ; debugger's abort lands here
      (setf (tv2:repl-hist-vars win) new-hist)
      (let ((result-strs (let ((*package* new-pkg))            ; print results in the listener's package
                           (unless errored
                             (loop for vals in results
                                   collect (if vals (mapcar #'prin1-to-string vals) :none))))))
        (tv2:run-on-ui
         (lambda ()
           (let ((sb (tv2:find-view win 'tv2::transcript)))
             (when sb
               (when (plusp (length output))
                 (tv2:scrollback-append sb output)
                 (unless (char= (char output (1- (length output))) #\Newline)
                   (tv2:scrollback-append sb (string #\Newline))))
               (dolist (vals result-strs)
                 (if (eq vals :none)
                     (tv2:scrollback-append sb (format nil "; No values~%"))
                     (dolist (v vals) (tv2:scrollback-append sb (format nil "=> ~a~%" v)))))))
           (setf (tv2:repl-package win) new-pkg (tv2:repl-busy win) nil)
           (tv2::%repl-update-prompt win)))))))

(defun install-tvlisp-logic ()
  "Inject tvlisp's real logic into the tv2 toolkit (extended each migration stage)."
  (setf tv2:*lisp-indenter* #'tvlisp-indent          ; stage 1: editor indentation
        tv2:*repl-eval-fn*   #'tvlisp-repl-eval))     ; stage 2: REPL evaluator

(defun main ()
  "Run the tv2-based tvlisp IDE until the user quits the launcher."
  (install-tvlisp-logic)
  (tv2:run-app))

(defun toplevel ()
  "Dumped-executable entry point: run the IDE, report a fatal error cleanly, exit."
  (handler-case (main)
    (error (e) (format *error-output* "~&tvlisp-tv2: fatal: ~a~%" e)))
  (uiop:quit 0))
