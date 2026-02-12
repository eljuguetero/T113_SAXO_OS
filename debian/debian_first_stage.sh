#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

cd $SCRIPT_DIR

TARGET_DIR=debian_fs

fakeroot debootstrap --arch=armhf --foreign  --variant=minbase trixie  $TARGET_DIR  http://deb.debian.org/debian

