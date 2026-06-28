# Makefile --- build the tvlisp REPL / mini-IDE.
#
# tvlisp is dumped by ASDF's `program-op' (configured via :build-operation /
# :build-pathname / :entry-point in tvlisp.asd):
#
#   tvlisp  <- system tvlisp   (entry tvision-tvlisp:toplevel)
#
# It depends on the `tvision' framework, a sibling project at ../tvision.
#
# Usage:
#   make            # build ./tvlisp
#   make test       # tvlisp pty smoke tests against the built binary
#   make clean      # remove the binary and this project's fasl cache

SBCL ?= sbcl
PYTHON ?= python3

# Build SYSTEM with asdf:make.  We add this project AND the sibling framework
# (../tvision, reachable via the parent tree) to the source registry so the
# build works without any global ocicl/ASDF config.
define asdf-make
$(SBCL) --non-interactive \
	--eval '(asdf:initialize-source-registry (list :source-registry (list :tree (uiop:getcwd)) (list :tree (merge-pathnames "../" (uiop:getcwd))) :inherit-configuration))' \
	--eval '(asdf:make :$(1))' \
	--eval '(uiop:quit 0)'
endef

# Rebuild whenever the app source or the framework changes.
FRAMEWORK := $(wildcard ../tvision/src/*.lisp) ../tvision/tvision.asd

.DEFAULT_GOAL := all
.PHONY: all clean run test test-lisp test-pty help

all: tvlisp

tvlisp: tvlisp.asd src/tvlisp.lisp $(FRAMEWORK)
	$(call asdf-make,tvlisp)

run: tvlisp
	./tvlisp

# Full test: the headless REPL/debugger/inspector suite plus the pty smoke test.
test: test-lisp test-pty

# Headless unit suite (REPL backend, debugger, inspector, thread monitor).
# FiveAM is a test-only dependency, restored by `ocicl install`.
test-lisp: tvlisp.asd $(wildcard src/*.lisp) tests/tvlisp-tests.lisp
	$(SBCL) --non-interactive \
		--eval '(asdf:initialize-source-registry (list :source-registry (list :tree (uiop:getcwd)) (list :tree (merge-pathnames "../" (uiop:getcwd))) :inherit-configuration))' \
		--eval '(handler-bind ((warning (function muffle-warning))) (asdf:load-system :tvlisp/tests))' \
		--eval '(sb-ext:exit :code (if (zerop (tvision-tvlisp-tests:run-tests)) 0 1))'

# Drive the built ./tvlisp through a pty and assert on the screen (end-to-end).
test-pty: tvlisp tests/pty_smoke.py
	$(PYTHON) tests/pty_smoke.py ./tvlisp

clean:
	rm -f tvlisp
	rm -rf $(HOME)/.cache/common-lisp/*tvlisp* 2>/dev/null || true

help:
	@echo "Targets: all (default), tvlisp, run, test, clean"
