# hy-nrepl Evaluation Backend Specification

## Backends

- **process** (default): persistent worker subprocess per session
  - JSON-over-stdio protocol (`{op, code, session, options}`)
  - Soft interrupts via trace cancellation, hard interrupts via SIGTERM/SIGKILL
  - Auto restart on crash, reports `Interrupted` vs `Aborted`
  - Optional handle mode (`options.return = "handle"`, `op` = `deref`/`del`)
  - Resource isolation: RLIMIT_CPU, RLIMIT_AS, per-session temp directory, matplotlib `Agg`
- **thread**: legacy in-process evaluator preserved for compatibility

Switch backend at runtime with `hy-nrepl --eval-backend=process|thread`. The active backend is exposed via the `describe` op under the `backend` key.

## Worker process

- Maintains session module/locals, exposes queue-based `stdin`
- Captures stdout/stderr for inclusion in responses
- Responses follow `{ok, repr|handle|error, elapsed_ms, stdout?, stderr?}`
- Supports cooperative cancellation (`Interrupted`) and forced termination (`Aborted`)
- Limits the number of retained handles (LRU eviction)

## Parent process integration

- `ProcessEvalBackend` owns worker lifecycle and maps worker responses to nREPL messages
- `interrupt` op triggers soft cancel and escalates to hard abort if unresponsive
- Automatic worker restart after crash ensures subsequent evaluations start fresh
- Thread backend (`ThreadEvalBackend`) remains available for legacy workflows

## Testing

Pytest suite covers:

- Successful evaluation via process backend
- Cooperative interrupt of long-running code
- Matplotlib usage under the Agg backend
- Forced worker kill with automatic restart
