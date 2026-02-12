#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

cd $SCRIPT_DIR

TARGET_DIR=debian_fs

./debian_mount.sh

cp etc/sources.list ${TARGET_DIR}/etc/apt/sources.list
cp scripts/*.sh ${TARGET_DIR}/tmp

sudo chmod +x ${TARGET_DIR}/tmp/debian_saxo.sh
sudo chroot $TARGET_DIR /tmp/debian_saxo.sh

./debian_umount.sh
