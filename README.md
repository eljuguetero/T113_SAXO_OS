sudo apt update
sudo apt install -y build-essential fakeroot bc bison flex libssl-dev libncurses-dev libelf-dev  gcc-arm-linux-gnueabi
sudo apt install -y mkbootimg sudo apt install u-boot-tools

git clone --recurse-submodules --shallow-submodules --depth 1 git@github.com:eljuguetero/T113_SAXO_OS.git
