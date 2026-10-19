"""Compile and run POSIX consumers using only installed development metadata."""

import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


SOURCE = r"""
#include <curl/curl.h>
#include <string.h>

int main(void)
{
    CURL *curl;
    CURLcode result = curl_global_init(CURL_GLOBAL_DEFAULT);
    if(result != CURLE_OK)
        return (int)result;
    if(!strstr(LIBCURL_VERSION, "IMPERSONATE") ||
       !strstr(curl_version(), "IMPERSONATE"))
        return 1;
    curl = curl_easy_init();
    if(!curl)
        return 1;
    result = curl_easy_impersonate(curl, "chrome150", 0);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return (int)result;
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefix", required=True, type=Path)
    parser.add_argument("--libdir", default="lib")
    parser.add_argument("--bindir", default="bin")
    args = parser.parse_args()
    prefix = args.prefix.resolve()
    libdir = prefix / args.libdir
    config = prefix / args.bindir / "curl-impersonate-config"
    env = dict(os.environ)
    # Neither developer-installed .pc files nor a build-tree library may mask
    # missing dependencies in the installed package.
    env.update(
        PKG_CONFIG_PATH="",
        PKG_CONFIG_LIBDIR=str(libdir / "pkgconfig"),
        PKG_CONFIG_SYSROOT_DIR="",
        CPATH="",
        C_INCLUDE_PATH="",
        LIBRARY_PATH="",
        LD_LIBRARY_PATH=str(libdir),
        DYLD_LIBRARY_PATH=str(libdir),
    )
    compiler = shlex.split(os.environ.get("CC", "cc"))
    pkg_config = shlex.split(os.environ.get("PKG_CONFIG", "pkg-config"))

    with tempfile.TemporaryDirectory(prefix="curl-install-check-") as temporary:
        work = Path(temporary)
        source = work / "consumer.c"
        source.write_text(SOURCE)
        for interface in ("pkg-config", "curl-impersonate-config"):
            for static in (False, True):
                if interface == "pkg-config":
                    command = pkg_config + ["--cflags", "--libs"]
                    if static:
                        command.append("--static")
                    command.append("libcurl-impersonate")
                else:
                    command = [str(config), "--cflags",
                               "--static-libs" if static else "--libs"]
                flags = shlex.split(subprocess.check_output(
                    command, env=env, text=True))
                for flag in flags:
                    if flag.startswith(("-I", "-L")):
                        path = Path(flag[2:]).resolve()
                    elif Path(flag).is_absolute():
                        path = Path(flag).resolve()
                    else:
                        continue
                    if not path.is_relative_to(prefix) or not path.exists():
                        raise RuntimeError(f"Invalid installed path: {flag}")
                if static:
                    # pkg-config --static adds dependencies but still allows
                    # the linker to prefer a shared libcurl. Force the archive.
                    flags = [str(libdir / "libcurl-impersonate.a")
                             if flag == "-lcurl-impersonate" else flag
                             for flag in flags]
                program = work / "consumer"
                subprocess.run(compiler + [str(source), "-o", str(program)] + flags,
                               env=env, check=True)
                subprocess.run([str(program)], env=env, check=True)
                mode = "static" if static else "shared"
                print(f"{interface}: {mode} consumer passed", flush=True)


if __name__ == "__main__":
    main()
