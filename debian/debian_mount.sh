#!/bin/bash

echo "Mounting filesystems. proc, sys, dev"

TARGET_DIR=debian_fs

if mount | grep -q ${TARGET_DIR}/dev; then
   echo ${TARGET_DIR}/dev/ already mounted
else
   echo "Mounting dev filesystem"
   sudo mount --rbind --make-rslave /dev ${TARGET_DIR}/dev/
fi

if mount | grep -q ${TARGET_DIR}/sys; then
   echo ${TARGET_DIR}/sys/ already mounted
else
   echo "Mounting sys filesystem"
   sudo mount --rbind --make-rslave /sys ${TARGET_DIR}/sys/
fi

if mount | grep -q ${TARGET_DIR}/proc; then
   echo ${TARGET_DIR}/proc/ already mounted
else
   echo "Mounting proc filesystem"
   sudo mount -t proc /proc ${TARGET_DIR}/proc
fi
