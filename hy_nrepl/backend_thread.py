"""Thread-based evaluation backend (legacy behaviour)."""
from __future__ import annotations

import ctypes
import io
import logging
import queue
import sys
import threading
from io import StringIO
from typing import Any, Callable, Dict, Optional

from hy import eval as hy_eval
from hy.core.hy_repr import hy_repr
from hy.errors import hy_exc_filter
from hy.reader import HyReader
from hy.reader.exceptions import LexException
from hy import models as hy_models


class HyNReplSTDIN(queue.Queue):
    """Queue-backed ``sys.stdin`` surrogate used by the thread backend."""

    def __init__(self, writer: Callable[[Dict[str, Any]], None]) -> None:
        super().__init__()
        self.writer = writer

    def readline(self) -> str:  # pragma: no cover - exercised via integration
        self.writer({"status": ["need-input"]})
        self.join()
        return self.get()


def async_raise(tid: int, exc: BaseException) -> None:
    """Raise ``exc`` asynchronously in the target thread."""
    logging.debug("Thread backend async_raise: tid=%%s exc=%%s", tid, exc)
    res = ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_long(tid), ctypes.py_object(exc))
    if res == 0:
        raise ValueError(f"Thread ID does not exist: {tid}")
    if res > 1:  # pragma: no cover - safety guard
        ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_long(tid), 0)
        raise SystemError("PyThreadState_SetAsyncExc failed")


class StreamingOut(io.TextIOBase):
    """A file-like object that streams writes to an nREPL client."""

    def __init__(self, writer: Callable[[Dict[str, Any]], None]) -> None:
        self.writer = writer

    def write(self, text: str) -> int:
        if text:
            self.writer({"out": text})
        return len(text)

    def flush(self) -> None:  # pragma: no cover - nothing to flush
        return None


class InterruptibleEval(threading.Thread):
    """Evaluate Hy code cooperatively in a background thread."""

    def __init__(self, session: Any, msg: Dict[str, Any], writer: Callable[[Dict[str, Any]], None]) -> None:
        super().__init__(daemon=True)
        self.reader = HyReader()
        self.writer = writer
        self.msg = msg
        self.session = session
        self.expr = None
        self.session.eval_id = msg.get("id")
        self._old_stdin = sys.stdin
        sys.stdin = HyNReplSTDIN(writer)

    def raise_exc(self, exc: BaseException) -> None:
        logging.debug("Thread backend raise_exc: exc=%%s threads=%%s", exc, threading.enumerate())
        if not self.is_alive():  # pragma: no cover - defensive
            raise RuntimeError("Cannot raise exception in a dead thread")
        async_raise(self.ident, exc)

    def terminate(self) -> None:
        self.raise_exc(SystemExit())

    # tokenization helper
    def _tokenize(self, code: str):
        gen = self.reader.parse(StringIO(code))
        exprs = list(gen)
        if len(exprs) == 1:
            return exprs[0]
        exprs.insert(0, hy_models.Symbol("do"))
        return hy_models.Expression(exprs)

    def run(self) -> None:  # pragma: no cover - executed indirectly
        code = self.msg.get("code", "")
        oldout = sys.stdout
        try:
            expr = self._tokenize(code)
            sys.stdout = StreamingOut(self.writer)
            buffer = StringIO()
            logging.debug("Thread backend run: msg=%%s expr=%%s", self.msg, hy_repr(expr))
            buffer.write(str(hy_repr(hy_eval(expr, locals=self.session.locals, module=self.session.module))))
            self.writer({
                "value": buffer.getvalue(),
                "ns": self.msg.get("ns", "Hy"),
            })
            self.writer({"status": ["done"]})
        except Exception:  # pragma: no cover - exercised in tests
            self._format_exception(sys.exc_info())
            self.writer({"status": ["done"]})
        finally:
            sys.stdout = oldout
            sys.stdin = self._old_stdin
            self.session.eval_id = None

    def _format_exception(self, exc_info: Any) -> None:
        exc_type, exc_value, exc_tb = exc_info
        self.session.last_traceback = exc_tb
        payload = {
            "status": ["eval-error"],
            "ex": exc_type.__name__,
            "root-ex": exc_type.__name__,
            "id": self.msg.get("id"),
        }
        self.writer(payload)
        if isinstance(exc_value, LexException):
            logging.debug(
                "Thread backend format_exception: text=%%s msg=%%s",
                getattr(exc_value, "text", ""),
                getattr(exc_value, "msg", ""),
            )
            if exc_value.text is None:
                exc_value.text = ""
            exc_value = type(exc_value)(f"LexException: {exc_value.msg}")
        self.writer({"err": hy_exc_filter(*exc_info)})


class ThreadEvalBackend:
    """Adapter exposing the legacy thread-based evaluator."""

    def __init__(self, session: Any, **_: Any) -> None:
        self.session = session
        self.current: Optional[InterruptibleEval] = None

    # evaluation API -------------------------------------------------
    def eval(self, msg: Dict[str, Any], transport: Any) -> None:
        def writer(payload: Dict[str, Any]) -> None:
            if getattr(self.session, "stdin-id", None):
                payload.setdefault("id", self.session.stdin_id)
                self.session.stdin_id = None
            else:
                payload.setdefault("id", msg.get("id"))
            self.session.write(payload, transport)

        with self.session.lock:
            if self.current and self.current.is_alive():
                self.current.join()
            self.current = InterruptibleEval(self.session, msg, writer)
            self.session.repl = self.current
            self.current.start()

    def interrupt(self, msg: Dict[str, Any]) -> str:
        with self.session.lock:
            if not self.current or not self.current.is_alive():
                return "session-idle"
            if msg.get("interrupt-id") and msg.get("interrupt-id") != getattr(self.session, "eval-id", None):
                return "interrupt-id-mismatch"
            self.current.terminate()
            self.current.join()
            self.session.eval_id = None
            logging.debug("Thread backend interrupt: interrupted")
            return "interrupted"


__all__ = [
    "ThreadEvalBackend",
    "InterruptibleEval",
]
