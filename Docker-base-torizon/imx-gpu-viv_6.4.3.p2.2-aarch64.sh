#!/bin/bash
set -e
f () {
    errorCode=$? # save the exit code as the first thing done in the trap function
    exit $errorCode  # or use some other value or do return instead
}
trap f ERR

source global_variables.sh
PN='imx-gpu-viv'
BPN=${PN}
PV='6.4.3.p2.2-aarch64'
S=${WORKDIR}'/'${BPN}-${PV}
FSL_MIRROR='https://www.nxp.com/lgfiles/NMG/MAD/YOCTO'
SRC_URI="${FSL_MIRROR}/${BPN}-${PV}.bin"
USE_WL='yes'
GLES3_HEADER_REMOVALS=''
HAS_GBM='true'
IS_MX8='1'
PE='1'

pushd ${WORKDIR} && wget ${SRC_URI} && \
  chmod +x ./${BPN}-${PV}.bin && \
  ./${BPN}-${PV}.bin --force --auto-accept && \
  popd

## do_install () ##
install -d ${D}${libdir}
install -d ${D}${includedir}
install -d ${D}${bindir}

cp -P ${S}/gpu-core/usr/lib/*.so* ${D}${libdir}
cp -r ${S}/gpu-core/usr/include/* ${D}${includedir}
cp -r ${S}/gpu-demos/opt ${D}
cp -r ${S}/gpu-tools/gmem-info/usr/bin/* ${D}${bindir}

# Use vulkan header from vulkan-headers recipe to support vkmark
rm -rf ${D}${includedir}/vulkan/

if [ -d ${S}/gpu-core/usr/lib/${IMX_SOC} ]; then
    cp -r ${S}/gpu-core/usr/lib/${IMX_SOC}/* ${D}${libdir}
fi

install -d ${D}${libdir}/pkgconfig
if ${HAS_GBM}; then
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/gbm.pc ${D}${libdir}/pkgconfig/gbm.pc
fi

# The preference order, based in DISTRO_FEATURES, is Wayland (with or without X11), X11 and fb
if [ "${USE_WL}" = "yes" ]; then

    backend=wayland

    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/egl_wayland.pc ${D}${libdir}/pkgconfig/egl.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv1_cm.pc ${D}${libdir}/pkgconfig/glesv1_cm.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv2.pc ${D}${libdir}/pkgconfig/glesv2.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/vg.pc ${D}${libdir}/pkgconfig/vg.pc

   if [ "${USE_X11}" = "yes" ]; then

    cp -r ${S}/gpu-core/usr/lib/dri ${D}${libdir}

   fi

elif [ "${USE_X11}" = "yes" ]; then

    cp -r ${S}/gpu-core/usr/lib/dri ${D}${libdir}

    backend=x11

    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/gl_x11.pc ${D}${libdir}/pkgconfig/gl.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/egl_x11.pc ${D}${libdir}/pkgconfig/egl.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv1_cm_x11.pc ${D}${libdir}/pkgconfig/glesv1_cm.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv2_x11.pc ${D}${libdir}/pkgconfig/glesv2.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/vg_x11.pc ${D}${libdir}/pkgconfig/vg.pc

else
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv1_cm.pc ${D}${libdir}/pkgconfig/glesv1_cm.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv2.pc ${D}${libdir}/pkgconfig/glesv2.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/vg.pc ${D}${libdir}/pkgconfig/vg.pc

    # Regular framebuffer
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/egl_linuxfb.pc ${D}${libdir}/pkgconfig/egl.pc

    backend=fb

fi

# Install Vendor ICDs for OpenCL's installable client driver loader (ICDs Loader)
install -d ${D}${sysconfdir}/OpenCL/vendors/
install -m 0644 ${S}/gpu-core/etc/Vivante.icd ${D}${sysconfdir}/OpenCL/vendors/Vivante.icd

# Handle backend specific drivers
cp -r ${S}/gpu-core/usr/lib/${backend}/* ${D}${libdir}
if [ "${USE_WL}" = "yes" ]; then
    # Special case for libVDK on Wayland backend, deliver fb library as well.
    cp ${S}/gpu-core/usr/lib/fb/libVDK.so.1.2.0 ${D}${libdir}/libVDK-fb.so.1.2.0
fi
if [ "${IS_MX8}" = "1" ]; then
    # Rename our libvulkan.so so it doesn't clash with vulkan-loader libvulkan.so
    mv ${D}${libdir}/libvulkan.so.1.1.6 ${D}${libdir}/libvulkan_VSI.so.1.1.6
    patchelf --set-soname libvulkan_VSI.so.1 ${D}${libdir}/libvulkan_VSI.so.1.1.6
    ln -sf libvulkan_VSI.so.1.1.6 ${D}${libdir}/libvulkan_VSI.so.1
    ln -sf libvulkan_VSI.so.1.1.6 ${D}${libdir}/libvulkan_VSI.so
    rm ${D}${libdir}/libvulkan.so*
fi

# skip packaging wayland libraries if no support is requested
if [ "${USE_WL}" = "no" ]; then
    find ${D}${libdir} -name "libgc_wayland_protocol.*" -exec rm '{}' ';'
    find ${D}${libdir} -name "libwayland-viv.*" -exec rm '{}' ';'
fi

# FIXME: MX6SL does not have 3D support; hack it for now
if [ "${IS_MX6SL}" = "1" ]; then
    rm -rf ${D}${libdir}/libCLC* ${D}${includedir}/CL \
           \
           ${D}${libdir}/libGL* ${D}${includedir}/GL* ${D}${libdir}/pkgconfig/gl.pc \
           \
           ${D}${libdir}/libGLES* ${D}${libdir}/pkgconfig/gles*.pc \
           \
           ${D}${libdir}/libOpenCL* ${D}${includedir}/CL \
           \
           ${D}${libdir}/libOpenVG.3d.so \
           \
           ${D}${libdir}/libVivanteOpenCL.so \
           \
           ${D}/opt/viv_samples/vdk \
           ${D}/opt/viv_samples/es20 ${D}/opt/viv_samples/cl11

    ln -sf libOpenVG.2d.so ${D}${libdir}/libOpenVG.so
fi

# find ${D}${libdir} -type f -exec chmod 644 {} \;
# find ${D}${includedir} -type f -exec chmod 644 {} \;
#
# chown -R root:root "${D}"
