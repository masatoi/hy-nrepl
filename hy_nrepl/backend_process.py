"""Process-based evaluation backend for hy-nrepl."""
from __future__ import annotations

import json
import logging
import os
import subprocess
import sys
import threading
from dataclasses import dataclass
from typing import Any, Dict, Optional

LOGGER = logging.getLogger(__name__)

DEFAULT_CPU_LIMIT = 15  # seconds
DEFAULT_MEM_LIMIT = 512 * 1024 * 1024  # bytes (~512 MiB)
DEFAULT_MAX_HANDLES = 128
SOFT_INTERRUPT_TIMEOUT = 1.0  # seconds
HARD_INTERRUPT_TIMEOUT = 5.0  # seconds


class WorkerCrashed(RuntimeError):
    """Raised when the worker process exits unexpectedly."""


@dataclass
class WorkerConfig:
    session_id: str
    python: str = sys.executable
    module: str = "hy_nrepl.worker"
    cpu_limit: int = DEFAULT_CPU_LIMIT
    memory_limit: int = DEFAULT_MEM_LIMIT
    max_handles: int = DEFAULT_MAX_HANDLES

    def to_argv(self) -> list[str]:
        return [
            self.python,
            "-m",
            self.module,
            "--session",
            self.session_id,
            "--cpu-limit",
            str(self.cpu_limit),
            "--mem-limit",
            str(self.memory_limit),
            "--max-handles",
            str(self.max_handles),
        ]


class WorkerProcess:
    """Manage the lifetime and I/O of a worker subprocess."""

    def __init__(self, config: WorkerConfig) -> None:
        self.config = config
        self.process: Optional[subprocess.Popen[str]] = None
        self._stderr_thread: Optional[threading.Thread] = None
        self._write_lock = threading.Lock()
        self._read_lock = threading.Lock()

    # lifecycle ------------------------------------------------------
    def start(self) -> None:
        if self.process and self.process.poll() is None:
            return

        LOGGER.debug("Starting worker for session %s", self.config.session_id)
        env = os.environ.copy()
        env.setdefault("PYTHONUNBUFFERED", "1")
        argv = self.config.to_argv()
        self.process = subprocess.Popen(
            argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        assert self.process.stdin and self.process.stdout and self.process.stderr
        self._stderr_thread = threading.Thread(
            target=self._drain_stderr,
            name=f"hy-nrepl-worker-stderr-{self.config.session_id}",
            daemon=True,
        )
        self._stderr_thread.start()

    def _drain_stderr(self) -> None:  # pragma: no cover - logging helper
        assert self.process and self.process.stderr
        for line in self.process.stderr:
            LOGGER.debug("[worker %s] %s", self.config.session_id, line.rstrip())

    @property
    def alive(self) -> bool:
        return bool(self.process and self.process.poll() is None)

    def terminate(self) -> None:
        if not self.process:
            return
        if self.process.poll() is not None:
            return
        LOGGER.debug("Sending SIGTERM to worker %s", self.config.session_id)
        self.process.terminate()

    def kill(self) -> None:
        if not self.process:
            return
        if self.process.poll() is not None:
            return
        LOGGER.debug("Sending SIGKILL to worker %s", self.config.session_id)
        self.process.kill()

    def wait(self, timeout: float | None = None) -> Optional[int]:
        if not self.process:
            return None
        try:
            return self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    # communication --------------------------------------------------
    def send(self, payload: Dict[str, Any]) -> None:
        if not self.process or not self.process.stdin:
            raise WorkerCrashed("Worker stdin is not available")
        data = json.dumps(payload, ensure_ascii=False)
        with self._write_lock:
            try:
                self.process.stdin.write(data + "\n")
                self.process.stdin.flush()
            except (BrokenPipeError, ValueError) as exc:  # ValueError when closed
                raise WorkerCrashed("Failed to send to worker") from exc

    def read(self) -> Dict[str, Any]:
        if not self.process or not self.process.stdout:
            raise WorkerCrashed("Worker stdout is not available")
        with self._read_lock:
            line = self.process.stdout.readline()
        if line == "":
            raise WorkerCrashed("Worker terminated without response")
        try:
            return json.loads(line)
        except json.JSONDecodeError as exc:  # pragma: no cover - defensive
            raise WorkerCrashed(f"Worker sent invalid JSON: {line!r}") from exc


class ProcessEvalBackend:
    """Evaluation backend that proxies to a persistent worker process."""

    def __init__(
        self,
        session: Any,
        *,
        cpu_limit: int = DEFAULT_CPU_LIMIT,
        memory_limit: int = DEFAULT_MEM_LIMIT,
        max_handles: int = DEFAULT_MAX_HANDLES,
        soft_timeout: float = SOFT_INTERRUPT_TIMEOUT,
        hard_timeout: float = HARD_INTERRUPT_TIMEOUT,
    ) -> None:
        self.session = session
        self.config = WorkerConfig(
            session_id=session.id,
            cpu_limit=cpu_limit,
            memory_limit=memory_limit,
            max_handles=max_handles,
        )
        self.worker = WorkerProcess(self.config)
        self._soft_timeout = soft_timeout
        self._hard_timeout = hard_timeout
        self._current_eval_id: Optional[str] = None
        self._eval_done = threading.Event()
        self._forced_abort = False

    # helpers --------------------------------------------------------
    def _ensure_worker(self) -> None:
        if not self.worker.alive:
            self.worker.start()

    def _send(self, payload: Dict[str, Any], msg: Dict[str, Any], transport: Any) -> None:
        payload.setdefault("id", msg.get("id"))
        self.session.write(payload, transport)

    def _handle_outputs(self, response: Dict[str, Any], msg: Dict[str, Any], transport: Any) -> None:
        for key in ("stdout", "stderr"):
            text = response.get(key)
            if text:
                payload = {"out" if key == "stdout" else "err": text}
                self._send(payload, msg, transport)

    def _emit_success(self, response: Dict[str, Any], msg: Dict[str, Any], transport: Any) -> None:
        self._handle_outputs(response, msg, transport)
        value = response.get("repr", "")
        payload = {
            "value": value,
            "ns": msg.get("ns", "Hy"),
        }
        if "handle" in response:
            payload["hy-handle"] = response["handle"]
        self._send(payload, msg, transport)
        self._send({"status": ["done"]}, msg, transport)

    def _emit_error(self, response: Dict[str, Any], msg: Dict[str, Any], transport: Any) -> None:
        self._handle_outputs(response, msg, transport)
        err_type = response.get("type", "Error")
        message = response.get("message", "")
        traceback_text = response.get("traceback", "")
        if err_type in {"Interrupted", "Aborted"}:
            label = "interrupted" if err_type == "Interrupted" else "aborted"
            if message:
                self._send({"err": message}, msg, transport)
            self._send({"status": ["done", label]}, msg, transport)
            return

        status_payload = {
            "status": ["eval-error"],
            "ex": err_type,
            "root-ex": err_type,
            "id": msg.get("id"),
        }
        self.session.last_traceback = traceback_text
        self.session.write(status_payload, transport)
        if traceback_text:
            self._send({"err": traceback_text}, msg, transport)
        else:
            self._send({"err": message or err_type}, msg, transport)
        self._send({"status": ["done"]}, msg, transport)

    def _emit_abort(self, msg: Dict[str, Any], transport: Any) -> None:
        payload = {
            "ok": False,
            "type": "Aborted",
            "message": "Worker terminated",
        }
        self._emit_error(payload, msg, transport)

    def _send_interrupt(self) -> None:
        try:
            self.worker.send({"op": "interrupt"})
        except WorkerCrashed:
            LOGGER.warning("Worker crashed while sending interrupt", exc_info=True)

    def _hard_abort(self) -> None:
        self._forced_abort = True
        self.worker.terminate()
        exited = self.worker.wait(self._hard_timeout)
        if exited is None:
            self.worker.kill()
            self.worker.wait(1.0)
        self._eval_done.set()

    def _request(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        self._ensure_worker()
        self.worker.send(payload)
        return self.worker.read()

    # public API -----------------------------------------------------
    def eval(self, msg: Dict[str, Any], transport: Any) -> None:
        if "hy-deref" in msg or "hy-del" in msg:
            self._handle_handle_request(msg, transport)
            return

        options: Dict[str, Any] = {}
        if "hy-return" in msg:
            options["return"] = msg.get("hy-return")
        payload = {
            "op": "eval",
            "code": msg.get("code", ""),
            "session": self.session.id,
            "options": options,
        }

        self._ensure_worker()
        self._current_eval_id = msg.get("id")
        self.session.eval_id = self._current_eval_id
        self._eval_done.clear()
        try:
            self.worker.send(payload)
        except WorkerCrashed:
            self._emit_abort(msg, transport)
            self._current_eval_id = None
            self._eval_done.set()
            self.session.eval_id = None
            return

        try:
            response = self.worker.read()
        except WorkerCrashed:
            if self._forced_abort:
                self._emit_abort(msg, transport)
            else:
                self._emit_abort(msg, transport)
            self._current_eval_id = None
            self._eval_done.set()
            self._forced_abort = False
            self._ensure_worker()
            return

        self._eval_done.set()
        self._forced_abort = False
        self._current_eval_id = None
        self.session.eval_id = None
        if response.get("ok"):
            self._emit_success(response, msg, transport)
        else:
            self._emit_error(response, msg, transport)

    def _handle_handle_request(self, msg: Dict[str, Any], transport: Any) -> None:
        if "hy-deref" in msg:
            payload = {
                "op": "deref",
                "handle": msg.get("hy-deref"),
                "session": self.session.id,
            }
        else:
            payload = {
                "op": "del",
                "handle": msg.get("hy-del"),
                "session": self.session.id,
            }
        try:
            response = self._request(payload)
        except WorkerCrashed:
            self._emit_abort(msg, transport)
            self._forced_abort = False
            self._current_eval_id = None
            return
        if response.get("ok"):
            self._handle_outputs(response, msg, transport)
            payload = {
                "value": response.get("repr", ""),
                "ns": msg.get("ns", "Hy"),
            }
            if "handle" in response:
                payload["hy-handle"] = response["handle"]
            self._send(payload, msg, transport)
            self._send({"status": ["done"]}, msg, transport)
        else:
            self._emit_error(response, msg, transport)

    def interrupt(self, msg: Dict[str, Any]) -> str:
        eval_id = self._current_eval_id
        if not eval_id:
            return "session-idle"
        if msg.get("interrupt-id") and msg.get("interrupt-id") != eval_id:
            return "interrupt-id-mismatch"

        self._send_interrupt()
        if not self._eval_done.wait(self._soft_timeout):
            LOGGER.warning("Soft interrupt timed out; escalating")
            self._hard_abort()
        return "interrupted"

    def close(self) -> None:
        if self.worker.alive:
            self.worker.terminate()
            self.worker.wait(0.5)


__all__ = ["ProcessEvalBackend"]
