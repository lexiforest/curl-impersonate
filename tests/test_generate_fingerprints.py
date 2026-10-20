"""Offline regression tests for generated fingerprint expectations."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

import pytest
import yaml
from th1.tls.signature import TLSClientHelloSignature

from test_impersonate import _assert_http3_signature, _assert_partial_tls_signature


spec = importlib.util.spec_from_file_location(
    "generate_fingerprints",
    Path(__file__).resolve().parents[1] / "scripts/generate_fingerprints.py",
)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


@pytest.fixture
def profile():
    return {
        "name": "example",
        "fingerprint": {
            "client": "example", "client_version": "1", "os": "test", "os_version": "1",
            "tls_ciphers": ["TLS_AES_128_GCM_SHA256", "TLS_AES_256_GCM_SHA384"],
            "tls_grease": True,
            "tls_permute_extensions": True,
            "tls_extension_order": "10-13-27",
            "tls_supported_groups": ["X25519", "P-256"],
            "tls_signature_hashes": ["ecdsa_secp256r1_sha256", "rsa_pss_rsae_sha256"],
            "tls_cert_compression": ["brotli"],
            "headers": {"user-agent": "example"},
            "http2_settings": "1:65536;6:262144",
            "http2_pseudo_headers_order": "masp",
            "http3_settings": "1:65536;7:100;GREASE",
            "http3_pseudo_headers_order": "masp",
            "quic_transport_parameters": "12584:0x4f524947;15:AUTO;4:15728640;GREASE",
            "http3_headers": {"user-agent": "example-h3", "cookie": ""},
        },
    }


@pytest.fixture
def tls_capture():
    return {
        "record_version": "TLS_VERSION_1_0",
        "handshake_version": "TLS_VERSION_1_2",
        "session_id_length": 32,
        "comp_methods": [0],
        "ciphersuites": ["GREASE", 4865, 4866],
        "extensions": [
            {"type": "supported_groups", "length": 8, "supported_groups": ["GREASE", 29, 23]},
            {"type": "signature_algorithms", "length": 6, "sig_hash_algs": [1027, 2052]},
            {"type": "compress_certificate", "length": 3, "algorithms": [2]},
        ],
    }


def test_generated_protocols(profile):
    signature = generator.render_signature(profile, "example", 32)["signature"]
    assert "http2" in signature
    assert signature["tls_client_hello"] == {
        "partial": True,
        "ciphersuites": [4865, 4866],
        "extensions": [
            {"type": "supported_groups", "supported_groups": [29, 23]},
            {"type": "signature_algorithms", "sig_hash_algs": [1027, 2052]},
            {"type": "compress_certificate", "algorithms": [2]},
        ],
        "grease": True,
    }
    assert signature["http3"]["headers"] == {"user-agent": "example-h3"}
    assert signature["http3"]["settings"] == "1:65536;7:100;GREASE"


def test_partial_tls_matches_capture(profile, tls_capture):
    expected = generator.render_tls_signature(profile["fingerprint"])
    actual = TLSClientHelloSignature.from_dict(tls_capture)
    _assert_partial_tls_signature(actual, expected, False)
    # Unknown packet metadata must not be inferred from curl options.
    tls_capture["session_id_length"] = 0
    tls_capture["extensions"].reverse()
    actual = TLSClientHelloSignature.from_dict(tls_capture)
    _assert_partial_tls_signature(actual, expected, True)
    with pytest.raises(AssertionError):
        _assert_partial_tls_signature(actual, expected, False)


@pytest.mark.parametrize("field", ["ciphers", "groups", "signatures", "compression"])
def test_tls_mismatch_is_rejected(profile, tls_capture, field):
    if field == "ciphers":
        tls_capture["ciphersuites"].reverse()
    else:
        index, key = {"groups": (0, "supported_groups"),
                      "signatures": (1, "sig_hash_algs"),
                      "compression": (2, "algorithms")}[field]
        tls_capture["extensions"][index][key] = [999]
    with pytest.raises(AssertionError):
        _assert_partial_tls_signature(
            TLSClientHelloSignature.from_dict(tls_capture),
            generator.render_tls_signature(profile["fingerprint"]), True,
        )


@pytest.mark.parametrize("suffix", ["", "|20,8"])
@pytest.mark.parametrize("header_format", ["mapping", "list"])
def test_http3_normalization_and_mismatch(profile, suffix, header_format):
    expected = generator.render_http3_signature(profile["fingerprint"], 32)
    actual = {"http3": {
        "perk_text_normalized": "1:65536;7:100;GREASE|m,a,s,p|4:15728640;15:abcd;12584:4f524947;GREASE" + suffix,
        "headers": {"user-agent": "example-h3"},
    }}
    if header_format == "list":
        actual["http3"]["headers"] = [
            {"name": ":method", "value": "GET"},
            {"name": "user-agent", "value": "example-h3"},
        ]
    _assert_http3_signature(actual, expected)
    actual["http3"]["perk_text_normalized"] = actual["http3"]["perk_text_normalized"].replace("4:15728640", "4:1")
    with pytest.raises(AssertionError):
        _assert_http3_signature(actual, expected)


@pytest.mark.parametrize("header_format", ["mapping", "list"])
def test_http3_full_capture_checks_trailing_fields(header_format):
    fingerprint = "1:65536|m,a,s,p|15:AUTO|20,8"
    expected = {"perk_text_normalized": fingerprint, "headers": {"user-agent": "example"}}
    headers = ({"user-agent": "example"} if header_format == "mapping" else
               [{"name": "user-agent", "value": "example"}])
    actual = {"http3": {"perk_text_normalized": fingerprint, "headers": headers}}
    _assert_http3_signature(actual, expected)
    actual["http3"]["perk_text_normalized"] = fingerprint.replace("|20,8", "|8,8")
    with pytest.raises(AssertionError):
        _assert_http3_signature(actual, expected)


@pytest.mark.parametrize("headers", [
    {}, [], {"user-agent": "wrong"}, [{"name": "user-agent", "value": "wrong"}],
])
def test_http3_missing_or_wrong_header_is_rejected(profile, headers):
    expected = generator.render_http3_signature(profile["fingerprint"], 32)
    actual = {"http3": {
        "perk_text_normalized": "1:65536;7:100;GREASE|m,a,s,p|4:15728640;15:AUTO;12584:0x4f524947;GREASE|20,8",
        "headers": headers,
    }}
    with pytest.raises(AssertionError):
        _assert_http3_signature(actual, expected)


def test_captures_take_precedence(profile, tls_capture):
    captured = {"tls_client_hello": tls_capture, "http3": {"perk_text_normalized": "capture"}}
    profile["signature"] = copy.deepcopy(captured)
    signature = generator.render_signature(profile, "example", 32)["signature"]
    for key, value in captured.items():
        assert signature[key] == value


def test_no_http3_when_unavailable(profile):
    profile["fingerprint"]["http3_settings"] = ""
    signature = generator.render_signature(profile, "example", 32)["signature"]
    assert "http3" not in signature
    assert "tls_client_hello" in signature


def test_unknown_tls_value_is_rejected(profile):
    profile["fingerprint"]["tls_supported_groups"] = ["unknown"]
    with pytest.raises(ValueError, match="unsupported or missing tls_supported_groups"):
        generator.render_signature(profile, "example", 32)


def test_partial_tls_uses_capture_field_names(profile, tls_capture):
    expected = generator.render_tls_signature(profile["fingerprint"])
    actual = TLSClientHelloSignature.from_dict(tls_capture).to_dict()
    for extension in expected["extensions"]:
        captured = next(ext for ext in actual["extensions"] if ext["type"] == extension["type"])
        assert extension.keys() <= captured.keys()
    assert not {"record_version", "handshake_version", "session_id_length", "comp_methods"} & expected.keys()
    assert all("length" not in ext for ext in expected["extensions"])


def test_partial_tls_checks_explicit_capture_fields(profile, tls_capture):
    expected = generator.render_tls_signature(profile["fingerprint"])
    actual = TLSClientHelloSignature.from_dict(tls_capture)
    expected["session_id_length"] = 32
    expected["extensions"][0]["length"] = 8
    _assert_partial_tls_signature(actual, expected, True)
    expected["extensions"][0]["length"] = 10
    with pytest.raises(AssertionError, match="supported_groups.length"):
        _assert_partial_tls_signature(actual, expected, True)
    expected["extensions"][0]["length"] = 8
    expected["session_id_length"] = 0
    with pytest.raises(AssertionError, match="session_id_length"):
        _assert_partial_tls_signature(actual, expected, True)


@pytest.mark.parametrize("order,error", [
    ("", "tls_extension_order is required"),
    ("10-13-99999", "unsupported TLS extension ID"),
    ("10-13-27-27", "duplicate TLS extension"),
    ("10-13", "tls_cert_compression requires compress_certificate"),
])
def test_partial_tls_rejects_incomplete_extension_data(profile, order, error):
    profile["fingerprint"]["tls_extension_order"] = order
    with pytest.raises(ValueError, match=error):
        generator.render_tls_signature(profile["fingerprint"])


@pytest.mark.parametrize("prefix", ["", "profile,target\n", "\ufeffprofile,target\r\n"])
def test_csv_profiles(tmp_path, profile, prefix):
    path = tmp_path / "profiles.csv"
    path.write_text(prefix + '\n"example", alias_one\nexample,alias_two\n')
    assert generator.select_csv_profiles(path, [profile]) == [
        (profile, "alias_one"), (profile, "alias_two"),
    ]


@pytest.mark.parametrize("content,error", [
    ("profile,target\n", "no profile,target pairs"),
    ("missing,target\n", "unknown profile"),
    ("example,\n", "nonempty profile,target pair"),
    ("example,target,extra\n", "nonempty profile,target pair"),
    ("example,../escape\n", "invalid target name"),
    ("example,target\nexample,target\n", "duplicate target"),
])
def test_invalid_csv(tmp_path, profile, content, error):
    path = tmp_path / "profiles.csv"
    path.write_text(content)
    with pytest.raises(ValueError, match=error):
        generator.select_csv_profiles(path, [profile])


def test_csv_batch_cli(tmp_path, profile):
    profile["fingerprint"].update(http_version="v2", tls_version="1.2")
    second = copy.deepcopy(profile)
    second["name"] = "second"
    second["fingerprint"]["client_version"] = "2"
    source_json = tmp_path / "profiles.json"
    source_json.write_text(json.dumps([profile, second]))
    mapping = tmp_path / "profiles.csv"
    mapping.write_text("profile,target\nexample,zeta\nsecond,alpha\n")
    lib = tmp_path / "lib"
    lib.mkdir()
    (lib / "impersonate.h").write_text("#define IMPERSONATE_MAX_HEADERS 32\n")
    source = lib / "impersonate.c"
    source.write_text('const struct impersonate_opts impersonations[] = {\n'
                      '  {\n    .target = "alpha",\n    .alias = "old",\n  },\n'
                      '  {\n    .target = "keep",\n  }\n};\n')
    command = [
        sys.executable, generator.__file__, str(source_json), "--csv", str(mapping),
        "--curl-chrome-dir", str(tmp_path), "--wrapper-dir", str(tmp_path / "bin"),
        "--windows-wrapper-dir", str(tmp_path / "win"),
        "--signatures-dir", str(tmp_path / "signatures"),
        "--targets-file", str(tmp_path / "targets.yaml"),
    ]

    def snapshot():
        return {p: p.read_bytes() for p in tmp_path.rglob("*") if p.is_file()}

    before = snapshot()
    subprocess.run(command + ["--dry-run"], check=True, capture_output=True)
    assert snapshot() == before
    subprocess.run(command, check=True, capture_output=True)
    assert source.read_text().count('.target = "alpha"') == 1
    assert '.alias = "old"' not in source.read_text()
    assert source.read_text().index('"alpha"') < source.read_text().index('"keep"') < source.read_text().index('"zeta"')
    for target, version in (("alpha", "2"), ("zeta", "1")):
        assert (tmp_path / "bin" / f"curl_{target}").exists()
        assert (tmp_path / "win" / f"curl_{target}.bat").exists()
        signature = yaml.safe_load((tmp_path / "signatures" / f"{target}.yaml").read_text())
        assert signature["browser"]["target"] == target
        assert signature["browser"]["version"] == version
    assert len(yaml.safe_load((tmp_path / "targets.yaml").read_text())) == 4
    after = snapshot()
    subprocess.run(command, check=True, capture_output=True)
    assert snapshot() == after
    mapping.write_text("example,zeta\nmissing,alpha\n")
    before = snapshot()
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 1 and "unknown profile" in result.stderr
    assert snapshot() == before
