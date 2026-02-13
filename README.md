## Update package lists
sudo apt update

## Install essential build tools, kernel build dependencies, and ARM cross-compiler
sudo apt install -y build-essential fakeroot bc bison flex libssl-dev libncurses-dev libelf-dev gcc-arm-linux-gnueabi

## Install mkbootimg for boot image creation
sudo apt install -y mkbootimg

## Install U-Boot tools and Python development files
sudo apt install u-boot-tools python3-dev

## Clone the T113_SAXO_OS repository with all submodules (shallow clone, depth 1)
git clone --recurse-submodules --shallow-submodules --depth 1 git@github.com:eljuguetero/T113_SAXO_OS.git
