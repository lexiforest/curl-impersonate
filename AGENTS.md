# Repository Guidelines

## Project Structure & Module Organization
This repository is a CMake superbuild for `curl-impersonate`, not a typical app codebase.


- `CMakeLists.txt`: orchestrates dependency download/patch/build/install via `ExternalProject_Add`.
- `patches/`: patchsets applied to upstream deps (`curl.patch`, `boringssl.patch`, `ngtcp2.patch`, `nghttp3.patch`, etc.).
- `bin/` and `win/bin/`: wrapper launch scripts for impersonation profiles.
- `tests/`: signature-based integration tests (`pytest`), fixtures, and browser signature YAML files.
- `.github/workflows/`: CI for Linux/macOS/Windows builds and tests.
- `docker/`: Docker build definitions used for reproducible builds/distribution.

**important**

Don't update the patches directly, prompt the user to update the patches.

## Build, Test, and Development Commands
- `make configure`: generate CMake build files in `build/` (honors `CMAKE_CONFIGURE_ARGS`).
- `make build`: build all external dependencies and `curl-impersonate`.
- `make checkbuild`: verify expected features in the built binary (`zlib`, `zstd`, `brotli`, `nghttp2`, `BoringSSL`, `AppleIDN/libidn2`).
- `make install` or `make install-strip`: install artifacts (and optionally strip binaries).
- `make target TARGET=<name>`: build a single target (example: `TARGET=libidn2`).
- Tests:
  - `docker build -t curl-impersonate-tests tests/`
  - `docker run --rm curl-impersonate-tests`
  - Or local CI-like run: `cd tests && pytest . --install-dir <install-prefix> --capture-interface <iface>`

## Coding Style & Naming Conventions
- Keep changes minimal and dependency-focused; prefer editing build wiring/patches over ad hoc scripts.
- Match existing formatting: 2-space indentation in CMake/YAML; follow existing style in patched upstream code.
- Patch file names should map to dependency names (for example `patches/nghttp3.patch`).
- Signature files use `<browser>_<version>_<platform>.yaml` (example: `chrome_136.0.7103.93.yaml`).

## Testing Guidelines
- Primary validation is integration-level: build + network-signature tests.
- For build-only changes, run at least `make build` and `make checkbuild`.
- For fingerprint/behavior changes, run `tests/test_impersonate.py` path (Docker preferred for reproducibility).

## Commit & Pull Request Guidelines
- Commit subjects in history are short, imperative, and scoped (for example `Fix windows and docker build`, `Add support for http3 fingerprints (#217)`).
- Prefer one logical change per commit.
- PRs should include:
  - What changed and why.
  - Affected platforms/targets.
  - Exact verification commands run and key output.
  - Linked issue(s) when applicable.
