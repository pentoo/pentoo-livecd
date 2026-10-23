if [[ ${CATEGORY}/${PN} == dev-python/nassl ]]; then
  export MAKEOPTS="${MAKEOPTS} -j1 --shuffle=none"
fi
