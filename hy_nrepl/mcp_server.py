import asyncio
import socket
from typing import List

from mcp.server import FastMCP

from hy_nrepl.bencode import encode, decode


def _recv(sock: socket.socket, buf: bytearray) -> dict:
    """Receive a single bencoded message from the socket."""
    while True:
        try:
            msg, rest = decode(bytes(buf))
            buf[:] = rest
            return msg
        except Exception:
            data = sock.recv(4096)
            if not data:
                raise ConnectionError("connection closed")
            buf.extend(data)


def nrepl_eval(code: str, host: str = "127.0.0.1", port: int = 7888) -> str:
    """Evaluate Hy code through an nREPL server."""
    with socket.create_connection((host, port)) as sock:
        buf = bytearray()

        # Create a new session
        sock.sendall(encode({"op": "clone"}))
        session = _recv(sock, buf).get("new-session")

        # Send evaluation request
        sock.sendall(encode({"op": "eval", "code": code, "session": session}))

        values: List[str] = []
        while True:
            resp = _recv(sock, buf)
            if "value" in resp:
                values.append(resp["value"])
            if resp.get("status") and "done" in resp["status"]:
                break

        # Close session
        sock.sendall(encode({"op": "close", "session": session}))
        return "\n".join(values)


mcp_server = FastMCP("hy-nrepl-mcp")


@mcp_server.tool(name="eval")
def eval_tool(code: str) -> str:
    """Evaluate Hy expressions via nREPL."""
    return nrepl_eval(code)


async def main() -> None:
    await mcp_server.run_stdio_async()


if __name__ == "__main__":  # pragma: no cover - manual execution only
    asyncio.run(main())
