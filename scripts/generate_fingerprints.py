#!/usr/bin/env python3
"""Convert JSON fingerprints to curl wrappers, libcurl presets and tests.

Examples:
  python3 scripts/generate_fingerprints.py sample.json --dry-run
  python3 scripts/generate_fingerprints.py sample.json
  python3 scripts/generate_fingerprints.py sample.json \
      --profile chrome_150_macos_26.0 --target chrome150
  python3 scripts/generate_fingerprints.py --remove chrome150 --dry-run

Full profile names are used by default to preserve OS variants. Existing
presets with matching targets are replaced; other presets are preserved.
The complete impersonations array is sorted alphabetically by target.
Use --remove TARGET (repeatable) to remove presets and their generated
wrappers, target-named signatures and test registry entries without JSON input.
Patch export is left to the caller.
"""

import argparse
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
HTTP_VERSIONS = {
    "v1": "CURL_HTTP_VERSION_1_1",
    "v1.1": "CURL_HTTP_VERSION_1_1",
    "v2": "CURL_HTTP_VERSION_2_0",
    "v3": "CURL_HTTP_VERSION_3",
}
TLS_VERSIONS = {
    "1.0": "CURL_SSLVERSION_TLSv1_0",
    "1.1": "CURL_SSLVERSION_TLSv1_1",
    "1.2": "CURL_SSLVERSION_TLSv1_2",
    "1.3": "CURL_SSLVERSION_TLSv1_3",
}
# BoringSSL's OpenSSL names differ from the IANA names for pre-TLS 1.3.
CIPHERS = {
    "TLS_AES_128_GCM_SHA256": "TLS_AES_128_GCM_SHA256",
    "TLS_AES_256_GCM_SHA384": "TLS_AES_256_GCM_SHA384",
    "TLS_CHACHA20_POLY1305_SHA256": "TLS_CHACHA20_POLY1305_SHA256",
}
for _iana, _openssl in (
    ("RSA", ""), ("ECDHE_RSA", "ECDHE-RSA-"),
    ("ECDHE_ECDSA", "ECDHE-ECDSA-"),
):
    for _suite, _name in (
        ("AES_128_CBC_SHA", "AES128-SHA"),
        ("AES_256_CBC_SHA", "AES256-SHA"),
        ("AES_128_GCM_SHA256", "AES128-GCM-SHA256"),
        ("AES_256_GCM_SHA384", "AES256-GCM-SHA384"),
        ("3DES_EDE_CBC_SHA", "DES-CBC3-SHA"),
        ("CHACHA20_POLY1305_SHA256", "CHACHA20-POLY1305"),
    ):
        CIPHERS[f"TLS_{_iana}_WITH_{_suite}"] = _openssl + _name


def c_string(value):
    """Quote UTF-8 text for C, including control characters safely."""
    result = '"'
    for byte in value.encode("utf-8"):
        if byte in (34, 92):
            result += "\\" + chr(byte)
        elif 32 <= byte < 127:
            result += chr(byte)
        else:
            result += f"\\{byte:03o}"
    return result + '"'


def headers(values, order, limit):
    values = {key.lower(): value for key, value in values.items()}
    names = list(dict.fromkeys(
        [key.strip().lower() for key in (order or "").split(",") if key.strip()]
        + list(values)
    ))
    # An empty cookie in the capture is a placeholder, not a default header.
    result = [f"{key}: {values[key]}" for key in names
              if key in values and not (key == "cookie" and values[key] == "")]
    if len(result) > limit:
        raise ValueError(f"too many headers ({len(result)} > {limit})")
    return result


def render_preset(profile, target, limit):
    fp = profile["fingerprint"]
    fields = {"target": target, "alias": target}
    lines = ["  {"]

    def emit(key, value):
        if isinstance(value, list):
            lines.append(f"    .{key} = {{")
            lines.extend(f"      {c_string(item)}," for item in value)
            lines.append("    },")
        else:
            literal = ("NULL" if value is None else
                       str(value).lower() if isinstance(value, (bool, int)) else
                       c_string(value))
            lines.append(f"    .{key} = {literal},")

    try:
        http = HTTP_VERSIONS[fp["http_version"]]
        tls = TLS_VERSIONS[fp["tls_version"]]
        fields["ciphers"] = ":".join(CIPHERS[x] for x in fp["tls_ciphers"])
    except KeyError as exc:
        raise ValueError(f"unsupported or missing version/cipher: {exc}") from exc
    for key, value in fields.items():
        emit(key, value)
    lines.extend([
        f"    .httpversion = {http},",
        f"    .ssl_version = {tls} | CURL_SSLVERSION_MAX_DEFAULT,",
    ])
    for source, dest, separator in (
        ("tls_supported_groups", "curves", ":"),
        ("http3_tls_supported_groups", "http3_curves", ":"),
        ("tls_signature_hashes", "sig_hash_algs", ":"),
        ("http3_tls_signature_hashes", "http3_sig_hash_algs", ":"),
        ("tls_cert_compression", "cert_compression", ","),
        ("tls_delegated_credentials", "tls_delegated_credentials", ":"),
        ("tls_trust_anchors", "tls_trust_anchors", ","),
    ):
        if source in fp:
            emit(dest, separator.join(fp[source]) or None)
    for source, dest in (
        ("tls_alpn", "alpn"), ("tls_alps", "alps"),
        ("tls_ech", "ech"), ("header_order", "http_header_order"),
        ("http3_header_order", "http3_http_header_order"),
    ):
        if source in fp:
            value = fp[source]
            if source == "tls_ech":
                value = value or None
            emit(dest, value)
    for key in (
        "tls_session_ticket", "tls_permute_extensions", "tls_grease",
        "tls_use_new_alps_codepoint", "tls_signed_cert_timestamps",
        "tls_record_size_limit", "tls_key_shares_limit", "tls_extension_order",
        "http2_settings", "http2_window_update", "http2_pseudo_headers_order",
        "http2_no_priority", "http3_settings", "http3_pseudo_headers_order",
        "http3_tls_extension_order", "quic_transport_parameters",
        "split_cookies", "form_boundary",
    ):
        if key in fp:
            value = fp[key]
            if key in ("tls_record_size_limit", "tls_key_shares_limit"):
                value = value or 0
            # A captured random order must not override extension permutation.
            if key == "tls_extension_order" and fp.get("tls_permute_extensions"):
                value = None
            emit(key, value)
    for suffix in ("weight", "exclusive"):
        key = f"http2_stream_{suffix}"
        value = fp.get(key)
        if value is None:
            value = fp.get(f"http2_priority_{suffix}")
        emit(key, value if value is not None else 0)
    emit("http_headers", headers(fp.get("headers", {}), fp.get("header_order"), limit))
    if "http3_headers" in fp:
        emit("http3_headers", headers(fp["http3_headers"], fp.get("http3_header_order"), limit))
    lines.append("  }")
    return "\n".join(lines)


def update_presets(source, presets, remove=()):
    """Merge selected presets and sort all entries lexically by target."""
    marker = "const struct impersonate_opts impersonations[] = {"
    start = source.index(marker) + len(marker)
    end = source.index("\n};", start)
    body = source[start:end]
    # Entries and their closing braces use two spaces; nested header arrays
    # use four. Anchoring to those lines avoids braces in header values.
    entries = list(re.finditer(r"^  \{\n.*?^  \},?", body, re.M | re.S))
    if not entries and body.strip():
        raise ValueError("cannot locate existing impersonation entries")
    merged = {}
    cursor = 0
    for match in entries:
        if body[cursor:match.start()].strip():
            raise ValueError("unexpected content between impersonation entries")
        target = re.search(r'\.target\s*=\s*"([^"\\]+)"', match[0])
        if not target:
            raise ValueError("impersonation entry has no readable target")
        if target[1] in merged:
            raise ValueError(f"duplicate existing target: {target[1]}")
        merged[target[1]] = match[0].rstrip(",")
        cursor = match.end()
    if body[cursor:].strip():
        raise ValueError("unexpected content after impersonation entries")
    merged.update(presets)
    for target in remove:
        merged.pop(target, None)
    body = "\n" + ",\n".join(merged[target] for target in sorted(merged)) + "\n"
    return source[:start] + body + source[end:]


def render_signature(profile, target, limit):
    """Use observed HTTP/2 fields; do not invent uncaptured TLS details."""
    fp = profile["fingerprint"]
    pseudo_names = {"m": ":method", "a": ":authority", "s": ":scheme", "p": ":path"}
    order = fp["http2_pseudo_headers_order"]
    if sorted(order) != sorted(pseudo_names):
        raise ValueError(f"invalid HTTP/2 pseudo-header order: {order!r}")
    settings = []
    for item in (fp.get("http2_settings") or "").split(";"):
        if item:
            key, value = item.split(":")
            settings.append({"key": int(key), "value": int(value)})
    frames = [{"frame_type": "SETTINGS", "settings": settings, "stream_id": 0}]
    if fp.get("http2_window_update"):
        frames.append({"frame_type": "WINDOW_UPDATE", "stream_id": 0,
                       "window_size_increment": fp["http2_window_update"]})
    frames.append({
        "frame_type": "HEADERS", "stream_id": 1,
        "headers": headers(fp.get("headers", {}), fp.get("header_order"), limit),
        "pseudo_headers": [pseudo_names[key] for key in order],
    })
    signature = {
        "options": {"tls_permute_extensions": fp.get("tls_permute_extensions", False)},
        "http2": {"frames": frames},
    }
    # Complete captures may accompany the profile. Preserve them verbatim;
    # TLS lengths, record versions and session IDs cannot be recovered from
    # option lists. HTTP/3 tests likewise need a normalized captured signature.
    captured = profile.get("signature", {})
    for key in ("tls_client_hello", "http3"):
        if key in captured:
            signature[key] = captured[key]
    return {
        "browser": {
            "name": profile.get("client", fp["client"]),
            "version": str(profile.get("version", fp["client_version"])),
            # Include OS version to keep the test database's browser keys unique.
            "os": f"{profile.get('os', fp['os'])}_{profile.get('os_version', fp['os_version'])}",
            "target": target,
        },
        "signature": signature,
    }


def update_test_targets(rows, targets, remove=()):
    """Replace selected wrapper/libcurl rows, preserving unrelated tests."""
    selected = set(targets) | set(remove)
    wrappers = {f"curl_{target}" for target in selected}
    result = []
    for row in rows:
        if not isinstance(row, list) or len(row) != 4:
            raise ValueError("test targets must be a list of four-element rows")
        binary, env, library, expected = row
        if binary in wrappers:
            continue
        if binary == "minicurl" and (env or {}).get("CURL_IMPERSONATE") in selected:
            continue
        result.append(row)
    for target in targets:
        result.append([f"curl_{target}", None, None, target])
        result.append(["minicurl", {"CURL_IMPERSONATE": target}, "libcurl-impersonate", target])
    return result


def remove_fingerprints(args, yaml):
    """Remove exact target names and their generated artifacts; missing is OK."""
    targets = sorted(set(args.remove))
    for target in targets:
        if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", target):
            raise ValueError(f"invalid target name: {target!r}")
    path = args.curl_chrome_dir / "lib/impersonate.c"
    updated = update_presets(path.read_text(), {}, remove=targets)
    targets_text = None
    if args.targets_file.exists():
        text = args.targets_file.read_text()
        json_targets = args.targets_file.suffix.lower() == ".json"
        rows = json.loads(text) if json_targets else yaml.safe_load(text)
        rows = update_test_targets(rows, (), remove=targets)
        targets_text = (json.dumps(rows, indent=2) + "\n" if json_targets else
                        yaml.safe_dump(rows, sort_keys=False))
    artifacts = [
        artifact
        for target in targets
        for artifact in (
            args.wrapper_dir / f"curl_{target}",
            args.windows_wrapper_dir / f"curl_{target}.bat",
            args.signatures_dir / f"{target}.yaml",
        )
    ]
    if args.dry_run:
        print(f"Would remove targets from {path}: {', '.join(targets)}")
        for artifact in artifacts:
            if artifact.exists() or artifact.is_symlink():
                print(f"Would delete {artifact}")
        if targets_text is not None:
            print(f"\n# {args.targets_file}\n{targets_text}")
        return
    path.write_text(updated)
    for artifact in artifacts:
        artifact.unlink(missing_ok=True)
    if targets_text is not None:
        args.targets_file.write_text(targets_text)
    print(f"Removed targets from {path} and their generated artifacts: "
          f"{', '.join(targets)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("profile_file", nargs="?", type=Path, default=ROOT / "sample.json")
    parser.add_argument("--profile", action="append", help="select a profile name (repeatable)")
    parser.add_argument("--list", action="store_true", help="list available profile names without writing files")
    parser.add_argument("--target", help="override target name; requires exactly one profile")
    parser.add_argument("--remove", action="append", metavar="TARGET",
                        help="remove a target and its generated artifacts (repeatable; no JSON input needed)")
    parser.add_argument("--curl-chrome-dir", type=Path, default=ROOT.parent / "curl-chrome")
    parser.add_argument("--wrapper-dir", type=Path, default=ROOT / "bin")
    parser.add_argument("--windows-wrapper-dir", type=Path, default=ROOT / "win/bin")
    parser.add_argument("--signatures-dir", type=Path, default=ROOT / "tests/signatures")
    parser.add_argument("--targets-file", type=Path, default=ROOT / "tests/targets.yaml",
                        help="test registry to update (.yaml or .json)")
    parser.add_argument("--dry-run", action="store_true", help="preview generation or removal without changing files")
    args = parser.parse_args()
    if args.remove and (args.profile or args.target or args.list):
        parser.error("--remove cannot be combined with --profile, --target or --list")
    try:
        if args.remove:
            try:
                import yaml
            except ImportError as exc:
                raise ValueError("PyYAML is required: python3 -m pip install pyyaml") from exc
            remove_fingerprints(args, yaml)
            return
        data = json.loads(args.profile_file.read_text())
        profiles = data.get("data", [data]) if isinstance(data, dict) else data
        if args.list:
            print("\n".join(p["name"] for p in profiles))
            return
        if args.profile:
            missing = set(args.profile) - {p["name"] for p in profiles}
            if missing:
                raise ValueError(f"unknown profiles: {', '.join(sorted(missing))}")
            profiles = [p for p in profiles if p["name"] in args.profile]
        if not profiles:
            raise ValueError("no profiles selected")
        if args.target and len(profiles) != 1:
            raise ValueError("--target requires exactly one selected profile")
        try:
            import yaml
        except ImportError as exc:
            raise ValueError("PyYAML is required: python3 -m pip install pyyaml") from exc
        header = (args.curl_chrome_dir / "lib/impersonate.h").read_text()
        limit = int(re.search(r"#define IMPERSONATE_MAX_HEADERS\s+(\d+)", header)[1])
        presets = {}
        signatures = {}
        for profile in profiles:
            target = args.target or profile["name"]
            if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*", target):
                raise ValueError(f"invalid target name: {target!r}")
            if target in presets:
                raise ValueError(f"duplicate target: {target}")
            presets[target] = render_preset(profile, target, limit)
            signatures[target] = yaml.safe_dump(render_signature(profile, target, limit), sort_keys=False)
        path = args.curl_chrome_dir / "lib/impersonate.c"
        updated = update_presets(path.read_text(), presets)
        json_targets = args.targets_file.suffix.lower() == ".json"
        if args.targets_file.exists():
            text = args.targets_file.read_text()
            rows = json.loads(text) if json_targets else yaml.safe_load(text)
        else:
            rows = []
        rows = update_test_targets(rows, presets)
        targets_text = (json.dumps(rows, indent=2) + "\n" if json_targets else
                        yaml.safe_dump(rows, sort_keys=False))
        if args.dry_run:
            print(",\n".join(presets.values()))
            for target, text in signatures.items():
                print(f"\n# {args.signatures_dir / (target + '.yaml')}\n{text}")
            print(f"\n# {args.targets_file}\n{targets_text}")
            return
        path.write_text(updated)
        args.wrapper_dir.mkdir(parents=True, exist_ok=True)
        args.windows_wrapper_dir.mkdir(parents=True, exist_ok=True)
        args.signatures_dir.mkdir(parents=True, exist_ok=True)
        args.targets_file.parent.mkdir(parents=True, exist_ok=True)
        for target in presets:
            wrapper = args.wrapper_dir / f"curl_{target}"
            wrapper.write_text(
                '#!/usr/bin/env bash\n\n# Find the directory of this script\n'
                'dir=${0%/*}\n\n'
                f'"$dir/curl-impersonate" --compressed --impersonate "{target}" "$@"\n'
            )
            wrapper.chmod(wrapper.stat().st_mode | 0o111)
            (args.windows_wrapper_dir / f"curl_{target}.bat").write_text(
                '@echo off\n'
                f'"%~dp0curl-impersonate.exe" --compressed --impersonate "{target}" %*\n'
            )
            (args.signatures_dir / f"{target}.yaml").write_text(signatures[target])
        args.targets_file.write_text(targets_text)
        print(f"Generated {len(presets)} presets in {path} and wrappers in "
              f"{args.wrapper_dir} and {args.windows_wrapper_dir}; "
              f"signatures in {args.signatures_dir}; updated {args.targets_file}")
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        parser.exit(1, f"error: {exc}\n")


if __name__ == "__main__":
    main()
