#!/bin/bash

TARGET_DIR=debian_fs

./debian_mount.sh

sudo chroot ${TARGET_DIR} /bin/bash --login 

./debian_umount.sh
