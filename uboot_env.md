setenv bootdelay 2
setenv mmc_dev 0
setenv mmc_boot_part 1
setenv kernel uImage
setenv kernel_addr_r 0x41800000
setenv fdt_addr_r 0x43000000
setenv load_dtb    "fatload mmc ${mmc_dev}:${mmc_boot_part} ${fdt_addr_r} sun8i-t113s-saxo.dtb"
setenv load_kernel "fatload mmc ${mmc_dev}:${mmc_boot_part} ${kernel_addr_r} ${kernel}"
setenv boot_mmc "run load_dtb;run load_kernel; bootm ${kernel_addr_r} - ${fdt_addr_r}"
setenv bootargs "mem=128M cma=72M root=/dev/mmcblk0p2 rw init=/sbin/init rootwait console=ttyS3,115200n8"

