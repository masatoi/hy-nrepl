# Repository Guidelines

## Project Structure & Module Organization
- `hy_nrepl/`: Source code.
  - `server.hy`: TCP nREPL server entry (`hy -m hy-nrepl.server`).
  - `session.hy`: Session model/registry and transport I/O.
  - `ops/`: nREPL operations (e.g., `eval.hy`, `completions.hy`, `lookup.hy`).
  - `bencode.hy`: Message encoding/decoding.
- `tests/`: Test suite (Hy and Python). Hy files (e.g., `tests/ops/eval.hy`) are collected by pytest via `conftest.py`.
- `bin/hy-nrepl`: CLI shim that runs the server module.
- `setup.py`, `requirements.txt`, `.github/workflows/`: Packaging, deps, and CI.

## Build, Test, and Development Commands
- Install (PyPI): `pip install hy-nrepl`
- Dev deps: `pip install -r requirements.txt` (includes `pytest`)
- Editable install: `pip install -e .`
- Alt test deps: `pip install -e .[test]`
- Run tests: `pytest tests`
- Run server: `hy-nrepl` or `hy -m hy-nrepl.server --debug 7888`
- Local client check: connect to `localhost:<port>` (default 7888) with your nREPL client.

## Coding Style & Naming Conventions
- Language: Python 3.11+, Hy >= 0.29.0.
- Indentation: 4 spaces; keep lines readable (~100 cols).
- Hy: prefer kebab-case for public symbols (`defn get-info`), prefix private with `_`.
- Python: use snake_case; keep names consistent with Hy interfaces when crossing the boundary.
- Keep modules small and focused (server/session/ops separation). Add new ops under `hy_nrepl/ops/` and register via `defop` in that file.

## Testing Guidelines
- Framework: pytest. Hy tests are `.hy` files under `tests/` and are auto-collected.
- Name tests `test_*` (pytest collects Hy functions defined with `defn test-...`).
- Coverage: add tests for new ops and edge cases (e.g., multi-message flows, errors).
- Run `pytest tests` locally; CI runs a Hy version matrix.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subject (e.g., "Add eval interrupt handling"). Group related changes.
- PRs: include description, rationale, linked issues, reproduction steps, and test updates. Add screenshots/logs for protocol traces if relevant.
- Requirements: all tests pass; no regressions in existing ops; update README for user-visible flags or behavior.

## Security & Configuration Tips
- Server binds `127.0.0.1` by default; expose ports intentionally.
- Use `--debug` only in development; logs may include code snippets.
