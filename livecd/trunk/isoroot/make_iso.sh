mkisofs -J -R -l -V "Pentoo" -o /tmp/pentoo.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table ./
