"""Integration test for completions via nREPL protocol with process backend."""
import socket
import time
import pytest

from hy_nrepl.bencode import encode, decode_multiple


def send_msg(sock, msg):
    """Send a message to nREPL server."""
    sock.sendall(encode(msg))


def recv_msgs(sock, timeout=5.0):
    """Receive all available messages from nREPL server."""
    sock.settimeout(timeout)
    data = b""
    start = time.time()
    while time.time() - start < timeout:
        try:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
            # Try to decode what we have
            try:
                msgs = list(decode_multiple(data))
                # Check if we have at least one "done" status
                for msg in msgs:
                    if "status" in msg and "done" in msg.get("status", []):
                        return msgs
            except:
                pass
        except socket.timeout:
            break

    # Return whatever we decoded
    if data:
        try:
            return list(decode_multiple(data))
        except:
            pass
    return []


def test_completions_integration_process_backend():
    """Test completions work end-to-end with process backend."""
    # Start a minimal test - we'll connect to an existing server
    # or skip if not available
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(("127.0.0.1", 7888))
    except ConnectionRefusedError:
        pytest.skip("nREPL server not running on port 7888")
        return

    try:
        # Clone a session
        send_msg(sock, {"op": "clone", "id": "clone1"})
        msgs = recv_msgs(sock)
        assert msgs, "Should receive clone response"

        session_id = None
        for msg in msgs:
            if "new-session" in msg:
                session_id = msg["new-session"]
                break

        assert session_id, f"Should get session ID from: {msgs}"

        # Import os module
        send_msg(sock, {
            "op": "eval",
            "code": "(import os)",
            "session": session_id,
            "id": "eval1"
        })
        msgs = recv_msgs(sock)
        assert any("done" in m.get("status", []) for m in msgs), f"Eval should complete: {msgs}"

        # Request completions for "os.get"
        send_msg(sock, {
            "op": "completions",
            "prefix": "os.get",
            "session": session_id,
            "id": "comp1"
        })
        msgs = recv_msgs(sock)

        # Find the completions response
        completions = []
        for msg in msgs:
            if "completions" in msg:
                completions = msg["completions"]
                break

        # Check we got completions
        assert completions, f"Should get completions, got messages: {msgs}"
        candidates = [c["candidate"] for c in completions]
        assert "os.getcwd" in candidates, f"Should find os.getcwd in {candidates}"

        print(f"✓ Found {len(completions)} completions including os.getcwd")

    finally:
        sock.close()


if __name__ == "__main__":
    test_completions_integration_process_backend()
