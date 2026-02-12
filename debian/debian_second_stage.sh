#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

cd $SCRIPT_DIR

TARGET_DIR=debian_fs

./debian_mount.sh

sudo chroot $TARGET_DIR /debootstrap/debootstrap --second-stage

./debian_umount.sh
