import os
import signal
import threading
import time

import pytest

from hy_nrepl.backends import make_backend_factory
from hy_nrepl.bencode import decode_multiple
from hy_nrepl.session import SessionRegistry


class TransportCollector:
    def __init__(self):
        self.buffers = []

    def sendall(self, data: bytes) -> None:
        self.buffers.append(data)

    def messages(self):
        out = []
        for chunk in self.buffers:
            out.extend(decode_multiple(chunk))
        return out


@pytest.fixture
def process_session():
    factory = make_backend_factory("process")
    registry = SessionRegistry(factory, "process")
    session = registry.create()
    session.registry = registry
    try:
        yield session
    finally:
        if session.backend:
            session.backend.close()


def test_process_eval_success(process_session):
    transport = TransportCollector()
    msg = {"id": "msg1", "code": "(+ 1 2)", "ns": "Hy"}
    process_session.backend.eval(msg, transport)
    messages = transport.messages()
    assert any(m.get("value") == "3" for m in messages)
    assert any(m.get("status") == ["done"] for m in messages)


def test_process_interrupt_long_loop(process_session):
    transport = TransportCollector()
    msg = {
        "id": "loop",
        "code": "(do (import time) (while True (time.sleep 0.1)))",
        "ns": "Hy",
    }
    thread = threading.Thread(target=process_session.backend.eval, args=(msg, transport))
    thread.start()
    time.sleep(0.5)

    status = process_session.backend.interrupt({"interrupt-id": "loop"})
    assert status == "interrupted"
    thread.join(timeout=5)
    assert not thread.is_alive()

    messages = transport.messages()
    assert any(m.get("status") == ["done", "interrupted"] for m in messages)


def test_process_matplotlib_support(process_session):
    pytest.importorskip("matplotlib")
    transport = TransportCollector()
    code = "(do (import matplotlib) (import matplotlib.pyplot [as plt]) (.plot plt [1 2] [3 4]) (.close plt) \"ok\")"
    process_session.backend.eval({"id": "mpl", "code": code, "ns": "Hy"}, transport)
    messages = transport.messages()
    assert any(m.get("value") == '"ok"' for m in messages)


def test_process_forced_kill_and_restart(process_session):
    transport = TransportCollector()
    msg = {
        "id": "hang",
        "code": "(do (import time) (while True (time.sleep 0.2)))",
        "ns": "Hy",
    }
    thread = threading.Thread(target=process_session.backend.eval, args=(msg, transport))
    thread.start()
    time.sleep(0.5)

    worker = process_session.backend.worker
    if worker.alive:
        worker.kill()
        worker.wait(1.0)
    thread.join(timeout=5)
    assert not thread.is_alive()

    messages = transport.messages()
    assert any(m.get("status") == ["done", "aborted"] for m in messages)

    # Ensure worker is automatically restarted for the next evaluation
    transport2 = TransportCollector()
    process_session.backend.eval({"id": "next", "code": "(+ 4 5)", "ns": "Hy"}, transport2)
    messages2 = transport2.messages()
    assert any(m.get("value") == "9" for m in messages2)
