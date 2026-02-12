#!/bin/bash

TARGET_DIR=debian_fs

./debian_umount.sh

sudo mksquashfs ${TARGET_DIR} debian.lz4.squashfs -b 256k  -comp lz4 -Xhc

