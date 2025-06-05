from pathlib import Path

import hy, pytest
import warnings

NATIVE_TESTS = Path.cwd() / "tests"

# Ignore PytestReturnNotNoneWarning on Pytest versions that define it.
try:
    warnings.filterwarnings(
        "ignore", category=pytest.PytestReturnNotNoneWarning, append=True
    )
except AttributeError:
    # Older Pytest versions do not provide this warning class.
    pass


def pytest_configure(config):
    """Apply warning filters after Pytest is fully configured."""
    try:
        warnings.filterwarnings(
            "ignore", category=pytest.PytestReturnNotNoneWarning, append=True
        )
    except AttributeError:
        pass


def pytest_collect_file(file_path, parent):
    if (
        file_path.suffix == ".hy"
        and NATIVE_TESTS in file_path.parents
        and file_path.name != "__init__.hy"
    ):
        return pytest.Module.from_parent(parent, path=file_path)
