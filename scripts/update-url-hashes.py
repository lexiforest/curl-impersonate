#!/usr/bin/env python3
"""Download each *_URL in CMakeLists.txt and update its *_URL_HASH with the SHA256."""

import hashlib
import re
import urllib.request
from pathlib import Path

CMAKE_FILE = Path(__file__).resolve().parents[1] / "CMakeLists.txt"


def main() -> None:
    text = CMAKE_FILE.read_text()
    variables = dict(re.findall(r'set\(\s*(\w+)\s+"([^"]*)"', text))

    def expand(value: str) -> str:
        return re.sub(r"\$\{(\w+)\}", lambda m: expand(variables[m.group(1)]), value)

    for name, value in variables.items():
        if not name.endswith("_URL"):
            continue
        hash_var = f"{name}_HASH"
        if hash_var not in variables:
            continue

        url = expand(value)
        digest = hashlib.sha256()
        with urllib.request.urlopen(url) as response:
            for chunk in iter(lambda: response.read(1 << 20), b""):
                digest.update(chunk)
        new_hash = f"SHA256={digest.hexdigest()}"

        print(f"{hash_var} = {new_hash} ({url})")
        text = re.sub(
            rf'(set\(\s*{hash_var}\s+)"[^"]*"',
            rf'\1"{new_hash}"',
            text,
        )

    CMAKE_FILE.write_text(text)


if __name__ == "__main__":
    main()
