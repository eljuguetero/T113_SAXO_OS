
./bin/dragonsecboot -pack boot_package.cfg

sudo dd if=u-boot/u-boot-sunxi-with-spl.bin of=/dev/sda bs=1k seek=8

sudo dd if=boot_package.fex of=/dev/sda bs=1k seek=16400
