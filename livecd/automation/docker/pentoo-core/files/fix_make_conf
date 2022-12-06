if ! grep -q 'EMERGE_DEFAULT_OPTS=.*--jobs' /etc/portage/make.conf; then
  printf "EMERGE_DEFAULT_OPTS=\"\${EMERGE_DEFAULT_OPTS} --jobs=$(nproc) --load-average=$(nproc)\"\n" >> /etc/portage/make.conf
fi
