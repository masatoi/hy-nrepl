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


def test_process_session_isolation():
    """Test that two sessions have completely isolated state."""
    factory = make_backend_factory("process")
    registry = SessionRegistry(factory, "process")

    session1 = registry.create()
    session2 = registry.create()

    try:
        # Define a function in session1
        transport1 = TransportCollector()
        session1.backend.eval({"id": "def1", "code": "(defn foo [] 42)", "ns": "Hy"}, transport1)
        messages1 = transport1.messages()
        assert any(m.get("status") == ["done"] for m in messages1)

        # Call foo in session1 - should work
        transport2 = TransportCollector()
        session1.backend.eval({"id": "call1", "code": "(foo)", "ns": "Hy"}, transport2)
        messages2 = transport2.messages()
        assert any(m.get("value") == "42" for m in messages2)

        # Try to call foo in session2 - should fail with NameError
        transport3 = TransportCollector()
        session2.backend.eval({"id": "call2", "code": "(foo)", "ns": "Hy"}, transport3)
        messages3 = transport3.messages()
        # Should get an error message
        assert any("eval-error" in m.get("status", []) for m in messages3), f"Expected eval-error in {messages3}"

    finally:
        if session1.backend:
            session1.backend.close()
        if session2.backend:
            session2.backend.close()


def test_process_multi_eval_state_persistence(process_session):
    """Test that state persists across multiple evaluations."""
    # Define a variable
    transport1 = TransportCollector()
    process_session.backend.eval({"id": "def", "code": "(setv x 10)", "ns": "Hy"}, transport1)
    messages1 = transport1.messages()
    assert any(m.get("status") == ["done"] for m in messages1)

    # Use the variable in next eval
    transport2 = TransportCollector()
    process_session.backend.eval({"id": "use", "code": "(+ x 5)", "ns": "Hy"}, transport2)
    messages2 = transport2.messages()
    assert any(m.get("value") == "15" for m in messages2)

    # Define a function
    transport3 = TransportCollector()
    process_session.backend.eval({"id": "deffn", "code": "(defn add1 [n] (+ n 1))", "ns": "Hy"}, transport3)
    messages3 = transport3.messages()
    assert any(m.get("status") == ["done"] for m in messages3)

    # Call the function
    transport4 = TransportCollector()
    process_session.backend.eval({"id": "callfn", "code": "(add1 20)", "ns": "Hy"}, transport4)
    messages4 = transport4.messages()
    assert any(m.get("value") == "21" for m in messages4)


def test_process_error_handling(process_session):
    """Test various error scenarios."""
    # Syntax error
    transport1 = TransportCollector()
    process_session.backend.eval({"id": "syntax", "code": "(+ 1", "ns": "Hy"}, transport1)
    messages1 = transport1.messages()
    assert any("eval-error" in m.get("status", []) for m in messages1)

    # Name error
    transport2 = TransportCollector()
    process_session.backend.eval({"id": "name", "code": "(undefined-var)", "ns": "Hy"}, transport2)
    messages2 = transport2.messages()
    assert any("eval-error" in m.get("status", []) for m in messages2)

    # Runtime exception
    transport3 = TransportCollector()
    process_session.backend.eval({"id": "runtime", "code": "(/ 1 0)", "ns": "Hy"}, transport3)
    messages3 = transport3.messages()
    assert any("eval-error" in m.get("status", []) for m in messages3)

    # Worker should still be functional after errors
    transport4 = TransportCollector()
    process_session.backend.eval({"id": "recovery", "code": "(+ 2 3)", "ns": "Hy"}, transport4)
    messages4 = transport4.messages()
    assert any(m.get("value") == "5" for m in messages4)


def test_process_handle_management(process_session):
    """Test handle creation, deref, and deletion."""
    # Create a handle
    transport1 = TransportCollector()
    msg1 = {"id": "create", "code": "[1 2 3 4 5]", "hy-return": "handle", "ns": "Hy"}
    process_session.backend.eval(msg1, transport1)
    messages1 = transport1.messages()

    # Find the handle
    handle = None
    for m in messages1:
        if "hy-handle" in m:
            handle = m["hy-handle"]
            break

    assert handle is not None, f"Should get a handle, got messages: {messages1}"

    # Deref the handle
    transport2 = TransportCollector()
    msg2 = {"id": "deref", "hy-deref": handle, "ns": "Hy"}
    process_session.backend.eval(msg2, transport2)
    messages2 = transport2.messages()
    assert any(m.get("value") == "[1 2 3 4 5]" for m in messages2), f"Should deref handle: {messages2}"

    # Delete the handle
    transport3 = TransportCollector()
    msg3 = {"id": "del", "hy-del": handle, "ns": "Hy"}
    process_session.backend.eval(msg3, transport3)
    messages3 = transport3.messages()
    assert any(m.get("status") == ["done"] for m in messages3)

    # Trying to deref deleted handle should fail
    transport4 = TransportCollector()
    msg4 = {"id": "deref2", "hy-deref": handle, "ns": "Hy"}
    process_session.backend.eval(msg4, transport4)
    messages4 = transport4.messages()
    assert any("eval-error" in m.get("status", []) for m in messages4)


def test_process_interrupt_pure_computation(process_session):
    """Test that pure Python computation can be interrupted immediately."""
    # Define a recursive fibonacci function
    transport1 = TransportCollector()
    fib_def = """(defn fib [n]
      (if (<= n 1)
        n
        (+ (fib (- n 1)) (fib (- n 2)))))"""
    process_session.backend.eval({"id": "def", "code": fib_def, "ns": "Hy"}, transport1)
    messages1 = transport1.messages()
    assert any(m.get("status") == ["done"] for m in messages1)

    # Start a long computation (fib 35 takes several seconds)
    transport2 = TransportCollector()
    msg = {"id": "fib35", "code": "(fib 35)", "ns": "Hy"}
    thread = threading.Thread(target=process_session.backend.eval, args=(msg, transport2))
    thread.start()
    time.sleep(0.2)  # Let computation start

    # Interrupt and measure response time
    start = time.time()
    status = process_session.backend.interrupt({"interrupt-id": "fib35"})
    elapsed = time.time() - start
    assert status == "interrupted"
    thread.join(timeout=5)
    assert not thread.is_alive()

    # Pure Python computation should interrupt much faster than blocking calls
    # Soft interrupt (sys.settrace) should work immediately for pure Python
    # We expect < 0.1s, but allow some margin for system load
    assert elapsed < 0.2, f"Pure computation interrupt took {elapsed:.3f}s, expected < 0.2s"

    messages2 = transport2.messages()
    assert any(m.get("status") == ["done", "interrupted"] for m in messages2)
