import asyncio
import io
import itertools
import json
import logging
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
import time

import dpkt
import pytest
import yaml
from th1.http2.parser import parse_nghttpd_log
from th1.http2.signature import HTTP2Signature
from th1.tls.parser import parse_pcap
from th1.tls.signature import TLSClientHelloSignature


@pytest.fixture
def browser_signatures():
    docs = {}
    for path in pathlib.Path("signatures").glob("**/*.yaml"):
        with open(path, "r") as f:
            # Parse signatures.yaml database.
            for doc in yaml.safe_load_all(f.read()):
                if not doc:
                    continue
                browser = doc["browser"]
                key = f'{browser["name"]}_{browser["version"]}_{browser["os"]}'
                docs[key] = doc
                if browser.get("target"):
                    docs[browser["target"]] = doc
    return docs


"""
Test that the network signature of curl-impersonate is identical to that of
a real browser, by comparing with known signatures
"""

# When running curl use a specific range of local ports.
# This ensures we will capture the correct traffic in tcpdump.
LOCAL_PORTS = (50000, 50100)

SERVER_PORT = 8443

# List of binaries and their expected signatures
CURL_BINARIES_AND_SIGNATURES = yaml.safe_load(open("./targets.yaml"))
HTTP3_CLIENTS = []
for path in pathlib.Path("signatures").glob("**/*.yaml"):
    for doc in yaml.safe_load_all(path.read_text()):
        if not doc or not doc.get("signature", {}).get("http3"):
            continue
        profile = doc["browser"].get("target")
        if not profile:
            continue
        HTTP3_CLIENTS.extend(
            [
                pytest.param(
                    f"curl_{profile}", None, None, profile, id=f"{profile}-wrapper"
                ),
                pytest.param(
                    "minicurl",
                    {},
                    "libcurl-impersonate",
                    profile,
                    id=f"{profile}-libcurl",
                ),
            ]
        )


@pytest.fixture
def tcpdump(pytestconfig):
    """Initialize a sniffer to capture curl's traffic to the local server."""
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
                f"tcp src portrange {LOCAL_PORTS[0]}-{LOCAL_PORTS[1]}"
                f" and tcp dst port {SERVER_PORT}"
            ),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for "listening on ..." so curl doesn't run before the capture is active
    line = p.stderr.readline()
    logging.debug("tcpdump: %s", line.decode("utf-8", errors="replace").rstrip())

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


def _extract_client_hellos(pcap: bytes, port: int = SERVER_PORT) -> list[dict]:
    """Extract TLS Client Hello records from a loopback capture.

    th1's ``parse_pcap`` assumes Ethernet framing; macOS/BSD loopback
    captures use DLT_NULL (a 4-byte protocol family header per packet),
    so parse the IP payload directly in that case.
    """
    reader = dpkt.pcap.Reader(io.BytesIO(pcap))
    if reader.datalink() != dpkt.pcap.DLT_NULL:
        return parse_pcap(pcap, port=port)

    client_hellos = []
    for _, buf in reader:
        # Host byte order, OS-specific AF_* values
        family = int.from_bytes(buf[:4], sys.byteorder)
        try:
            if family == socket.AF_INET:
                ip = dpkt.ip.IP(buf[4:])
            elif family == socket.AF_INET6:
                ip = dpkt.ip6.IP6(buf[4:])
            else:
                continue
        except dpkt.UnpackError:
            continue
        if not isinstance(ip.data, dpkt.tcp.TCP):
            continue
        tcp = ip.data
        if tcp.dport != port or not tcp.data:
            continue
        tls = dpkt.ssl.TLSRecord(tcp.data)
        if tls.type != 0x16:  # Handshake
            continue
        handshake = dpkt.ssl.TLSHandshake(tls.data)
        if handshake.type != 0x01:  # Client Hello
            continue
        client_hellos.append(
            {
                "client_hello": tcp.data,
                "signature": TLSClientHelloSignature.from_bytes(tcp.data),
            }
        )
    return client_hellos


def _set_ld_preload(env_vars, lib):
    if sys.platform.startswith("linux"):
        env_vars["LD_PRELOAD"] = lib + ".so"
    elif sys.platform.startswith("darwin"):
        env_vars["DYLD_INSERT_LIBRARIES"] = lib + ".dylib"


def _run_curl(curl_binary, env_vars, extra_args, urls, output="/dev/null"):
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
        "-o",
        output,
        "--local-port",
        f"{LOCAL_PORTS[0]}-{LOCAL_PORTS[1]}",
    ]
    if extra_args:
        args += extra_args
    args.extend(urls)
    logging.debug("runing curl with: %s", " ".join(args))

    curl = subprocess.Popen(args, env=env)
    return curl.wait(timeout=60)


@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload, expected_signature",
    CURL_BINARIES_AND_SIGNATURES,
)
async def test_tls_client_hello(
    pytestconfig,
    tcpdump,
    nghttpd,
    curl_binary,
    env_vars,
    ld_preload,
    browser_signatures,
    expected_signature,
):
    """
    Check that curl's TLS signature is identical to that of a
    real browser.

    Launches curl against the local TLS server while sniffing its traffic
    with tcpdump on the loopback interface. Then extracts the Client Hello
    packets from the capture and compares their signature with the expected
    one defined in the YAML database.
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

    # Separate processes cannot resume TLS sessions
    expected_hellos = 2
    for _ in range(expected_hellos):
        ret = _run_curl(
            curl_binary,
            env_vars=env_vars,
            extra_args=["-k"],
            urls=[f"https://localhost:{SERVER_PORT}"],
        )
        assert ret == 0

    # Let tcpdump flush before stopping
    time.sleep(0.5)
    tcpdump.terminate()
    pcap, stderr = tcpdump.communicate(timeout=10)

    assert len(pcap) > 0, f"tcpdump produced no capture, stderr: {stderr}"
    logging.debug(f"Captured pcap of length {len(pcap)} bytes")

    client_hellos = _extract_client_hellos(pcap)

    # A client hello message for each curl invocation
    assert len(client_hellos) == expected_hellos, (
        f"Expected {expected_hellos} Client Hello messages, "
        f"found {len(client_hellos)}; tcpdump stderr: {stderr}"
    )

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


@pytest.mark.remote
@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload, profile", HTTP3_CLIENTS
)
def test_http3_fingerprint(
    pytestconfig, browser_signatures, curl_binary, env_vars, ld_preload, profile
):
    """Compare stable HTTP/3, QUIC, and QUIC TLS fingerprint fields."""
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )
    expected = browser_signatures[profile]["signature"]["http3"]
    env_vars = dict(env_vars or {})
    if ld_preload:
        if not sys.platform.startswith("linux"):
            pytest.skip()
        env_vars["CURL_IMPERSONATE"] = profile
        _set_ld_preload(
            env_vars,
            os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
        )

    with tempfile.TemporaryDirectory() as tmpdir:
        output = os.path.join(tmpdir, "fingerprint.json")
        for attempt in range(2):
            ret = _run_curl(
                curl_binary,
                env_vars=env_vars,
                extra_args=["--http3-only"],
                urls=["https://fp.impersonate.pro/api/http3"],
                output=output,
            )
            if ret == 0:
                break
            logging.warning("HTTP/3 fingerprint attempt %d failed", attempt + 1)
        assert ret == 0

        with open(output, "r") as f:
            response = json.load(f)

    assert "http3" in response, response.get("info", response)
    assert response["http3"]["perk_text_normalized"] == expected[
        "perk_text_normalized"
    ]

    actual_headers = response["http3"]["headers"]
    for name, value in expected["headers"].items():
        assert actual_headers.get(name) == value

    assert response["tls"]["ja3"]["text"] == expected["ja3_text"]
    signature_algorithms = next(
        extension
        for extension in response["tls"]["extensions"]
        if extension["name"] == "signature_algorithms"
    )
    assert signature_algorithms["data"]["algorithms"] == expected[
        "signature_algorithms"
    ]


@pytest.mark.parametrize(
    "curl_binary, env_vars, ld_preload, profile", HTTP3_CLIENTS
)
async def test_http3_fallback_to_http2(
    pytestconfig,
    nghttpd,
    browser_signatures,
    curl_binary,
    env_vars,
    ld_preload,
    profile,
):
    """HTTP/3 preferred mode must retain the profile when falling back to H2."""
    curl_binary = os.path.join(
        pytestconfig.getoption("install_dir"), "bin", curl_binary
    )
    env_vars = dict(env_vars or {})
    if ld_preload:
        if not sys.platform.startswith("linux"):
            pytest.skip()
        env_vars["CURL_IMPERSONATE"] = profile
        _set_ld_preload(
            env_vars,
            os.path.join(pytestconfig.getoption("install_dir"), "lib", ld_preload),
        )
    ret = _run_curl(
        curl_binary,
        env_vars=env_vars,
        extra_args=["--http3", "-k"],
        urls=["https://localhost:8443"],
    )
    assert ret == 0

    output = await _read_proc_output(nghttpd, timeout=2)
    assert len(output) > 0

    actual = parse_nghttpd_log(output)
    expected = HTTP2Signature.from_dict(
        browser_signatures[profile]["signature"]["http2"]
    )
    equals, msg = actual.equals(expected)
    assert equals, msg



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
