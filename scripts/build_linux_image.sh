#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`
WORKING_DIR=`(cd ${SCRIPT}/../..; pwd)`

export ARCH=riscv
if [ -z $MACH ]; then
	export MACH=spike
else
	export MACH=$MACH
fi
export CROSS_COMPILE=riscv64-unknown-linux-gnu-
export BBL=sdfirm
export SDFIRM_DIR=${WORKING_DIR}/sdfirm
export LINUX_DIR=${WORKING_DIR}/linux
export BUSYBOX_DIR=${WORKING_DIR}/busybox

${SCRIPT}/build.sh $1

cp -f ${WORKING_DIR}/obj/linux-riscv/arch/${ARCH}/boot/Image ${SDFIRM_DIR}/
