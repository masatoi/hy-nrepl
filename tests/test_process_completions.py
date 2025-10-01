"""Test completions and lookup operations with process backend."""
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


def test_completions_after_import(process_session):
    """Test that completions work after importing a module in process backend."""
    transport = TransportCollector()

    # First import os module
    msg = {"id": "import", "code": "(import os)", "ns": "Hy"}
    process_session.backend.eval(msg, transport)
    messages = transport.messages()
    assert any(m.get("status") == ["done"] for m in messages)

    # Now test completions for os.get using backend method
    completions = process_session.backend.completions("os.get")

    # Should find os.getcwd and other os.get* functions
    candidates = [c["candidate"] for c in completions]
    assert "os.getcwd" in candidates, f"Expected os.getcwd in {candidates}"
    assert len(completions) > 0, "Should have at least one completion"


def test_lookup_after_import(process_session):
    """Test that lookup works after importing a module in process backend."""
    transport = TransportCollector()

    # First import os module
    msg = {"id": "import", "code": "(import os)", "ns": "Hy"}
    process_session.backend.eval(msg, transport)
    messages = transport.messages()
    assert any(m.get("status") == ["done"] for m in messages)

    # Now test lookup for os.getcwd using backend method
    info = process_session.backend.lookup("os.getcwd")

    # Should find information about os.getcwd
    assert info, "Should get info for os.getcwd"
    assert "doc" in info or "name" in info, f"Info should contain doc or name: {info}"
