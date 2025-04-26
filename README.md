# HyREPL
[![HyREPL unit test](https://github.com/masatoi/HyREPL/actions/workflows/hyrepl_test.yaml/badge.svg)](https://github.com/masatoi/HyREPL/actions/workflows/hyrepl_test.yaml)

HyREPL is an implementation of the [nREPL](https://nrepl.org) protocol for [Hy](https://github.com/hylang/hy).

## Implemented Operations

from [nREPL Built-in Ops](https://nrepl.org/nrepl/1.3/ops.html)

- [ ] add-middleware
- [x] clone
- [x] close
- [x] completions
- [x] describe
- [x] eval
- [x] interrupt
- [x] load-file
- [x] lookup
- [ ] ls-middleware
- [x] ls-sessions
- [x] stdin
- [ ] swap-middleware

## Usage
HyREPL requires Python 3.10 and Hy over 0.2.9.

To install

```sh
pip install git+https://github.com/masatoi/HyREPL.git
```

To run server, (default port is 7888)
```sh
hyrepl

# Output debug log and specify port
hyrepl --debug 7888
```

To run the tests, simply execute `pytest tests` in project root directory.

## Confirmed working nREPL clients

### Emacs
The following combinations are currently confirmed to work stably.

- [hy-mode](https://github.com/hylang/hy-mode) + [Rail](https://github.com/masatoi/Rail)
  - REPL (Eval and Interruption)
  - Symbol completion
  - Eldoc (Function arg documentations)
  - Jump to source

This list is not exhaustive, and HyREPL does not support all features offered by these clients, such as advanced debugger integration, profiling or tracing. Jump to source is also not supported.

### Lighttable
* Support live eval by connecting with `Clojure nrepl`. Still basic and buggy 

### Vim
* `fireplace` with [vim-hy](https://github.com/hylang/vim-hy) to provide the
  necessary glue

### Emacs
* `cider`
* `monroe`

### Console
* `python-nrepl-client`

Using HyREPL with fireplace
===========================

For the best integration, install [vim-hy](https://github.com/hylang/vim-hy). It
offers syntax highlighting and indentation support as well as wrappers around
fireplace to make it more Hy-friendly.

Run `hy -m HyREPL.server` in your target directory and open a Hy file in vim.
You can also use `:setf hy` to set the file type explicitly.  Connect vim to the
REPL with `:Connect`.  Use `nrepl` as the protocol, `localhost` as the host and
the port number HyREPL printed on start.

Without `vim-hy`
----------------
Open a Hy file and set the file type to `clojure`: `set filetype=clojure`. This
will suck because it doesn't support `:Doc`. Other things might be broken as
well.

Missing features
----------------
* `:Require[!]` does not yet work. Use `:%Eval` to evaluate complete files.
* fireplace uses a lot of clojure-specific pieces of code. Most of these could
  be transformed with workarounds.

Using HyREPL inside your own programs
=====================================
You can use HyREPL to add a remote control to your own programs. The following
steps are a small example:

    (import time
      [HyREPL.server :as repl]
      [HyREPL.middleware.eval :as repl-mw])
    (setv (. repl-mw eval-module) (globals))
    (defmain [&rest args]
      (let [[s (repl.start-server)]]
        (print (.format "Listening on {}" (. (second s) server-address)))
        (while True
          (time.sleep 1))))

Made with ♥
===========

If you encounter bugs or missing features, please create an [issue
report](https://github.com/Foxboron/HyREPL/issues). Patches are always welcome.
If you have questions, we hang out in `#hy` on Freenode.
