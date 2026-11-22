#!/usr/bin/env python3
"""Check every gpkg binpkg in each PKGDIR the way emerge checks a binhost's
packages with FEATURES=binpkg-request-signature: each one must carry a good
signature from a key trusted in BINPKG_GPG_VERIFY_GPG_HOME.  Also check that
Packages and Packages.gz list exactly those files with their current size and
mtime, since clients reject a download that doesn't match the index.

usage: pentoo_verify_binpkgs.py PKGDIR...
"""

import gzip
import os
import sys
from concurrent.futures import ProcessPoolExecutor

os.environ["FEATURES"] = (
    os.environ.get("FEATURES", "")
    + " -binpkg-ignore-signature binpkg-request-signature"
)

import portage
from portage import gpkg

portage._internal_caller = True


def verify_package(path):
    try:
        gpkg.gpkg(portage.settings, gpkg_file=path)._verify_binpkg()
    except Exception as e:
        return f"{path}: {type(e).__name__}: {e}"
    return None


def check_index(pkgdir, packages):
    index = os.path.join(pkgdir, "Packages")
    try:
        with open(index, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        return [f"{index}: missing"]
    errors = []
    if os.path.exists(index + ".gz"):
        with gzip.open(index + ".gz") as f:
            if f.read() != data:
                errors.append(f"{index}.gz: differs from {index}")

    indexed = set()
    for stanza in data.decode("utf-8").split("\n\n")[1:]:
        entry = dict(
            line.split(": ", 1) for line in stanza.splitlines() if ": " in line
        )
        if "CPV" not in entry:
            continue
        if "PATH" not in entry:
            errors.append(f"{index}: {entry['CPV']} has no PATH")
            continue
        path = os.path.join(pkgdir, entry["PATH"])
        indexed.add(path)
        try:
            st = os.stat(path)
        except FileNotFoundError:
            errors.append(f"{index}: lists missing {path}")
            continue
        if entry.get("SIZE") != str(st.st_size) or entry.get("MTIME") != str(
            int(st.st_mtime)
        ):
            errors.append(f"{index}: stale SIZE or MTIME for {path}")
    for path in sorted(set(packages) - indexed):
        errors.append(f"{index}: does not list {path}")
    return errors


def main(pkgdirs):
    errors = []
    packages = {}
    for pkgdir in pkgdirs:
        if not os.path.isdir(pkgdir):
            errors.append(f"{pkgdir}: not a directory")
            continue
        packages[pkgdir] = sorted(
            os.path.join(root, name)
            for root, _, names in os.walk(pkgdir)
            for name in names
            if name.endswith(".gpkg.tar")
        )
        errors.extend(check_index(pkgdir, packages[pkgdir]))

    paths = [p for ps in packages.values() for p in ps]
    with ProcessPoolExecutor() as pool:
        errors.extend(e for e in pool.map(verify_package, paths) if e)

    for e in errors:
        print(f"FAIL {e}", file=sys.stderr)
    print(f"{len(paths)} binpkgs checked, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__.rsplit("\n\n", 1)[-1].strip())
    sys.exit(main(sys.argv[1:]))
