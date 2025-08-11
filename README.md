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

To install:

```sh
pip install hy-nrepl
````

To run the server (default port is 7888):

```sh
hy-nrepl

# Output debug log and specify port
hy-nrepl --debug 7888
```

## Testing

Install test dependencies, then run pytest:

```sh
pip install -e .[test]

pytest tests
```

## Known Issues

Code evaluation is performed in a thread that is not Python's main thread. Therefore, some libraries that expect to be run on the main thread will not work as expected.

  - **GUI Libraries**: Libraries like **Tkinter** will not function correctly.
  - **Plotting Libraries**: **Matplotlib** is known to have issues. As an alternative, you can use libraries like **Plotly**, which work without relying on the main thread.

## Confirmed working nREPL clients

### Emacs

The following combinations are currently confirmed to work stably.

  - [hy-mode](https://github.com/hylang/hy-mode) + [Rail](https://github.com/masatoi/Rail)
      - REPL (Eval and Interruption)
      - Symbol completion
      - Eldoc (Function arg documentations)
      - Jump to source

### Emacs Configuration Example

Here is an example configuration for a plain Emacs setup using `use-package`.

**1. Install Rail**

This setup uses a forked version of `Rail` that has been modified to work well with `hy-nrepl`.

Clone the forked `Rail` repository from GitHub. This example clones it to the home directory (`~/Rail`).

```sh
git clone [https://github.com/masatoi/Rail.git](https://github.com/masatoi/Rail.git) ~/Rail
```

**2. Configure Emacs**

Add the following settings to your Emacs initialization file (e.g., `~/.emacs.d/init.el`). This setup assumes you are using `package.el` and `use-package`.

```emacs-lisp
;;; Assumes use-package is already installed.
;;; If not, add bootstrap code for package.el and use-package.
(require 'package)
(add-to-list 'package-archives '("melpa" . "[https://melpa.org/packages/](https://melpa.org/packages/)") t)
(package-initialize)

;;; hy-mode (will be installed from MELPA)
;;; jedhy is disabled as Rail provides completion.
(use-package hy-mode
  :mode "\\.hy\\'"
  :custom (hy-jedhy--enable? nil))

;;; Rail (loaded from the local path)
(use-package rail
  :ensure nil
  :load-path "~/Rail" ; Must match the path where you cloned Rail
  :commands (rail rail-interaction-mode)
  :hook ((hy-mode . rail-interaction-mode)
         (hy-mode . rail-setup-eldoc)
         (rail-mode . rail-setup-eldoc)))
```

**3. How to Connect**

1.  **Start the nREPL server in your terminal.** It will listen on `localhost:7888` by default.

    ```sh
    hy-nrepl
    ```

2.  **Connect to the nREPL server from Emacs.** Run `M-x rail`, and you will be prompted for the host and port. Enter the default value, `localhost:7888`, and press Enter. This will complete the connection and open a REPL buffer.

3.  **Developing with `.hy` files.** Once connected, opening a `.hy` file will automatically enable the minor mode `rail-interaction-mode`. This provides features like:

      - Evaluating Hy S-expressions within the buffer
      - Symbol completion
      - Displaying function argument information via Eldoc

4.  **Interrupting Execution.** While an evaluation is running in the REPL buffer, you can interrupt it by pressing `C-c C-c`.

<!-- end list -->
