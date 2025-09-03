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

from hy_nrepl.client import NreplClient

NREPL_SESSION: Optional[str] = None


def nrepl_eval(code: str, host: str = "127.0.0.1", port: int = 7888) -> str:
    """Evaluate Hy code through an nREPL server."""
    global NREPL_SESSION
    # Use the reusable Hy client to communicate
    with NreplClient(host, port, 5) as client:
        # Create a new session if we don't have one
        if NREPL_SESSION is None:
            client.send("clone", params={})
            resp = client.receive()
            NREPL_SESSION = (resp or {}).get("new-session")

        # Send evaluation request
        client.send("eval", params={"code": code, "session": NREPL_SESSION})

        values: List[str] = []
        errors: List[str] = []
        while True:
            resp = client.receive()
            if not resp:
                # Timeout or socket closed; surface as error string like previous behavior
                errors.append("No response from nREPL")
                break
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
    with NreplClient(host, port, 5) as client:
        msg_id = str(uuid.uuid4())
        client.send(
            "interrupt",
            params={"session": session, "interrupt-id": interrupt_id},
            msg_id=msg_id,
        )
        resp = client.receive()
        if not resp:
            return []
        return resp.get("status", [])


def nrepl_lookup(sym: str, host: str = "127.0.0.1", port: int = 7888) -> dict:
    """Lookup information about a symbol via nREPL."""
    global NREPL_SESSION
    with NreplClient(host, port, 5) as client:
        if NREPL_SESSION is None:
            client.send("clone", params={})
            resp = client.receive()
            NREPL_SESSION = (resp or {}).get("new-session")

        client.send("lookup", params={"sym": sym, "session": NREPL_SESSION})

        info: dict = {}
        while True:
            resp = client.receive()
            if not resp:
                break
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
