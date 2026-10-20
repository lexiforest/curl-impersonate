Development and contributing
****************************

When opening a pull request, do not use the ``main`` branch in your fork. Use a separate
branch such as ``feature/xxx`` or ``bugfix/xxx`` so follow-up changes and tests can be
added more easily.

See also the AI policy in curl_cffi: https://github.com/lexiforest/curl_cffi#contributing

Generating fingerprint profiles
===============================

``scripts/generate_fingerprints.py`` converts JSON fingerprint profiles into
libcurl presets, wrapper scripts, and test expectations. Run it from the
curl-impersonate repository root. It requires Python 3 and PyYAML, plus a
checkout of ``curl-chrome`` at ``../curl-chrome`` by default:

.. code-block:: sh

   python3 -m pip install pyyaml
   python3 scripts/generate_fingerprints.py
   python3 scripts/generate_fingerprints.py profiles.json --list

Invoking the script without arguments prints help and changes no files.
``--list`` lists the names in the input JSON without writing files.
``profiles.json`` in these examples is your input file; it is not bundled with
the repository.

Input format
------------

The input can be a single profile object, an array of profiles, or an object
with a ``data`` array of profiles. Each profile has a ``name`` and a
``fingerprint`` object containing the protocol options and browser metadata.
The fingerprint includes fields such as ``client``, ``client_version``,
``os``, ``os_version``, ``http_version``, ``tls_version``, ``tls_ciphers``,
``http2_settings``, ``http2_pseudo_headers_order``, and ``headers``. Optional
fields describe TLS extensions, header ordering, HTTP/3, and QUIC.

The generator consumes structured fingerprint options, not packet captures.
A profile may additionally supply ``signature.tls_client_hello`` or
``signature.http3`` to preserve explicit signature captures.

Generate or replace targets
---------------------------

Preview one profile and give it a shorter target name:

.. code-block:: sh

   python3 scripts/generate_fingerprints.py profiles.json \
       --profile chrome_152_windows_10 --target chrome152 --dry-run

Remove ``--dry-run`` to write the results. Without ``--profile``, every profile
in the JSON is selected. ``--profile`` can be repeated; ``--target`` requires
exactly one selected profile. Without ``--target``, each full profile name
becomes its target name, preserving OS variants.

For a batch with custom target names, create ``profiles.csv``:

.. code-block:: text

   profile,target
   chrome_152_windows_10,chrome152
   chrome_152_macos_26.0,chrome152_macos
   safari_27.0_ios_27.0,safari270_ios

.. code-block:: sh

   python3 scripts/generate_fingerprints.py profiles.json \
       --csv profiles.csv --dry-run
   python3 scripts/generate_fingerprints.py profiles.json --csv profiles.csv

The ``profile,target`` header is optional. Each profile must exist in the JSON,
and each target in the CSV must be unique. ``--csv`` cannot be combined with
``--profile``, ``--target``, ``--list``, or ``--remove``.

Generation updates:

* ``../curl-chrome/lib/impersonate.c``: replace matching targets, preserve other
  presets, and sort the complete array alphabetically by target.
* ``bin/curl_<target>`` and ``win/bin/curl_<target>.bat``: write wrappers.
  POSIX wrappers use ``#!/bin/sh`` and ``exec``.
* ``tests/signatures/<target>.yaml``: write signature expectations.
* ``tests/targets.yaml``: replace the selected targets' wrapper and libcurl
  test registrations.

Running the same command again replaces these generated files and entries;
it does not append duplicate presets. Manual edits to a selected target's
generated artifacts are overwritten.

Use ``--curl-chrome-dir``, ``--wrapper-dir``, ``--windows-wrapper-dir``,
``--signatures-dir``, and ``--targets-file`` to change the default paths.

Remove targets
--------------

Removal does not require a JSON input:

.. code-block:: sh

   python3 scripts/generate_fingerprints.py --remove chrome152 --dry-run
   python3 scripts/generate_fingerprints.py \
       --remove chrome152 --remove chrome152_macos

``--remove`` deletes the exact target from ``impersonate.c``, both wrappers,
its target-named signature YAML, and its test registrations. Missing targets
are harmless. Signature files under other names are not deleted.

Signature coverage and validation
---------------------------------

Generated YAML includes HTTP/2 expectations and, when available, HTTP/3
settings, pseudo-header order, QUIC transport parameters, and headers.
Generated TLS expectations use ``partial: true`` and check only the known
ciphers and extension fields. Packet lengths, record versions, and session ID
lengths cannot be inferred from option lists. Explicit TLS and HTTP/3 captures
in the input take precedence over generated expectations.

The comparison helpers in ``tests/test_impersonate.py`` handle partial TLS and
HTTP/3 expectations. See ``tests/README.md`` for integration test setup. With
the test dependencies installed, run the generator's offline regressions with:

.. code-block:: sh

   cd tests
   python3 -m pytest test_generate_fingerprints.py -q

Patch export is a separate step
-------------------------------

The generator changes the source checkout, but does not update
``patches/curl.patch``. After reviewing the generated changes, export the patch
from ``curl-chrome``:

.. code-block:: sh

   cd ../curl-chrome
   ./export.sh

The superbuild consumes the exported patch. An existing dependency source tree
does not automatically reapply a changed patch; use a clean build when checking
updated presets, then run the signature tests against that build.
