#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

cd $SCRIPT_DIR

cp u-boot-patch-v2025.07/t113s_saxo_defconfig u-boot/configs
cp u-boot-patch-v2025.07/sun8i-t113s-saxo.dts         u-boot/arch/arm/dts
cp u-boot-patch-v2025.07/sunxi-d1s-t113s-saxo.dtsi    u-boot/arch/arm/dts
cp u-boot-patch-v2025.07/sunxi-d1s-t113.dtsi          u-boot/arch/riscv/dts

cd u-boot

git checkout -f

patch -d . -p1 <  ../u-boot-patch-v2025.07/0001-saxo-dtb.patch

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j4 t113s_saxo_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j4
