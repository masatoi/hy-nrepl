"""Worker process for the subprocess-based evaluation backend."""
from __future__ import annotations

import argparse
import atexit
import contextlib
import json
import os
import queue
import resource
import shutil
import signal
import sys
import tempfile
import threading
import time
import traceback
from collections import OrderedDict
from dataclasses import dataclass
from io import StringIO
from types import ModuleType
from typing import Any, Dict, Optional

from hy import eval as hy_eval
from hy.core.hy_repr import hy_repr
from hy import models as hy_models
from hy.reader import HyReader

# Import completion and lookup functions
try:
    import hy.pyops as _  # Ensure hy.pyops is loaded
    from hy_nrepl.ops.completions import get_completions as _get_completions
    from hy_nrepl.ops.lookup import get_info as _get_info
except ImportError as e:
    # Fallback if imports fail
    _get_completions = None
    _get_info = None

DEFAULT_CPU_LIMIT = 15
DEFAULT_MEM_LIMIT = 512 * 1024 * 1024
DEFAULT_MAX_HANDLES = 128


class SoftInterrupt(Exception):
    """Raised when the evaluation is cancelled cooperatively."""


@dataclass
class WorkerArgs:
    session: str
    cpu_limit: int = DEFAULT_CPU_LIMIT
    mem_limit: int = DEFAULT_MEM_LIMIT
    max_handles: int = DEFAULT_MAX_HANDLES


class Worker:
    """Hy evaluation worker running inside a sandboxed subprocess."""

    def __init__(self, args: WorkerArgs) -> None:
        self.args = args
        self.module = ModuleType(f"hy_worker_{args.session}")
        self.module.__dict__.setdefault("__builtins__", __builtins__)
        self.locals = self.module.__dict__
        self.reader = HyReader()
        self.handles: "OrderedDict[str, Any]" = OrderedDict()
        self.next_handle = 1
        self.cancel_event = threading.Event()
        self.eval_thread: Optional[threading.Thread] = None
        self.eval_running = threading.Event()
        self.shutdown_event = threading.Event()
        self.command_queue: "queue.Queue[Dict[str, Any]]" = queue.Queue()
        self.write_lock = threading.Lock()
        self.temp_dir = tempfile.mkdtemp(prefix="hy-nrepl-")
        os.chdir(self.temp_dir)
        atexit.register(lambda: shutil.rmtree(self.temp_dir, ignore_errors=True))
        self._apply_limits()
        os.environ.setdefault("MPLBACKEND", "Agg")
        signal.signal(signal.SIGTERM, self._handle_sigterm)

    # lifecycle ------------------------------------------------------
    def _apply_limits(self) -> None:
        try:
            if self.args.cpu_limit > 0:
                resource.setrlimit(resource.RLIMIT_CPU, (self.args.cpu_limit, self.args.cpu_limit))
            if self.args.mem_limit > 0:
                resource.setrlimit(resource.RLIMIT_AS, (self.args.mem_limit, self.args.mem_limit))
        except (ValueError, OSError):  # pragma: no cover - platform differences
            pass

    def _handle_sigterm(self, signum: int, frame: Any) -> None:  # pragma: no cover - signal path
        self.cancel_event.set()
        self.shutdown_event.set()
        raise SystemExit(0)

    def start(self) -> None:
        reader_thread = threading.Thread(target=self._stdin_reader, daemon=True)
        reader_thread.start()
        while not self.shutdown_event.is_set():
            self._pump_commands()
            self._cleanup_eval()
        if self.eval_thread and self.eval_thread.is_alive():
            self.cancel_event.set()
            self.eval_thread.join(timeout=0.5)

    def _stdin_reader(self) -> None:
        for raw in sys.stdin:
            raw = raw.strip()
            if not raw:
                continue
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            self.command_queue.put(payload)
        self.command_queue.put({"op": "__shutdown__"})

    def _pump_commands(self) -> None:
        try:
            cmd = self.command_queue.get(timeout=0.1)
        except queue.Empty:
            return
        op = cmd.get("op")
        if op == "eval":
            self._start_eval(cmd)
        elif op == "interrupt":
            self.cancel_event.set()
        elif op == "deref":
            self._handle_deref(cmd)
        elif op == "del":
            self._handle_del(cmd)
        elif op == "completions":
            self._handle_completions(cmd)
        elif op == "lookup":
            self._handle_lookup(cmd)
        elif op == "__shutdown__":
            self.shutdown_event.set()
        else:
            self._emit({
                "ok": False,
                "type": "UnknownOp",
                "message": f"Unknown op: {op}",
                "elapsed_ms": 0,
            })

    def _cleanup_eval(self) -> None:
        if self.eval_thread and not self.eval_thread.is_alive():
            self.eval_thread = None
            self.eval_running.clear()
            self.cancel_event.clear()

    # evaluation -----------------------------------------------------
    def _start_eval(self, cmd: Dict[str, Any]) -> None:
        if self.eval_thread and self.eval_thread.is_alive():
            self._emit({
                "ok": False,
                "type": "Busy",
                "message": "Evaluation already in progress",
                "elapsed_ms": 0,
            })
            return
        self.cancel_event.clear()
        self.eval_running.set()
        self.eval_thread = threading.Thread(
            target=self._run_eval,
            args=(cmd,),
            daemon=True,
            name=f"hy-worker-eval-{self.args.session}",
        )
        self.eval_thread.start()

    def _tokenize(self, code: str):
        gen = self.reader.parse(StringIO(code))
        exprs = list(gen)
        if len(exprs) == 1:
            return exprs[0]
        exprs.insert(0, hy_models.Symbol("do"))
        return hy_models.Expression(exprs)

    def _store_handle(self, value: Any) -> str:
        handle = str(self.next_handle)
        self.next_handle += 1
        self.handles[handle] = value
        self.handles.move_to_end(handle)
        while len(self.handles) > self.args.max_handles:
            self.handles.popitem(last=False)
        return handle

    def _run_eval(self, cmd: Dict[str, Any]) -> None:
        code = cmd.get("code", "")
        options = cmd.get("options", {}) or {}
        start = time.perf_counter()
        stdout_buf = StringIO()
        stderr_buf = StringIO()

        def tracer(frame, event, arg):  # pragma: no cover - executed during tracing
            if self.cancel_event.is_set():
                raise SoftInterrupt()
            return tracer

        try:
            # Parse first, before setting trace (parsing shouldn't be interruptible)
            expr = self._tokenize(code)

            # Now set trace for evaluation only
            old_trace = sys.gettrace()
            old_thread_trace = threading.gettrace()
            sys.settrace(tracer)
            threading.settrace(tracer)

            with contextlib.redirect_stdout(stdout_buf), contextlib.redirect_stderr(stderr_buf):
                result = hy_eval(expr, locals=self.locals, module=self.module)
            payload: Dict[str, Any] = {
                "ok": True,
                "repr": str(hy_repr(result)),
            }
            if options.get("return") == "handle":
                payload["handle"] = self._store_handle(result)
            self._attach_streams(payload, stdout_buf, stderr_buf)
            payload["elapsed_ms"] = int((time.perf_counter() - start) * 1000)
            self._emit(payload)
        except SoftInterrupt:
            payload = {
                "ok": False,
                "type": "Interrupted",
                "message": "Evaluation interrupted",
            }
            self._attach_streams(payload, stdout_buf, stderr_buf)
            payload["elapsed_ms"] = int((time.perf_counter() - start) * 1000)
            self._emit(payload)
        except BaseException as exc:  # pragma: no cover - covered by tests
            payload = {
                "ok": False,
                "type": exc.__class__.__name__,
                "message": str(exc),
                "traceback": traceback.format_exc(),
            }
            self._attach_streams(payload, stdout_buf, stderr_buf)
            payload["elapsed_ms"] = int((time.perf_counter() - start) * 1000)
            self._emit(payload)
        finally:
            # Restore trace functions (only if they were set)
            try:
                sys.settrace(old_trace)
                threading.settrace(old_thread_trace)
            except NameError:
                # If parsing failed, old_trace/old_thread_trace may not be defined
                pass
            self.eval_running.clear()
            self.cancel_event.clear()

    def _attach_streams(self, payload: Dict[str, Any], stdout_buf: StringIO, stderr_buf: StringIO) -> None:
        out = stdout_buf.getvalue()
        err = stderr_buf.getvalue()
        if out:
            payload["stdout"] = out
        if err:
            payload["stderr"] = err

    # handle operations ----------------------------------------------
    def _handle_deref(self, cmd: Dict[str, Any]) -> None:
        handle = str(cmd.get("handle"))
        if handle not in self.handles:
            self._emit({
                "ok": False,
                "type": "LookupError",
                "message": f"Unknown handle: {handle}",
                "elapsed_ms": 0,
            })
            return
        value = self.handles[handle]
        self.handles.move_to_end(handle)
        self._emit({
            "ok": True,
            "repr": str(hy_repr(value)),
            "handle": handle,
            "elapsed_ms": 0,
        })

    def _handle_del(self, cmd: Dict[str, Any]) -> None:
        handle = str(cmd.get("handle"))
        existed = self.handles.pop(handle, None)
        if existed is None:
            self._emit({
                "ok": False,
                "type": "LookupError",
                "message": f"Unknown handle: {handle}",
                "elapsed_ms": 0,
            })
        else:
            self._emit({
                "ok": True,
                "repr": f"deleted {handle}",
                "handle": handle,
                "elapsed_ms": 0,
            })

    def _handle_completions(self, cmd: Dict[str, Any]) -> None:
        """Handle completions request from parent process."""
        prefix = cmd.get("prefix", "")
        start = time.perf_counter()
        
        if _get_completions is None:
            self._emit({
                "ok": False,
                "type": "NotAvailable",
                "message": "Completions not available",
                "elapsed_ms": 0,
            })
            return
        
        try:
            # Create a mock session-like object with our module
            class MockSession:
                def __init__(self, module):
                    self.module = module
            
            mock_session = MockSession(self.module)
            completions = _get_completions(mock_session, prefix)
            
            self._emit({
                "ok": True,
                "completions": completions,
                "elapsed_ms": int((time.perf_counter() - start) * 1000),
            })
        except Exception as exc:
            self._emit({
                "ok": False,
                "type": exc.__class__.__name__,
                "message": str(exc),
                "traceback": traceback.format_exc(),
                "elapsed_ms": int((time.perf_counter() - start) * 1000),
            })

    def _handle_lookup(self, cmd: Dict[str, Any]) -> None:
        """Handle lookup request from parent process."""
        symbol = cmd.get("symbol", "")
        start = time.perf_counter()
        
        if _get_info is None:
            self._emit({
                "ok": False,
                "type": "NotAvailable",
                "message": "Lookup not available",
                "elapsed_ms": 0,
            })
            return
        
        try:
            # Create a mock session-like object with our module
            class MockSession:
                def __init__(self, module):
                    self.module = module
            
            mock_session = MockSession(self.module)
            info = _get_info(mock_session, symbol)
            
            self._emit({
                "ok": True,
                "info": info,
                "elapsed_ms": int((time.perf_counter() - start) * 1000),
            })
        except Exception as exc:
            self._emit({
                "ok": False,
                "type": exc.__class__.__name__,
                "message": str(exc),
                "traceback": traceback.format_exc(),
                "elapsed_ms": int((time.perf_counter() - start) * 1000),
            })

    # output ---------------------------------------------------------
    def _emit(self, payload: Dict[str, Any]) -> None:
        with self.write_lock:
            sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
            sys.stdout.flush()


def parse_args(argv: Optional[list[str]] = None) -> WorkerArgs:
    parser = argparse.ArgumentParser(prog="hy-nrepl-worker")
    parser.add_argument("--session", required=True)
    parser.add_argument("--cpu-limit", type=int, default=DEFAULT_CPU_LIMIT)
    parser.add_argument("--mem-limit", type=int, default=DEFAULT_MEM_LIMIT)
    parser.add_argument("--max-handles", type=int, default=DEFAULT_MAX_HANDLES)
    ns = parser.parse_args(argv)
    return WorkerArgs(session=ns.session, cpu_limit=ns.cpu_limit, mem_limit=ns.mem_limit, max_handles=ns.max_handles)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    worker = Worker(args)
    worker.start()
    return 0


if __name__ == "__main__":  # pragma: no cover - manual execution
    raise SystemExit(main())
