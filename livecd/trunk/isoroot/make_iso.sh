mkisofs -J -R -l -V "2011.0" -o /tmp/pentoo.iso -b boot/grub/stage2_eltorito -c boot/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table ./
