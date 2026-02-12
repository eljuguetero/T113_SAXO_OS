#!/bin/bash

TARGET_DIR=debian_fs

for fs in $(mount | grep "debian_fs"  | awk '{print $3}' | awk '{print length, $0}' | sort -nr | cut -d' ' -f2-); do
   echo umounting $fs
   sudo umount $fs
done
