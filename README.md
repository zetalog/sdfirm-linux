SDFirm Linux+Busybox Image Builder
======================================

About
---------

This project is a combination of [eps-std](https://github.com/zetalog/eps-std) and [tiny-linux](https://github.com/IanJiangICT/tiny-linux).

All these projects are used to create a busybox+linux image. And this
project is specialized to only creates a RISC-V linux kernel image with
busybox as its basic userspace program. And creates a bootable BBL image
using sdfirm.

Build steps of creating sdfirm BBL image
--------------------------------------------

In a working directory (say, workspace), do the following to prepare the
environments:

    $ cd workspace
    $ git clone https://github.com/zetalog/sdfirm
    $ git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
    $ git clone git://busybox.net/busybox.git
    $ git clone https://github.com/zetalog/sdfirm-linux

Then type the following command to complate all jobs:

spike image:

    $ MACH=spike64 ./sdfirm-linux/scripts/build_linux_image.sh

qemu image:

    $ MACH=virt64 ./sdfirm-linux/scripts/build_linux_image.sh

Run steps
-------------

If you've created a spike64 or virt64 image and you have spike or qemu
installed on your machine, do the following to run the image:

spike image:

    $ ./sdfirm/scripts/run-spike.sh ./obj/sdfirm-riscv/sdfirm

qemu image:

    $ ./sdfirm/scripts/run-qemu.sh ./obj/sdfirm-riscv/sdfirm

Add userspace programs
--------------------------

If you want to add userspace programs, you need to put your pre-built
programs to sdfirm-linux/bench folder and modify
sdfirm-linux/config/config-initramfs-riscv to include the image to the
linux rootfs image.

As an example, here is a way to build dhrystone/linpack:

    $ pushd ./sdfirm/tests/bench
    $ make -f Makefile.target clean
    $ make -f Makefile.target
    $ popd
    $ cp ./sdfirm/tests/bench/dhrystone.elf ./sdfirm-linux/bench/dhrystone
    $ cp ./sdfirm/tests/bench/linpack.elf ./sdfirm-linux/bench/linpack

Note that, the config-initramfs-riscv has already been prepared to include
these 2 files if they exist.
