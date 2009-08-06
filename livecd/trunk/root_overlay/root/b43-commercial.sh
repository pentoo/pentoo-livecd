#!/bin/bash
echo "User action is installing the broadcom commercial firmware."
echo "Broadcom prohibits the distribution of firmware in a"
echo "usable form for Linux users."
emerge broadcom-firmware-installer
echo "Firmware has been installed and is NOT permitted to be redistributed."
echo "You can make a module for your personal use and put it in the modules"
echo "folder of your usb/cd for personal use only. Try flushchanges."

#echo "If someone is really nice they will make a script to make this a module for the user..."
