import hy
from hy_nrepl.server import start_server
from hy_nrepl.mcp_server import nrepl_eval


def test_nrepl_eval_basic():
    thread, srv = start_server("127.0.0.1", 0)
    host, port = srv.server_address
    try:
        result = nrepl_eval("(+ 1 1)", host=host, port=port)
        assert result == "2"
    finally:
        srv.shutdown()
        thread.join(timeout=1)
