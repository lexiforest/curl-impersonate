"""Local ws/wss smoke coverage for the installed libcurl-impersonate."""

import os
from pathlib import Path
import shlex
import ssl
import subprocess
import sys
import threading

import pytest
from websockets.extensions.base import Extension
from websockets.extensions.permessage_deflate import ServerPerMessageDeflateFactory
from websockets.frames import CTRL_OPCODES, OP_BINARY, OP_TEXT
from websockets.sync.server import serve


HERE = Path(__file__).resolve().parent


@pytest.fixture(scope="session")
def websocket_client(pytestconfig, tmp_path_factory):
    prefix = Path(pytestconfig.getoption("install_dir")).resolve()
    suffix = "dylib" if sys.platform == "darwin" else "so"
    library = prefix / "lib" / f"libcurl-impersonate.{suffix}"
    assert library.is_file(), f"Missing installed shared library: {library}"
    assert (prefix / "include/curl/websockets.h").is_file()
    executable = tmp_path_factory.mktemp("websocket") / "client"
    command = [
        *shlex.split(os.environ.get("CC", "cc")),
        "-Wall", "-Wextra", "-Werror",
        f"-I{prefix / 'include'}",
        str(HERE / "websocket.c"),
        str(library),
        f"-Wl,-rpath,{library.parent}",
        "-o", str(executable),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    return executable


class ObservedDeflate(Extension):
    """Record RSV1 before decoding and after encoding, at the wire boundary."""

    name = "permessage-deflate"

    def __init__(self, extension, received, sent):
        self.extension = extension
        self.received = received
        self.sent = sent

    def decode(self, frame, *, max_size=None):
        self.received.append((frame.opcode, frame.rsv1))
        return self.extension.decode(frame, max_size=max_size)

    def encode(self, frame):
        frame = self.extension.encode(frame)
        self.sent.append((frame.opcode, frame.rsv1))
        return frame


class ObservedDeflateFactory(ServerPerMessageDeflateFactory):
    def __init__(self):
        super().__init__()
        self.received = []
        self.sent = []

    def process_request_params(self, params, accepted_extensions):
        params, extension = super().process_request_params(params, accepted_extensions)
        return params, ObservedDeflate(extension, self.received, self.sent)


def run_websocket_smoke(websocket_client, scheme, profile, *, deflate=False):
    context = None
    if scheme == "wss":
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(HERE / "ssl/server.crt", HERE / "ssl/server.key")

    messages = []
    errors = []
    closed = threading.Event()

    def echo(connection):
        try:
            if deflate:
                assert "permessage-deflate" in connection.response.headers.get(
                    "Sec-WebSocket-Extensions", ""
                ), "permessage-deflate wasn't negotiated"
            for message in connection:
                messages.append(message)
                connection.send(message)
            assert connection.close_code == 1000
        except Exception as error:
            errors.append(error)
        finally:
            closed.set()

    extension = ObservedDeflateFactory() if deflate else None
    # Only enable compression through the observed extension, never implicitly.
    with serve(echo, "127.0.0.1", 0, ssl=context, compression=None,
               extensions=[extension] if deflate else None,
               open_timeout=5, close_timeout=2) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            port = server.socket.getsockname()[1]
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith("CURL_IMPERSONATE")}
            result = subprocess.run(
                [str(websocket_client), f"{scheme}://127.0.0.1:{port}/echo", profile]
                + (["--deflate"] if deflate else []),
                env=env, capture_output=True, text=True, timeout=15,
            )
            assert result.returncode == 0, result.stdout + result.stderr
            assert closed.wait(5), "Server did not finish the closing handshake"
            assert not errors, errors
            assert messages == [
                "WebSocket smoke: hello!",
                bytes(i % 256 for i in range(513)),
            ] * (2 if deflate else 1)
            if deflate:
                for direction, frames in [("client", extension.received),
                                          ("server", extension.sent)]:
                    data_frames = [(opcode, rsv1) for opcode, rsv1 in frames
                                   if opcode in (OP_TEXT, OP_BINARY)]
                    assert data_frames == [(OP_TEXT, True), (OP_BINARY, True)] * 2, (
                        f"{direction} didn't compress every data message: {frames}"
                    )
                    assert all(not rsv1 for opcode, rsv1 in frames
                               if opcode in CTRL_OPCODES), (
                        f"{direction} compressed a control frame: {frames}"
                    )
        finally:
            server.shutdown()
            thread.join(timeout=5)
            assert not thread.is_alive(), "WebSocket server did not stop"


@pytest.mark.parametrize("scheme", ["ws", "wss"])
@pytest.mark.parametrize("profile", ["none", "chrome150", "firefox144", "safari260"])
def test_websocket_smoke(websocket_client, scheme, profile):
    run_websocket_smoke(websocket_client, scheme, profile)


@pytest.mark.parametrize("scheme", ["ws", "wss"])
def test_websocket_permessage_deflate(websocket_client, scheme):
    run_websocket_smoke(websocket_client, scheme, "chrome150", deflate=True)
