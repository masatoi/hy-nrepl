"""Evaluation backend factory helpers."""
from __future__ import annotations

from typing import Any, Callable, Dict

from .backend_process import ProcessEvalBackend
from .backend_thread import ThreadEvalBackend

BACKENDS: Dict[str, type] = {
    "process": ProcessEvalBackend,
    "thread": ThreadEvalBackend,
}


def make_backend_factory(name: str, **options: Any) -> Callable[[Any], Any]:
    """Return a callable that instantiates the requested backend.

    Parameters
    ----------
    name:
        Backend identifier (``process`` or ``thread``).
    options:
        Additional keyword arguments passed to the backend constructor.
    """
    key = (name or "").lower()
    try:
        backend_cls = BACKENDS[key]
    except KeyError as exc:  # pragma: no cover - defensive guard
        raise ValueError(f"Unknown eval backend: {name!r}") from exc

    def factory(session: Any) -> Any:
        return backend_cls(session=session, **options)

    return factory


__all__ = ["BACKENDS", "make_backend_factory"]
