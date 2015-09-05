# Pentoo Penetration Testing LiveCD
stuff to generate the pentoo livecd
<a href="http://pentoo.ch"><img src="https://github.com/pentoo/pentoo-overlay/wiki/images/pentoo2.png"></a>


<a href="http://pentoo.ch"><img src="https://avatars0.githubusercontent.com/u/6411603?v=3&s=200" align="left" hspace="10" vspace="6"></a>
Pentoo is a Live CD and Live USB designed for penetration testing and security assessment. Based on Gentoo Linux, Pentoo is provided both as 32 and 64 bit installable livecd. Pentoo is also available as an overlay for an existing Gentoo installation. It features packet injection patched wifi drivers, GPGPU cracking software, and lots of tools for penetration testing and security assessment. The Pentoo kernel includes grsecurity and PAX hardening and extra patches - with binaries compiled from a hardened toolchain with the latest nightly versions of some tools available. The latest release of the Pentoo Livecd is [2015 RC3.8](http://www.pentoo.ch/download/)

Pentoo comes in many flavors and it is important to choose wisely. Right now, you have two main choices:

***hardened or default?***

You want hardened. No seriously, you want hardened. When was the last time you thought to yourself "I need less security in my pen-testing environment?" In all seriousness, nearly everything works in the hardened builds, and it is vastly more stable than anything you have ever used before with the added bonus of being more secure. You only want default if you are doing exploit against yourself, or you need opengl support. OpenCL and CUDA work fine in the hardened release, but right now, opengl support still eludes us. If you cannot live without opengl acceleration pick default, otherwise, you really want hardened.

#USB flash installation media

**BIOS and UEFI Bootable USB :: Quick Install**

*Creating on GNU/Linux*

This method is recommended due to its simplicity. **This will irrevocably destroy all data on /dev/sdx**

Run the following command, replacing /dev/sdx with your drive, e.g. /dev/sdb. (do not append a partition number, so do not use something like /dev/sdb1)

```
dd bs=512k if=/path/to/pentoo-amd64-hardened-2015.0_RC*.iso of=/dev/sdx && sync
```

*Creating on Windows*

If you’re running under Windows, you’ll need to download the Win32 Disk Imager utility:

<a href="http://sourceforge.net/projects/win32diskimager/"><img src="https://a.fsdn.com/con/app/proj/win32diskimager/screenshots/win32-imagewriter.png"></a>

*Creating on OS X*

Run the following command, replacing /dev/diskx with your drive, e.g. /dev/disk7.

```
sudo dd if=/path/to/pentoo-amd64-hardened-2015.0_RC*.iso of=/dev/diskx bs=1m
```


Want to learn more? [See the wiki.](https://github.com/pentoo/pentoo-overlay/wiki)



Discussion and support available on irc.freenode.net  **#pentoo**
