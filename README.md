# hy-nrepl
[![hy-nrepl unit test](https://github.com/masatoi/hy-nrepl/actions/workflows/hy_nrepl_test.yaml/badge.svg)](https://github.com/masatoi/hy-nrepl/actions/workflows/hy_nrepl_test.yaml)

hy-nrepl is an implementation of the [nREPL](https://nrepl.org) protocol for [Hy](https://github.com/hylang/hy).
hy-nrepl is a fork from [HyREPL](https://github.com/allison-casey/HyREPL) and has been adjusted to work with the current Hy.

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
hy-nrepl requires Python >= 3.11 and Hy >= 0.29.0.

To install

```sh
pip install hy-nrepl
```

To run server, (default port is 7888)
```sh
hy-nrepl

# Output debug log and specify port
hy-nrepl --debug 7888
```

Testing
-------

Install test dependencies, then run pytest:

```sh
pip install -e .[test]

pytest tests
```

## Confirmed working nREPL clients

### Emacs
The following combinations are currently confirmed to work stably.

- [hy-mode](https://github.com/hylang/hy-mode) + [Rail](https://github.com/masatoi/Rail)
  - REPL (Eval and Interruption)
  - Symbol completion
  - Eldoc (Function arg documentations)
  - Jump to source
