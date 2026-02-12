#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd $SCRIPT_DIR

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=C

apt update && apt -y upgrade

apt install -y locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

apt install -y \
      cmake \
      dosfstools \
      e2fsprogs \
      firmware-realtek \
      fdisk \
      gdisk \
      g++ \
      libterm-readline-perl-perl \
      libyaml-cpp-dev\
      parted \
      picocom \
      sudo \
      usbutils \
      vim \
      watchdog

apt install -y python3 \
            python3-venv \
            python3-pip

apt install -y  \
	iproute2 \
	iputils-ping   \
	network-manager \
	openssh-server

./custom_user.sh

echo t113 > /etc/hostname
echo "127.0.0.1 t113" >> /etc/hosts

