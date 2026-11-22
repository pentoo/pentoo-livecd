# Pentoo Penetration Testing LiveCD
stuff to generate the pentoo livecd
<a href="http://pentoo.ch"><img src="https://github.com/pentoo/pentoo-overlay/wiki/images/pentoo2.png"></a>

<a href="http://pentoo.ch"><img src="https://avatars0.githubusercontent.com/u/6411603?v=3&s=200" align="left" hspace="10" vspace="6"></a>
Pentoo is a Live CD and Live USB designed for penetration testing and security assessment. Based on Gentoo Linux, Pentoo is provided both as 32 and 64 bit installable livecd. Pentoo is also available as an overlay for an existing Gentoo installation. It features packet injection patched wifi drivers, GPGPU cracking software, and lots of tools for penetration testing and security assessment. The Pentoo kernel includes grsecurity and PAX hardening and extra patches - with binaries compiled from a hardened toolchain with the latest nightly versions of some tools available. The latest release of the Pentoo Livecd is available [here](http://www.pentoo.ch/download/).

Pentoo comes in many flavors and utilizes catalyst as a build tool. [Catalyst](https://wiki.gentoo.org/wiki/Catalyst) is a release building tool, used by Gentoo Linux. With catalyst users are able to completely customize a Gentoo install by customizing the very tools that are used to install a system. Official Gentoo Linux release media is built using Catalyst.

Want to learn more? [See the wiki.](https://wiki.gentoo.org/wiki/Catalyst)

Discussion and support available on irc.freenode.net  **#pentoo**

## Checking stage dependencies without building

`livecd/tools/bootstrap-resolve.sh` pretend-runs the stage1 seed update or the
stage3 `@system` emerge the way catalyst does, with the bootstrap profile and
`livecd/portage`, so dependency problems in those stages show up before the
nightly build. It needs no root: emerge runs in a private user and mount
namespace, and the vdb and binpkgs it is given are mounted read-only.

```
# against a pentoo overlay checkout, no binpkgs, empty vdb
livecd/tools/bootstrap-resolve.sh -o ~/pentoo-overlay stage3

# on the build host, with the real pkgcache and the stage2 seed's vdb
mkdir /tmp/stage2 && tar --zstd -xf /catalyst/builds/hardened/stage2-amd64-2026.0.tar.zstd -C /tmp/stage2 --wildcards '*var/db/pkg/*'
livecd/tools/bootstrap-resolve.sh -p /catalyst/packages/amd64_23.0s-hardened-bootstrap -v /tmp/stage2/var/db/pkg stage3
```

With an empty vdb, stage3 ends in circular dependencies that the stage2 seed
does not have; anything before the merge list is a real problem.

## Signing binpkgs

The pkgcache catalyst builds into stays unsigned, since the stages would
reject signed packages from a key they don't trust. `mirror_sync` and
`pentoo_binpkgs.sh` sign the copy they rsync to the mirror with
`livecd/automation/pentoo_sign_binpkgs.sh`. It does three things:

- signs every unsigned gpkg with `gpkg-sign`
- refreshes `Packages`/`Packages.gz` with `emaint binhost --fix`
- checks every package with `pentoo_verify_binpkgs.py`, the same way emerge
  does with `FEATURES=binpkg-request-signature`, and checks that the index
  matches the files

If any step fails, the run fails and `pentoo_binpkgs.sh` doesn't run
`mirror.sh`. The user PIN file `/root/.gnupg-binpkg-signing/pin` is the
switch: signing is off until it exists, and removing it turns signing off
again. Only create it once clients trust the key in `/etc/portage/gnupg`:
emerge refuses signed binpkgs from an unknown key.

The key is NIST P-384 (ECDSA), generated on a YubiKey, and expires in 900
days, the GLEP 63 maximum. GLEP 63 itself only allows RSA or curve 25519 for
Gentoo developer keys, but nothing in Portage enforces that, and P-384 is
both stronger than either and much faster on the card. To generate it, plug in only that YubiKey and run:

```
livecd/tools/binpkg-key-yubikey.sh SERIAL ~/pentoo-binpkg-key
```

This wipes the card's OpenPGP keys. It works in a throwaway GnuPG home, so
`~/.gnupg` is never touched. It writes the public key, the revocation
certificate (keep it offline) and the fingerprint. Before the key expires,
extend it with the card and its Admin PIN, and give clients the new expiry.

On the build host, as root, with the YubiKey plugged in and pcscd running:

```
livecd/automation/pentoo_sign_binpkgs.sh --init FINGERPRINT.asc
```

To turn signing on, write the PIN file: run this, type the user PIN, press
Enter, then Ctrl-D:

```
(umask 077; cat > /root/.gnupg-binpkg-signing/pin)
```

Then check it and sign the mirror once by hand. The first pass over a full
binpkg dir can take an hour or more:

```
livecd/automation/pentoo_sign_binpkgs.sh --test-pin
livecd/automation/pentoo_sign_binpkgs.sh /mnt/mirror/local_mirror/Packages/amd64_23.0s-hardened
```

A wrong PIN file costs one PIN try per run. The script won't use the file
while the card shows fewer than 3 tries left, so a wrong file can't block
the PIN. After fixing the file, `--test-pin` tries it once on purpose, which
resets the counter when the PIN is right.

Before clients start enforcing signatures (pentoo-updater writing
`verify-signature = true` for the Pentoo binhosts), confirm that every public
mirror serves the signed packages. Signing changes a gpkg's size and mtime, so
`livecd/tools/check-mirror-signed.sh` compares each mirror's `Packages` and
`Packages.gz` with the local, already verified index and reports stale,
missing and extra entries. It exits non-zero unless every mirror and dir
matches. With no arguments it checks every dir under
`/mnt/mirror/local_mirror/Packages` on the three public mirrors:

```
livecd/tools/check-mirror-signed.sh
livecd/tools/check-mirror-signed.sh -m https://pentoo.osuosl.org/Packages/ amd64_23.0s-hardened
```

## Tests

`livecd/tools/test-catalyst-clean.sh` checks that `catalyst_clean` in
`livecd/automation/pentoo_functions.sh` removes only the tmp dir of the stage
it runs for, since several stages can build at the same time. It needs no root
and runs on tmpfs, so it is safe on the build host too.

`livecd/tools/test-mirror-sync.sh` checks what the automation publishes to the
mirror, and that synced binpkgs go through the signer before `mirror.sh` runs.

`livecd/tools/test-sign-binpkgs.sh` signs and verifies real `quickpkg` gpkgs.
A passphrase-protected software key in temp GnuPG homes stands in for the
YubiKey. It runs unprivileged on a Gentoo host, or in a `gentoo/stage3`
container as CI does (the command is in the script's header).

`livecd/tools/test-sign-binpkgs-yubikey.sh SERIAL KEY.asc` is the same check
against the real key on the YubiKey, so it needs the card and its user PIN.
It uses temp GnuPG homes and reports the time per signature. With
`--wrong-pin` it also checks that a wrong PIN file costs exactly one PIN try
and that the next run refuses to use it. CI can't run it.

`livecd/tools/test-check-mirror-signed.sh` runs `check-mirror-signed.sh`
against hand-written indexes served from `127.0.0.1`, with identical, stale,
missing and extra entries, a stale `Packages.gz` and a dir missing on the
mirror. It needs no root and
no network.

`livecd/tools/test-image-cleanup.sh` checks that every stage4, livecd and
docker target removes `/etc/portage/gnupg`. getuto keeps a private local
trust key and its passphrase there, so each install has to make its own
rather than get one shipped in an image. It also checks that each
Dockerfile empties the binpkg locations with `eclean-pkg` rather than `rm`.
Binpkgs from the Pentoo binhosts are kept in the `binrepos.conf` locations
under `/var/cache/binhost`, not in PKGDIR, and eclean-pkg finds them all.

`livecd/tools/test-docker-eclean.sh` runs the Dockerfiles' `eclean-pkg`
line in `pentoolinux/pentoo-core`. It checks that the line deletes every
binpkg, both in PKGDIR and in a `binrepos.conf` location, and leaves the
installed packages and `/var/empty` alone. Plain `eclean-pkg --deep` keeps
binpkgs of installed packages, so the line points `ROOT` at `/var/empty`,
where nothing is installed. It needs docker but no privileges.

The Dockerfiles that run emerge first run `pentoo-trust-helper` from the
mounted pentoo repo, if it has it. The images ship without
`/etc/portage/gnupg` and the builds don't sync, so nothing else makes the
keyring and trusts the binhost keys. Signed binpkgs would then be rejected.
`livecd/tools/test-docker-trust.sh OVERLAY` runs those lines in
`pentoolinux/pentoo-core` with the portage tree and a pentoo-overlay checkout
mounted at `/var/db/repos`, as the builds mount them. With an overlay that
has the helper, the Pentoo binhost key has to end up fully trusted. Without
it, the lines have to succeed and do nothing. It needs docker and the
`portage` volume container from `gentoo/portage`, but no privileges.
`test-image-cleanup.sh` checks that each of those Dockerfiles runs the
helper before its first emerge.

The iso keeps the repos, so a user can emerge on it without syncing first.
`root_overlay/etc/local.d/50-pentoo-trust-helper.start` runs
`pentoo-trust-helper` at boot to make the keyring and trust the Pentoo binhost
key, and removes itself once that works. The installer copies `/etc` without
deleting, so an install runs it once more on its first boot.
`livecd/tools/test-livecd-trust-hook.sh` checks it with a stub helper and
needs no root.
