import asyncio
import socket
import uuid
from typing import List, Optional

import hy  # ensure `.hy` modules can be imported
# `modelcontextprotocol` is an optional dependency. Import lazily so tests and
# consumers that only use the helper functions below can run without the MCP
# package installed.
try:  # pragma: no cover - exercised in CI when MCP is available
    from mcp.server import FastMCP  # type: ignore
except Exception:  # pragma: no cover - executed when MCP is missing
    FastMCP = None  # type: ignore[assignment]

from hy_nrepl.bencode import encode, decode

NREPL_SESSION: Optional[str] = None


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
    global NREPL_SESSION
    with socket.create_connection((host, port)) as sock:
        buf = bytearray()

        # Create a new session if we don't have one
        if NREPL_SESSION is None:
            sock.sendall(encode({"op": "clone"}))
            NREPL_SESSION = _recv(sock, buf).get("new-session")

        # Send evaluation request
        sock.sendall(encode({"op": "eval", "code": code, "session": NREPL_SESSION}))

        values: List[str] = []
        errors: List[str] = []
        while True:
            resp = _recv(sock, buf)
            if "value" in resp:
                values.append(resp["value"])
            if "err" in resp:
                errors.append(resp["err"])
            if "ex" in resp:
                errors.append(f"Exception: {resp['ex']}")
            if resp.get("status") and "done" in resp["status"]:
                break

        if errors:
            return "\n".join(errors)
        return "\n".join(values)


def nrepl_interrupt(
    session: str,
    interrupt_id: str,
    host: str = "127.0.0.1",
    port: int = 7888,
) -> List[str]:
    """Send an interrupt request for a running eval."""
    with socket.create_connection((host, port)) as sock:
        buf = bytearray()
        msg_id = str(uuid.uuid4())
        sock.sendall(
            encode(
                {
                    "op": "interrupt",
                    "session": session,
                    "interrupt-id": interrupt_id,
                    "id": msg_id,
                }
            )
        )
        resp = _recv(sock, buf)
        return resp.get("status", [])


def nrepl_lookup(sym: str, host: str = "127.0.0.1", port: int = 7888) -> dict:
    """Lookup information about a symbol via nREPL."""
    global NREPL_SESSION
    with socket.create_connection((host, port)) as sock:
        buf = bytearray()
        if NREPL_SESSION is None:
            sock.sendall(encode({"op": "clone"}))
            NREPL_SESSION = _recv(sock, buf).get("new-session")
        sock.sendall(encode({"op": "lookup", "sym": sym, "session": NREPL_SESSION}))

        info: dict = {}
        while True:
            resp = _recv(sock, buf)
            if "info" in resp:
                info = resp["info"]
            if resp.get("status") and "done" in resp["status"]:
                break

        return info


if FastMCP is not None:  # pragma: no cover - only when MCP is installed
    mcp_server = FastMCP("hy-nrepl-mcp")

    @mcp_server.tool(name="eval")
    def eval_tool(code: str) -> str:
        """Evaluate Hy expressions via nREPL."""
        return nrepl_eval(code)

    @mcp_server.tool(name="interrupt")
    def interrupt_tool(session: str, interrupt_id: str) -> List[str]:
        """Interrupt a running eval in the given session."""
        return nrepl_interrupt(session, interrupt_id)

    @mcp_server.tool(name="lookup")
    def lookup_tool(sym: str) -> dict:
        """Lookup symbol information via nREPL."""
        return nrepl_lookup(sym)

    async def main() -> None:
        await mcp_server.run_stdio_async()
else:
    mcp_server = None

    async def main() -> None:  # pragma: no cover - only when MCP missing
        raise ModuleNotFoundError("mcp package is not installed")


if __name__ == "__main__":  # pragma: no cover - manual execution only
    asyncio.run(main())