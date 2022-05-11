#!/bin/bash
set -e
source global_variables.sh
PN='tim-vx'
PV='1.1.32'
S=${WORKDIR}'/'${PN}
SRCBRANCH='lf-5.10.52_2.1.0'
TIM_VX_SRC='https://github.com/nxpmicro/tim-vx-imx'
PKG_CONFIG_SYSROOT_DIR="/"

EXTRA_OECMAKE=" \
    -DCONFIG=YOCTO \
    -DTIM_VX_ENABLE_TEST=off \
    -DCMAKE_INSTALL_PREFIX=/usr/
"
pushd ${WORKDIR} && git clone -b ${SRCBRANCH} ${TIM_VX_SRC} ${S} && popd
pushd ${S} && \
  git reset baea9b827f0a17525b2054b8d9e75b911a0c5035 --hard && \
  git clean -df && \
  git am /home/torizon/tim-vx-patch/*.patch && \
  mkdir build && pushd build && \
  cmake ${EXTRA_OECMAKE} .. && make -j`nproc` all install && \
  popd && popd
