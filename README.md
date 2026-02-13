# Host setup
```
# Update package lists
sudo apt update

# Install essential build tools, kernel build dependencies, and ARM cross-compiler
sudo apt install -y build-essential fakeroot bc bison flex libssl-dev libncurses-dev libelf-dev gcc-arm-linux-gnueabi

# Install mkbootimg for boot image creation
sudo apt install -y mkbootimg

# Install U-Boot tools and Python development files
sudo apt install -y u-boot-tools python3-dev

# Debian debootstrap related tools
sudo apt install -y debootstrap fakeroot qemu-user-static binfmt-support
```

# Clone the T113_SAXO_OS repository with all submodules 
Shallow clone, depth 1
```
git clone --recurse-submodules --shallow-submodules --depth 1 git@github.com:eljuguetero/T113_SAXO_OS.git
```
# Kernel compilation
```
./build_kernel.sh
```

# U-Boot compilation
```
./build_u-boot.sh
```

# Custom Debian bootstrap
```
cd debian 
./build_debian.sh
```
