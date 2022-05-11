#!/bin/bash
set -e

D="/"
PN="greengrass-bin"
PV="2.4.0"
SRC_URI="https://d2s8p88vqu9w66.cloudfront.net/releases/greengrass-2.4.0.zip"
GG_BASENAME="greengrass/v2"
GG_ROOT="${D}/${GG_BASENAME}"
S="${WORKDIR}"
WORKDIR="$HOME/greengrass"

mkdir -p ${WORKDIR}

cp ./greengrass-bin/greengrassv2-init.yaml ${WORKDIR}
pushd ${WORKDIR} && \
  wget -O greengrass.zip ${SRC_URI} && unzip greengrass.zip && \
  popd

## do_install()
install -d ${GG_ROOT}/config
install -d ${GG_ROOT}/alts
install -d ${GG_ROOT}/alts/init
install -d ${GG_ROOT}/alts/init/distro
install -d ${GG_ROOT}/alts/init/distro/bin
install -d ${GG_ROOT}/alts/init/distro/conf
install -d ${GG_ROOT}/alts/init/distro/lib

install -m 0440 ${WORKDIR}/LICENSE                         ${GG_ROOT}
install -m 0640 ${WORKDIR}/greengrassv2-init.yaml          ${GG_ROOT}/config/config.yaml.clean
install -m 0640 ${WORKDIR}/bin/greengrass.service.template ${GG_ROOT}/alts/init/distro/bin/greengrass.service.template
install -m 0740 ${WORKDIR}/bin/loader                      ${GG_ROOT}/alts/init/distro/bin/loader
install -m 0640 ${WORKDIR}/conf/recipe.yaml                ${GG_ROOT}/alts/init/distro/conf/recipe.yaml
install -m 0740 ${WORKDIR}/lib/Greengrass.jar              ${GG_ROOT}/alts/init/distro/lib/Greengrass.jar

ln -s /${GG_ROOT}/alts/init ${GG_ROOT}/alts/current

# Install systemd service file
# install -d ${D}${systemd_unitdir}/system/
# install -m 0644 ${WORKDIR}/bin/greengrass.service.template ${D}${systemd_unitdir}/system/greengrass.service
# sed -i -e "s,REPLACE_WITH_GG_LOADER_FILE,/${GG_BASENAME}/alts/current/distro/bin/loader,g" ${D}${systemd_unitdir}/system/greengrass.service
# sed -i -e "s,REPLACE_WITH_GG_LOADER_PID_FILE,/var/run/greengrass.pid,g" ${D}${systemd_unitdir}/system/greengrass.service
