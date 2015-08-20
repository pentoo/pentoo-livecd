#!/bin/bash

alias ls='ls --color'
alias aemerge='ACCEPT_KEYWORDS="~x86" emerge'
alias cp='cp -i'
alias mv='mv -i'

if [ $(tty) == /dev/tty1 ]; then
        cat /root/motd
fi

