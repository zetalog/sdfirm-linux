#!/bin/bash

TOP=`pwd`
SCRIPT=`(cd \`dirname $0\`; cd ..; pwd)`
ARCH=riscv
CROSS_COMPILE=riscv64-unknown-linux-gnu-

BUSYBOX_CONFIG=config-busybox-$ARCH
LINUX_CONFIG=config-linux-$ARCH-$MACH
INITRAMFS_FILELIST_TEMPLATE=$ARCH-initramfs-list

if [ -z $BUSYBOX_DIR ]; then
	BUSYBOX_DIR=busybox
	BUSYBOX_PATH=$TOP/busybox
else
	BUSYBOX_PATH=`(cd $BUSYBOX_DIR; pwd)`
	BUSYBOX_DIR=`dirname $BUSYBOX_PATH`
fi
if [ -z $LINUX_DIR ]; then
	LINUX_DIR=linux
	LINUX_PATH=$TOP/linux
else
	LINUX_PATH=`(cd $LINUX_DIR; pwd)`
	LINUX_DIR=`dirname $LINUX_PATH`
fi
if [ -z $BBL ]; then
	BBL=riscv-pk
fi
if [ "x$BBL" = "xsdfirm" ]; then
	if [ -z $SDFIRM_DIR ]; then
		SDFIRM_DIR=sdfirm
		SDFIRM_PATH=$TOP/sdfirm
	else
		SDFIRM_PATH=`(cd $SDFIRM_DIR; pwd)`
		SDFIRM_DIR=`dirname $SDFIRM_PATH`
	fi
	if [ -z $MACH ]; then
		MACH=spike64
	fi
fi
INITRAMFS_DIR=obj/initramfs/$ARCH
INITRAMFS_FILELIST=obj/initramfs/list-$ARCH
BBL_DIR=obj/bbl

BENCH_BIN_DIR=obj/bench-$ARCH

ARCHIVES_DIR=$TOP/archive

function clean_all()
{
	echo "== Clean all =="
	rm -rf $TOP/obj/busybox-$ARCH
	rm -rf $TOP/$INITRAMFS_DIR
	rm -rf $TOP/obj/linux-$ARCH
	rm -rf $TOP/$BBL_DIR
}

function build_busybox()
{
	echo "== Build Busybox =="
	rm -rf $TOP/obj/busybox-$ARCH
	cd $BUSYBOX_PATH
	mkdir -pv $TOP/obj/busybox-$ARCH
	cp $SCRIPT/config/$BUSYBOX_CONFIG ./.config
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/busybox-$ARCH/ oldconfig
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE mrproper
	cd $TOP/obj/busybox-$ARCH
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j6
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install
	cd -
}

function build_initramfs_old()
{
	echo "== Build initramfs =="
	rm -rf $TOP/$INITRAMFS_DIR
	mkdir -pv $TOP/$INITRAMFS_DIR
	cd $TOP/$INITRAMFS_DIR
	mkdir -pv {bin,sbin,dev,etc,proc,sys,usr/{bin,sbin}}
	cp -av $TOP/obj/busybox-$ARCH/_install/* .
	sudo mknod dev/ttyS0 c 5 1
	> ./init
	echo "#!/bin/busybox sh" >> ./init
	echo "" >> ./init
	#echo "/bin/busybox --install -s" >> ./init
	echo "mount -t proc none /proc" >> ./init
	echo "mount -t sysfs none /sys" >> ./init
	#echo "mount -t devtmpfs devtmpfs /dev" >> ./init
	echo "echo -e \"\nBoot took \$(cut -d' ' -f1 /proc/uptime) seconds\\n\" >> /dev/ttyS0" >> ./init
	echo "exec setsid sh -c 'exec sh </dev/ttyS0 >/dev/ttyS0 2>&1'" >> ./init
	chmod +x ./init
	find . | cpio -H newc -o > $TOP/obj/initramfs-$ARCH.cpio
	cd -
	cd $TOP/obj
	cat initramfs-$ARCH.cpio | gzip > initramfs-$ARCH.gz
	cd -
}

function build_initramfs()
{
	echo "== Build initramfs =="
	rm -rf $TOP/$INITRAMFS_DIR
	mkdir -pv $TOP/$INITRAMFS_DIR
	cp -rf $SCRIPT/config/$INITRAMFS_FILELIST_TEMPLATE $TOP/$INITRAMFS_FILELIST
	cp -rf $SCRIPT/config/riscv-initramfs-init $TOP/obj/riscv-initramfs-init
	cd $TOP/$INITRAMFS_DIR
	cp -av $TOP/obj/busybox-$ARCH/_install/* .
	if [ -x ./bin ]
	then
		for f in `ls ./bin`
		do
			if [ "$f" == "busybox" ]
			then
				continue
			fi
			grep $f $TOP/$INITRAMFS_FILELIST >> /dev/null
			if [ $? == 1 ]
			then
				echo "slink /bin/$f busybox 777 0 0" >> $TOP/$INITRAMFS_FILELIST
			fi
		done
	fi
	if [ -x ./sbin ]
	then
		for f in `ls ./sbin`
		do
			grep $f $TOP/$INITRAMFS_FILELIST >> /dev/null
			if [ $? == 1 ]
			then
				echo "slink /sbin/$f ../bin/busybox 777 0 0" >> $TOP/$INITRAMFS_FILELIST
			fi
		done
	fi
	if [ -x ./usr/sbin ]
	then
		for f in `ls ./usr/bin`
		do
			grep $f $TOP/$INITRAMFS_FILELIST >> /dev/null
			if [ $? == 1 ]
			then
				echo "slink /usr/bin/$f ../../bin/busybox 777 0 0" >> $TOP/$INITRAMFS_FILELIST
			fi
		done
	fi

	mkdir ./bench
	if [ -x $TOP/$BENCH_BIN_DIR ]
	then
		cp -rf $TOP/$BENCH_BIN_DIR/* ./bench
		for f in `ls ./bench`
		do
			echo "file /bench/$f ../../$INITRAMFS_DIR/bench/$f 755 0 0" >> $TOP/$INITRAMFS_FILELIST
		done
	fi

	echo "Use INITRAMFS_SOURCE file list: $INITRAMFS_FILELIST"
	grep INITRAMFS_SOURCE $SCRIPT/config/$LINUX_CONFIG
	echo "So initramfs is built not here now but together with kernel later"
	cat $TOP/$INITRAMFS_FILELIST
	cd -
}

function build_linux()
{
	echo "== Build Linux =="
	rm -rf $TOP/obj/linux-$ARCH
	#mkdir -p $TOP/obj/linux-$ARCH
	cd $LINUX_PATH
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE distclean
	cp $SCRIPT/config/$LINUX_CONFIG arch/$ARCH/configs/my_defconfig
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/linux-$ARCH/ my_defconfig
	ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE $LINUX_PATH/scripts/config \
		--file $TOP/obj/linux-$ARCH/.config \
		--set-str INITRAMFS_SOURCE $TOP/$INITRAMFS_FILELIST
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/linux-$ARCH/ -j6
	if [ ! -f $TOP/obj/linux-$ARCH/vmlinux ]
	then
		echo "Error: Failed to build Linux"
		exit 1
	fi
	${CROSS_COMPILE}objcopy --only-keep-debug $TOP/obj/linux-$ARCH/vmlinux $TOP/obj/linux-$ARCH/kernel.sym
	cd -
}

function build_sdfirm()
{
	echo "== Build sdfirm =="
	rm -rf $TOP/obj/sdfirm-$ARCH
	mkdir -p $TOP/obj/sdfirm-$ARCH
	cd $SDFIRM_PATH
	if [ -x $TOP/obj/sdfirm-$ARCH ]; then
		make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/sdfirm-$ARCH/ distclean
	fi
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE distclean
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE distclean
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/sdfirm-$ARCH/ ${MACH}_bbl_defconfig
	ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPLE $SDFIRM_PATH/scripts/config \
		--file $TOP/obj/sdfirm-$ARCH/.config \
		--set-str SBI_PAYLOAD_PATH $TOP/obj/linux-$ARCH/arch/$ARCH/boot/Image
	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE O=$TOP/obj/sdfirm-$ARCH/ -j6
	if [ ! -f $TOP/obj/sdfirm-$ARCH/sdfirm ]
	then
		echo "Error: Failed to build sdfirm"
		exit 1
	fi
	${CROSS_COMPILE}objcopy --only-keep-debug $TOP/obj/sdfirm-$ARCH/sdfirm $TOP/obj/sdfirm-$ARCH/sdfirm.sym
	cd -
}

function build_riscv-pk()
{
	echo "== Build riscv-pk =="
	rm -rf $TOP/$BBL_DIR
	mkdir -pv $TOP/$BBL_DIR
	cd $BBL_DIR
	$SCRIPT/riscv-pk/configure  --enable-logo --host=riscv64-unknown-linux-gnu --with-payload=$TOP/obj/linux-$ARCH/vmlinux
	make
	cd -
}

function build_bbl()
{
	if [ "x$BBL" = "xriscv-pk" ]; then
		build_riscv-pk
	fi
	if [ "x$BBL" = "xsdfirm" ]; then
		build_sdfirm
	fi
}

cd $TOP

echo "== Prepare =="
if [ ! -f $SCRIPT/config/$LINUX_CONFIG ]
then
	echo "Linux config not found $LINUX_CONFIG"
	exit 1
fi

if [ ! -f $SCRIPT/config/$BUSYBOX_CONFIG ]
then
	echo "Busybox config not found $BUSYBOX_CONFIG"
	exit 1
fi

if [ ! -d $LINUX_DIR ]
then
	echo "Linux source $LINUX_DIR not found"
	exit 1
fi

if [ ! -d $BUSYBOX_DIR ]
then
	echo "Busybox source $BUSYBOX_DIR not found"
	exit 1
fi

if [ $# -eq 1 ]
then
	if [ "$1" == "clean" ]
	then
		clean_all
	elif [ "$1" == "busybox" ]
	then
		build_busybox
	elif [ "$1" == "initramfs" ]
	then
		build_initramfs
	elif [ "$1" == "linux" ]
	then
		build_linux
	elif [ "$1" == "bbl" ]
	then
		build_bbl
	fi
else
		clean_all
		build_busybox
		build_initramfs
		build_linux
		build_bbl
fi
