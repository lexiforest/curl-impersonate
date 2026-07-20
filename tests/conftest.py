import sys


def pytest_addoption(parser):
    # Where to find curl-impersonate's binaries
    parser.addoption("--install-dir", action="store", default="/usr/local")
    # Captures run against a local server, so default to loopback.
    parser.addoption(
        "--capture-interface",
        action="store",
        default="lo0" if sys.platform == "darwin" else "lo",
    )
