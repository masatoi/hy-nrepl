import hy
from hy_nrepl.server import start_server
from hy_nrepl.mcp_server import nrepl_eval, nrepl_lookup
import hy_nrepl.mcp_server as mcp_server


def test_nrepl_eval_basic():
    mcp_server.NREPL_SESSION = None  # Ensure clean state before test
    thread, srv = start_server("127.0.0.1", 0)
    host, port = srv.server_address
    try:
        result = nrepl_eval("(+ 1 1)", host=host, port=port)
        assert result == "2"
    finally:
        mcp_server.NREPL_SESSION = None  # Clean up after test
        srv.shutdown()
        thread.join(timeout=1)


def test_nrepl_lookup_basic():
    mcp_server.NREPL_SESSION = None  # Ensure clean state before test
    thread, srv = start_server("127.0.0.1", 0)
    host, port = srv.server_address
    try:
        info = nrepl_lookup("map", host=host, port=port)
        assert info.get("name") == "map"
    finally:
        mcp_server.NREPL_SESSION = None  # Clean up after test
        srv.shutdown()
        thread.join(timeout=1)


def test_nrepl_eval_session_persistence():
    mcp_server.NREPL_SESSION = None  # Ensure clean state before test
    thread, srv = start_server("127.0.0.1", 0)
    host, port = srv.server_address
    try:
        # Define a variable
        nrepl_eval("(setv my-persistent-variable 100)", host=host, port=port)
        # Check if the variable is defined
        result = nrepl_eval("my-persistent-variable", host=host, port=port)
        assert result == "100"
    finally:
        mcp_server.NREPL_SESSION = None  # Clean up after test
        srv.shutdown()
        thread.join(timeout=1)
