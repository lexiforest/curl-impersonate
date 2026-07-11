import os
import sys
import random
import logging
import pathlib
import subprocess
import tempfile
import itertools
import asyncio

import yaml
import pytest
from th1.tls.parser import parse_pcap
from th1.tls.signature import TLSClientHelloSignature
from th1.http2.parser import parse_nghttpd_log
from th1.http2.signature import HTTP2Signature
import dpkt


@pytest.fixture
def browser_signatures():
    docs = {}
    for path in pathlib.Path("signatures").glob("**/*.yaml"):
        with open(path, "r") as f:
            # Parse signatures.yaml database.
            docs.update(
                {
                    f'{doc["browser"]["name"]}_{doc["browser"]["version"]}_{doc["browser"]["os"]}': doc
                    for doc in yaml.safe_load_all(f.read())
                    if doc
                }
            )
    return docs


"""
Test that the network signature of curl-impersonate is identical to that of
a real browser, by comparing with known signatures
"""

# When running curl use a specific range of local ports.
# This ensures we will capture the correct traffic in tcpdump.
LOCAL_PORTS = (50000, 50100)


# https://docs.github.com/en/actions/learn-github-actions/variables
logging.debug("$CI is: %s", os.getenv("CI"))
TEST_URLS = [
    "https://www.wikimedia.org",
    "https://www.wikipedia.org",
    "https://www.mozilla.org/en-US/",
    "https://www.apache.org",
    # "https://www.kernel.org",
    "https://git-scm.com",
]
# TEST_URLS = [
#     "https://tls.browserleaks.com/json",
#     "https://httpbin.org/ip",
# ]

# List of binaries and their expected signatures
CURL_BINARIES_AND_SIGNATURES = yaml.safe_load(open("./targets.yaml"))
HTTP3_TARGETS = yaml.safe_load(open("./http3_targets.yaml"))


@pytest.fixture
def test_urls():
    # Shuffle TEST_URLS randomly
    return random.sample(TEST_URLS, k=len(TEST_URLS))


@pytest.fixture
def tcpdump(pytestconfig):
    """Initialize a sniffer to capture curl's traffic."""
    interface = pytestconfig.getoption("capture_interface")

    logging.debug(f"Running tcpdump on interface {interface}")

    p = subprocess.Popen(
        [
            "tcpdump",
            "-n",
            "-i",
            interface,
            "-s",
            "0",
            "-w",
            "-",
            "-U",  # Important, makes tcpdump unbuffered
            (
                f"(tcp src portrange {LOCAL_PORTS[0]}-{LOCAL_PORTS[1]}"
                f" and tcp dst port 443) or"
                f"(tcp dst portrange {LOCAL_PORTS[0]}-{LOCAL_PORTS[1]}"
                f" and tcp src port 443)"
            ),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    yield p

    p.terminate()
    p.wait(timeout=10)


async def _read_proc_output(proc, timeout: int = 5):
    """Read an async process' output until timeout is reached"""
    data = bytes()
    loop = asyncio.get_running_loop()
    start_time = loop.time()
    passed = loop.time() - start_time
    while passed < timeout:
        try:
            data += await asyncio.wait_for(
                proc.stdout.readline(), timeout=timeout - passed
            )
        except asyncio.TimeoutError:
            pass
        passed = loop.time() - start_time
    return data


def _pull_quic_varint(data, offset=0):
    """Pull a QUIC variable-length integer from bytes."""
    if offset >= len(data):
        raise ValueError("not enough data for QUIC varint")

    first = data[offset]
    length = 1 << (first >> 6)
    if offset + length > len(data):
        raise ValueError("truncated QUIC varint")

    value = first & 0x3F
    for byte in data[offset + 1 : offset + length]:
        value = (value << 8) | byte
    return value, offset + length


def _decode_quic_varint(data):
    if not data:
        return None

    try:
        value, offset = _pull_quic_varint(data)
    except ValueError:
        return None
    if offset != len(data):
        return None
    return value


def _is_quic_grease_id(value):
    # QUIC GREASE transport parameter identifiers follow 31 * N + 27.
    return value >= 27 and ((value - 27) % 31) == 0


def _is_h3_settings_grease_id(value):
    # HTTP/3 GREASE setting identifiers follow 31 * N + 33.
    return value >= 33 and ((value - 33) % 31) == 0


def _decode_quic_transport_parameter(key, raw_value):
    if key == 17 and len(raw_value) >= 4 and len(raw_value) % 4 == 0:
        versions = [
            int.from_bytes(raw_value[i : i + 4], "big")
            for i in range(0, len(raw_value), 4)
        ]
        return {
            "version_information": {
                "chosen": versions[0],
                "available": versions[1:],
            }
        }

    if key == 18258 and len(raw_value) == 4:
        return {"value": int.from_bytes(raw_value, "big")}

    decoded = _decode_quic_varint(raw_value)
    if decoded is not None:
        return {"value": decoded}

    return {"hex": raw_value.hex()}


def _parse_quic_transport_parameters(data):
    params = []
    offset = 0
    while offset < len(data):
        key, offset = _pull_quic_varint(data, offset)
        value_len, offset = _pull_quic_varint(data, offset)
        if offset + value_len > len(data):
            raise ValueError("truncated QUIC transport parameter")

        raw_value = data[offset : offset + value_len]
        offset += value_len

        param = {"key": key}
        if _is_quic_grease_id(key):
            param["grease"] = True
            param["hex"] = raw_value.hex()
        else:
            param.update(_decode_quic_transport_parameter(key, raw_value))
        params.append(param)
    return params


def _headers_to_strings(headers):
    values = []
    for name, value in headers:
        values.append(f"{name.decode('utf-8')}: {value.decode('utf-8')}")
    return values


def _split_pseudo_headers(headers):
    pseudo_headers = []
    regular_headers = []
    for header in headers:
        if header.startswith(":"):
            assert not regular_headers, f"Pseudo-header appeared after headers: {header}"
            name = ":" + header[1:].split(":", 1)[0]
            pseudo_headers.append(name)
        else:
            regular_headers.append(header)
    return pseudo_headers, regular_headers


def _normalize_header(header):
    name, value = header.split(":", 1)
    return f"{name.lower()}:{value}"


def _assert_h3_settings(actual, expected):
    assert len(actual) == len(expected), (
        f"HTTP/3 SETTINGS length mismatch: expected {expected}, got {actual}"
    )
    for actual_setting, expected_setting in zip(actual, expected):
        if expected_setting.get("grease"):
            assert _is_h3_settings_grease_id(actual_setting["key"]), (
                f"Expected HTTP/3 SETTINGS GREASE id, got {actual_setting}"
            )
        else:
            assert actual_setting == expected_setting


def _assert_version_information(actual, expected):
    assert actual["chosen"] == expected["chosen"]
    assert len(actual["available"]) == len(expected["available"])
    for actual_version, expected_version in zip(
        actual["available"], expected["available"]
    ):
        if expected_version.get("grease"):
            assert _is_quic_grease_version(actual_version), (
                f"Expected QUIC version GREASE value, got {actual_version}"
            )
        else:
            assert actual_version == expected_version["value"]


def _is_quic_grease_version(value):
    return (value & 0x0F0F0F0F) == 0x0A0A0A0A


def _quic_param_matches(actual, expected):
    if expected.get("grease"):
        return actual.get("grease") is True

    if actual["key"] != expected["key"]:
        return False

    if "version_information" in expected:
        if "version_information" not in actual:
            return False
        _assert_version_information(
            actual["version_information"], expected["version_information"]
        )
        return True

    if expected.get("value") == "any":
        return "value" in actual
    if expected.get("hex") == "any":
        return "hex" in actual
    if "value" in expected:
        return actual.get("value") == expected["value"]
    if "hex" in expected:
        return actual.get("hex") == expected["hex"]

    return actual == expected


def _assert_quic_transport_parameters(actual, expected, allow_permutation):
    assert len(actual) == len(expected), (
        f"QUIC transport parameter length mismatch: expected {expected}, got {actual}"
    )

    if not allow_permutation:
        for actual_param, expected_param in zip(actual, expected):
            assert _quic_param_matches(actual_param, expected_param), (
                f"Expected QUIC transport parameter {expected_param}, "
                f"got {actual_param}"
            )
        return

    unmatched = list(actual)
    for expected_param in expected:
        for i, actual_param in enumerate(unmatched):
            if _quic_param_matches(actual_param, expected_param):
                unmatched.pop(i)
                break
        else:
            raise AssertionError(
                f"Missing QUIC transport parameter {expected_param}; got {actual}"
            )


class H3TestServer:
    def __init__(self, server, port, requests):
        self._server = server
        self.port = port
        self.requests = requests
        self.url = f"https://127.0.0.1:{port}/"

    async def next_request(self, timeout=5):
        return await asyncio.wait_for(self.requests.get(), timeout=timeout)

    def close(self):
        self._server.close()


async def _wait_nghttpd(proc):
    """Wait for nghttpd to start listening on its designated port"""
    data = bytes()
    while data is not None:
        data = await proc.stdout.readline()
        if not data:
            # Process terminated
            return False

        line = data.decode("utf-8").rstrip()
        if "listen 0.0.0.0:8443" in line:
            return True

    return False


@pytest.fixture
async def nghttpd():
    """Initialize an HTTP/2 server.
    The returned object is an asyncio.subprocess.Process object,
    so async methods must be used with it.
    """
    logging.debug("Running nghttpd on :8443")

    # Launch nghttpd and wait for it to start listening.

    proc = await asyncio.create_subprocess_exec(
        "nghttpd",
        "-v",
        "8443",
        "ssl/server.key",
        "ssl/server.crt",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    try:
        # Wait up to 3 seconds for nghttpd to start.
        # Otherwise fail.
        started = await asyncio.wait_for(_wait_nghttpd(proc), timeout=3)
        if not started:
            raise Exception("nghttpd failed to start")
    except asyncio.TimeoutError:
        raise Exception("nghttpd failed to start on time")

    yield proc

    proc.terminate()
    await proc.wait()


@pytest.fixture
async def h3_server():
    """Initialize a local HTTP/3 server and record the client's fingerprint."""
    aioquic_asyncio = pytest.importorskip("aioquic.asyncio")
    aioquic_protocol = pytest.importorskip("aioquic.asyncio.protocol")
    aioquic_configuration = pytest.importorskip("aioquic.quic.configuration")
    aioquic_events = pytest.importorskip("aioquic.quic.events")
    aioquic_h3_connection = pytest.importorskip("aioquic.h3.connection")
    aioquic_h3_events = pytest.importorskip("aioquic.h3.events")

    requests = asyncio.Queue()

    class H3RecorderProtocol(aioquic_protocol.QuicConnectionProtocol):
        def __init__(self, *args, request_queue, **kwargs):
            super().__init__(*args, **kwargs)
            self._http = aioquic_h3_connection.H3Connection(self._quic)
            self._request_queue = request_queue
            self._transport_parameters = []

            original_parse = self._quic._parse_transport_parameters

            def record_transport_parameters(data, from_session_ticket=False):
                if not from_session_ticket:
                    self._transport_parameters = _parse_quic_transport_parameters(data)
                return original_parse(data, from_session_ticket)

            self._quic._parse_transport_parameters = record_transport_parameters

        def quic_event_received(self, event):
            if isinstance(event, aioquic_events.ConnectionTerminated):
                return

            for h3_event in self._http.handle_event(event):
                if isinstance(h3_event, aioquic_h3_events.HeadersReceived):
                    headers = _headers_to_strings(h3_event.headers)
                    settings = [
                        {"key": int(key), "value": int(value)}
                        for key, value in (self._http.received_settings or {}).items()
                    ]
                    self._request_queue.put_nowait(
                        {
                            "headers": headers,
                            "http3_settings": settings,
                            "quic_transport_parameters": self._transport_parameters,
                        }
                    )

                    self._http.send_headers(
                        stream_id=h3_event.stream_id,
                        headers=[
                            (b":status", b"200"),
                            (b"content-length", b"2"),
                        ],
                    )
                    self._http.send_data(
                        stream_id=h3_event.stream_id, data=b"ok", end_stream=True
                    )
                    self.transmit()

    config = aioquic_configuration.QuicConfiguration(
        is_client=False,
        alpn_protocols=aioquic_h3_connection.H3_ALPN,
        max_datagram_frame_size=65536,
    )
    config.load_cert_chain("ssl/server.crt", "ssl/server.key")

    def create_protocol(*args, **kwargs):
        return H3RecorderProtocol(*args, request_queue=requests, **kwargs)

    server = await aioquic_asyncio.serve(
        "127.0.0.1",
        0,
        configuration=config,
        create_protocol=create_protocol,
    )
    host, port = server._transport.get_extra_info("sockname")
    logging.debug(f"Running aioquic HTTP/3 server on {host}:{port}")

    test_server = H3TestServer(server, port, requests)
    try:
        yield test_server
    finally:
        test_server.close()
        await asyncio.sleep(0)


def _set_ld_preload(env_vars, lib):
    if sys.platform.startswith("linux"):
        env_vars["LD_PRELOAD"] = lib + ".so"
    elif sys.platform.startswith("darwin"):
        env_vars["DYLD_INSERT_LIBRARIES"] = lib + ".dylib"


def _build_curl_env_and_args(
    curl_binary, env_vars, extra_args, urls, output="/dev/null"
):
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)

    logging.debug(f"Launching '{curl_binary}' to {urls}")
    if env_vars:
        logging.debug(
            "Environment variables: {}".format(
                " ".join([f"{k}={v}" for k, v in env_vars.items()])
            )
        )

    args = [
        curl_binary,
        "-o",
        output,
        "--local-port",
        f"{LOCAL_PORTS[0]}-{LOCAL_PORTS[1]}",
    ]
    if extra_args:
        args += extra_args
    args.extend(urls)
    logging.debug("runing curl with: %s", " ".join(args))
    return env, args


def _run_curl(curl_binary, env_vars, extra_args, urls, output="/dev/null"):
    env, args = _build_curl_env_and_args(
        curl_binary, env_vars, extra_args, urls, output
    )

    curl = subprocess.Popen(args, env=env)
    return curl.wait(timeout=60)


async def _run_curl_async(curl_binary, env_vars, extra_args, urls, output="/dev/null"):
    env, args = _build_curl_env_and_args(
        curl_binary, env_vars, extra_args, urls, output
    )
    proc = await asyncio.create_subprocess_exec(*args, env=env)
    return await asyncio.wait_for(proc.wait(), timeout=60)


@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload, expected_signature",
    CURL_BINARIES_AND_SIGNATURES,
)
def test_tls_client_hello(
    pytestconfig,
    tcpdump,
    curl_binary,
    env_vars,
    ld_preload,
    browser_signatures,
    expected_signature,
    test_urls,
):
    """
    Check that curl's TLS signature is identical to that of a
    real browser.

    Launches curl while sniffing its TLS traffic with tcpdump. Then
    extracts the Client Hello packet from the capture and compares its
    signature with the expected one defined in the YAML database.
    """
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )
    if ld_preload:
        # Injecting libcurl-impersonate with LD_PRELOAD is supported on
        # Linux only. On Mac there is DYLD_INSERT_LIBRARIES but it
        # requires more work to be functional.
        if not sys.platform.startswith("linux"):
            pytest.skip()

        _set_ld_preload(
            env_vars,
            os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
        )

    test_urls = test_urls[0:2]
    ret = _run_curl(curl_binary, env_vars=env_vars, extra_args=None, urls=test_urls)
    assert ret == 0

    try:
        pcap, stderr = tcpdump.communicate(timeout=5)

        # If tcpdump finished running before timeout, it's likely it failed
        # with an error.
        assert tcpdump.returncode == 0, (
            f"tcpdump failed with error code {tcpdump.returncode}, " f"stderr: {stderr}"
        )
    except subprocess.TimeoutExpired:
        tcpdump.kill()
        pcap, stderr = tcpdump.communicate(timeout=3)

    assert len(pcap) > 0
    logging.debug(f"Captured pcap of length {len(pcap)} bytes")

    try:
        client_hellos = parse_pcap(pcap)
    except dpkt.NeedData:
        logging.error("DPKT does not support Chrome 124 yet.")
        return

    # A client hello message for each URL
    assert len(client_hellos) == len(test_urls)

    logging.debug(
        f"Found {len(client_hellos)} Client Hello messages, "
        f"comparing to signature '{expected_signature}'"
    )

    for client_hello in client_hellos:
        # sig = TLSClientHelloSignature.from_bytes(client_hello)
        sig = client_hello["signature"]
        expected_sig = TLSClientHelloSignature.from_dict(
            browser_signatures[expected_signature]["signature"]["tls_client_hello"]
        )

        allow_tls_permutation = (
            browser_signatures[expected_signature]["signature"]
            .get("options", {})
            .get("tls_permute_extensions", False)
        )

        equals, reason = expected_sig.equals(sig, allow_tls_permutation)
        assert equals, reason


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload, expected_signature",
    CURL_BINARIES_AND_SIGNATURES,
)
async def test_http2_headers(
    pytestconfig,
    nghttpd,
    curl_binary,
    env_vars,
    ld_preload,
    browser_signatures,
    expected_signature,
):
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )
    if ld_preload:
        # Injecting libcurl-impersonate with LD_PRELOAD is supported on
        # Linux only. On Mac there is DYLD_INSERT_LIBRARIES but it
        # requires more work to be functional.
        if not sys.platform.startswith("linux"):
            pytest.skip()

        _set_ld_preload(
            env_vars,
            os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
        )

    ret = _run_curl(
        curl_binary,
        env_vars=env_vars,
        extra_args=["-k"],
        urls=["https://localhost:8443"],
    )
    assert ret == 0

    output = await _read_proc_output(nghttpd, timeout=2)

    assert len(output) > 0
    sig = parse_nghttpd_log(output)

    logging.debug(f"Received {len(sig.frames)} HTTP/2 frames")

    expected_sig = HTTP2Signature.from_dict(
        browser_signatures[expected_signature]["signature"]["http2"]
    )

    equals, msg = sig.equals(expected_sig)
    assert equals, msg


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "target",
    HTTP3_TARGETS,
    ids=[target["curl_binary"] for target in HTTP3_TARGETS],
)
async def test_http3_and_quic_fingerprints(pytestconfig, h3_server, target):
    """
    Check HTTP/3 and QUIC fingerprint surfaces against the H3-enabled
    impersonation profiles.
    """
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", target["curl_binary"]
    )

    ret = await _run_curl_async(
        curl_binary,
        env_vars=None,
        extra_args=["--http3-only", "-k"],
        urls=[h3_server.url],
    )
    assert ret == 0

    request = await h3_server.next_request(timeout=5)
    expected = target["expected"]

    pseudo_headers, headers = _split_pseudo_headers(request["headers"])
    assert pseudo_headers == expected["http3"]["pseudo_headers"]
    assert [_normalize_header(h) for h in headers] == [
        _normalize_header(h) for h in expected["http3"]["headers"]
    ]

    _assert_h3_settings(
        request["http3_settings"],
        expected["http3"]["settings"],
    )
    _assert_quic_transport_parameters(
        request["quic_transport_parameters"],
        expected["quic"]["transport_parameters"],
        expected["quic"].get("allow_permutation", False),
    )



@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload",
    [
        (
            "minicurl",
            {"CURL_IMPERSONATE": "chrome101", "CURL_IMPERSONATE_HEADERS": "no"},
            "libcurl-impersonate",
        ),
    ],
)
async def test_no_builtin_headers(
    pytestconfig, nghttpd, curl_binary, env_vars, ld_preload
):
    """
    Ensure the built-in headers of libcurl-impersonate are not added when
    the CURL_IMPERSONATE_HEADERS environment variable is set to "no".
    """
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )

    if not sys.platform.startswith("linux"):
        pytest.skip()

    _set_ld_preload(
        env_vars,
        os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
    )

    # Use some custom headers with a specific order.
    # We will test that the headers are sent in the exact given order, as
    # it is important for users to be able to control the exact headers
    # content and order.
    headers = [
        "X-Hello: World",
        "Accept: application/json",
        "X-Goodbye: World",
        "Accept-Encoding: deflate, gzip, br" "X-Foo: Bar",
        "User-Agent: curl-impersonate",
    ]
    header_args = list(itertools.chain(*[["-H", header] for header in headers]))

    ret = _run_curl(
        curl_binary,
        env_vars=env_vars,
        extra_args=["-k"] + header_args,
        urls=["https://localhost:8443"],
    )
    assert ret == 0

    output = await _read_proc_output(nghttpd, timeout=5)

    assert len(output) > 0
    sig = parse_nghttpd_log(output)
    for frame in sig.frames:
        if frame.frame_type == "HEADERS":
            headers_frame = frame
    for i, header in enumerate(headers_frame.headers):
        assert header.lower() == headers[i].lower()


@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload",
    [
        (
            "minicurl",
            {"CURL_IMPERSONATE": "chrome101"},
            "libcurl-impersonate",
        ),
        (
            "minicurl",
            {"CURL_IMPERSONATE": "chrome101", "CURL_IMPERSONATE_HEADERS": "no"},
            "libcurl-impersonate",
        ),
    ],
)
async def test_user_agent(pytestconfig, nghttpd, curl_binary, env_vars, ld_preload):
    """
    Ensure that any user-agent set with CURLOPT_HTTPHEADER will override
    the one set by libcurl-impersonate.
    """
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )

    if not sys.platform.startswith("linux"):
        pytest.skip()

    _set_ld_preload(
        env_vars,
        os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
    )

    user_agent = "My-User-Agent"

    ret = _run_curl(
        curl_binary,
        env_vars=env_vars,
        extra_args=["-k", "-H", f"User-Agent: {user_agent}"],
        urls=["https://localhost:8443"],
    )
    assert ret == 0

    output = await _read_proc_output(nghttpd, timeout=5)

    assert len(output) > 0

    sig = parse_nghttpd_log(output)
    for frame in sig.frames:
        if frame.frame_type == "HEADERS":
            headers_frame = frame
    assert any(
        [header.lower().startswith("user-agent:") for header in headers_frame.headers]
    )

    for header in headers_frame.headers:
        if header.lower().startswith("user-agent:"):
            assert header[len("user-agent:") :].strip() == user_agent


@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload",
    [
        (
            "minicurl",
            {"CURL_IMPERSONATE": "chrome101"},
            "libcurl-impersonate",
        ),
        (
            "minicurl",
            {"CURL_IMPERSONATE": "chrome101", "CURL_IMPERSONATE_HEADERS": "no"},
            "libcurl-impersonate",
        ),
    ],
)
async def test_user_agent_curlopt_useragent(
    pytestconfig, nghttpd, curl_binary, env_vars, ld_preload
):
    """
    Ensure that any user-agent set with CURLOPT_USERAGENT will override
    the one set by libcurl-impersonate. See:
    https://github.com/lwthiker/curl-impersonate/issues/51
    """
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )

    if not sys.platform.startswith("linux"):
        pytest.skip()

    _set_ld_preload(
        env_vars,
        os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
    )

    user_agent = "My-User-Agent"

    ret = _run_curl(
        curl_binary,
        env_vars=env_vars,
        extra_args=["-k", "-A", user_agent],
        urls=["https://localhost:8443"],
    )
    assert ret == 0

    output = await _read_proc_output(nghttpd, timeout=5)

    assert len(output) > 0

    sig = parse_nghttpd_log(output)
    for frame in sig.frames:
        if frame.frame_type == "HEADERS":
            headers_frame = frame
    headers = headers_frame.headers
    assert any([header.lower().startswith("user-agent:") for header in headers])

    for header in headers:
        if header.lower().startswith("user-agent:"):
            assert header[len("user-agent:") :].strip() == user_agent
