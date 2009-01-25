#/bin/sh!

# Purge the uneeded locale, should keeps only en
localepurge

# Set the timezone
if [[ -e /etc/conf.d/clock ]]
then
	sed -i -e 's/#TIMEZONE="Factory"/TIMEZONE="UTC"/' /etc/conf.d/clock
fi

# Bunzip all docs since they'll be in sqlzma format
cd /usr/share/doc
for maindir in `find ./ -maxdepth 1 -type d | sed -e 's:^./::'`
do
        cd "${maindir}"
        for file in `ls *.bz2`
        do
                bunzip2 "${file}"
        done
        cd ..
done

# Runs the incredible menu generator
genmenu.py -v -t urxvt

# Fix the root login by emptying the root password. No ssh will be allowed until 'passwd root'
sed -i -e 's/^root:\*:/root::/' /etc/shadow

# Setup kismet & airmon-ng
[ -e /usr/sbin/airmon-ng ] && sed -i -e 's:/kismet::' /usr/sbin/airmon-ng
[ -e /etc/kismet.conf ] && sed -i -e '/^source=.*/d' /etc/kismet.conf
[ -e /etc/kismet.conf ] && sed -i -e 's:configdir=.*:configdir=/root/kismet:' -e 's/your_user_here/kismet/' /etc/kismet.conf
[ -e /etc/kismet.conf ] && useradd -g root kismet
[ -e /etc/kismet.conf ] && cp -a /etc/kismet.conf /etc/kismet.conf~
[ -e /etc/kismet.conf ] && mkdir /root/kismet && chown kismet /root/kismet

# Remove useless opengl setup
rm /etc/init.d/x-setup
eselect opengl set xorg-x11 --dst-prefix=/etc/opengl

# Setup tor-privoxy
echo 'forward-socks4a / 127.0.0.1:9050' >> /etc/privoxy/config
cp /etc/tor/torrc.sample /etc/tor/torrc
mkdir /var/log/tor
chown tor:tor /var/lib/tor
chown tor:tor /var/log/tor

# Setup ntop
chmod 777 -R /var/lib/ntop
ntop --set-admin-password=pentoo

# Setup ath5k as the default
/usr/sbin/athload

# Sets FF as default browser
echo 'export BROWSER="firefox"' >> /etc/env.d/99local

# Build the metadata cache
emerge --metadata

# compile mingw32
crossdev --portage -bk i686-mingw32

# Adds sploit collection
cd /opt/
mkdir exploits/packetstorm -p
for file in `ls *.tgz`
do
	tar -zxf ${file} -C exploits/packetstorm/
	rm -f ${file}
done
tar -jxf milw0rm.tar.bz2 -C exploits/
rm -f milw0rm.tar.bz2
