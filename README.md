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
