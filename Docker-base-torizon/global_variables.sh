#!/bin/bash
set -e
bindir='/usr/bin'
D='/'
includedir='/usr/include'
libdir='/usr/lib'
TARGET_ARCH='aarch64'
WORKDIR='/workdir'
BPN=${PN}
sysconfdir='/etc'

# mkdir -p ${D}
mkdir -p ${WORKDIR}

f () {
    errorCode=$? # save the exit code as the first thing done in the trap function
    exit $errorCode  # or use some other value or do return instead
}
trap f ERR
