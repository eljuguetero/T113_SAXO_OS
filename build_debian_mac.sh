#!/bin/bash
# =============================================================================
# build_debian_mac.sh — Crea rootfs Debian Bookworm para T113-S3 SAXO desde macOS
# Requiere: Docker o OrbStack corriendo
#
# NOTA: debootstrap necesita crear device nodes (mknod) lo cual no es posible
# en volúmenes montados desde macOS. La solución es hacer todo dentro del
# filesystem del contenedor y exportar el resultado como tarball.
# =============================================================================

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
IMAGE_NAME="t113-build"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.build"
DEBIAN_FS="$SCRIPT_DIR/debian_fs"
ROOTFS="$DEBIAN_FS/debian_bookworm"
TARBALL="$DEBIAN_FS/debian_bookworm.tar.gz"

# -----------------------------------------------------------------------------
# Colores
# -----------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# -----------------------------------------------------------------------------
# Verificar Docker
# -----------------------------------------------------------------------------
info "Verificando Docker..."
docker info > /dev/null 2>&1 || error "Docker no está corriendo. Abre OrbStack o Docker Desktop."

# -----------------------------------------------------------------------------
# Crear Dockerfile si no existe
# -----------------------------------------------------------------------------
if [ ! -f "$DOCKERFILE" ]; then
    info "Creando $DOCKERFILE..."
    cat > "$DOCKERFILE" << 'EOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential bc bison flex \
    libssl-dev libncurses-dev libelf-dev \
    gcc-arm-none-eabi \
    gcc-arm-linux-gnueabi \
    u-boot-tools python3-dev swig \
    debootstrap qemu-user-static binfmt-support \
    device-tree-compiler git wget curl \
    python3-setuptools libgnutls28-dev \
    cpio rsync kmod fakeroot \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
EOF
fi

# -----------------------------------------------------------------------------
# Construir imagen Docker si no existe
# -----------------------------------------------------------------------------
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    info "Construyendo imagen Docker '$IMAGE_NAME' (primera vez, tarda ~2 min)..."
    docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" "$SCRIPT_DIR"
else
    info "Imagen Docker '$IMAGE_NAME' ya existe."
fi

# -----------------------------------------------------------------------------
# Crear directorio de salida
# -----------------------------------------------------------------------------
mkdir -p "$DEBIAN_FS"

# -----------------------------------------------------------------------------
# Lista de paquetes
# -----------------------------------------------------------------------------
PACKAGES="apt-transport-https,busybox,ca-certificates,can-utils,net-tools,build-essential,\
command-not-found,chrony,curl,e2fsprogs,ethtool,fdisk,gpiod,haveged,\
i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,initramfs-tools,lrzsz,\
libiio-utils,lm-sensors,locales,nano,net-tools,wpasupplicant,ntpdate,\
openssh-server,psmisc,rfkill,sudo,systemd-sysv,tftp,tftp-hpa,tio,usbutils,\
wget,xterm,xz-utils,vim,fim,build-essential,libftdi1-dev,libftdi1,chuck,chuck-data,\
alsa-utils,libasound2-dev,libsndfile1-dev,bison,flex,jackd2,libasound2,libsndfile1,\
libpulse-dev,pulseaudio,libjack-jackd2-dev,faust,apache2,\
libmicrohttpd12,libmicrohttpd-dev,iw,wireless-regdb,bsdextrautils"

# -----------------------------------------------------------------------------
# Todo el proceso dentro del filesystem del contenedor (evita restricción mknod)
# Luego se exporta como tarball al volumen macOS
# -----------------------------------------------------------------------------
info "Iniciando construcción del rootfs Debian Bookworm (armhf)..."
info "Esto puede tardar 15-30 minutos dependiendo de la conexión..."

docker run --rm \
    --privileged \
    -v "$DEBIAN_FS:/output" \
    "$IMAGE_NAME" bash -c "
        set -e

        ROOTFS=/build/debian_bookworm
        mkdir -p \$ROOTFS

        # ----------------------------------------------------------------
        # Etapa 1: debootstrap primera etapa (en filesystem del contenedor)
        # ----------------------------------------------------------------
        echo ''
        echo '[1/4] debootstrap primera etapa...'
        debootstrap \
            --variant=minbase \
            --arch=armhf \
            --components=main,contrib,non-free \
            --foreign \
            --include=${PACKAGES} \
            bookworm \
            \$ROOTFS \
            https://deb.debian.org/debian

        # ----------------------------------------------------------------
        # Etapa 2: debootstrap segunda etapa con QEMU
        # ----------------------------------------------------------------
        echo ''
        echo '[2/4] debootstrap segunda etapa (QEMU ARM)...'
        cp /usr/bin/qemu-arm-static \$ROOTFS/usr/bin/
        update-binfmts --enable qemu-arm 2>/dev/null || true
        chroot \$ROOTFS /debootstrap/debootstrap --second-stage

        # ----------------------------------------------------------------
        # Etapa 3: configuración del sistema
        # ----------------------------------------------------------------
        echo ''
        echo '[3/4] Configurando el sistema...'

        # Hostname
        echo 'saxo' > \$ROOTFS/etc/hostname

        # /etc/hosts
        cat > \$ROOTFS/etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   saxo
::1         localhost ip6-localhost ip6-loopback
HOSTS

        # Red (eth0 DHCP)
        cat > \$ROOTFS/etc/network/interfaces << 'NET'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
NET

        # fstab
        cat > \$ROOTFS/etc/fstab << 'FSTAB'
/dev/mmcblk0p2  /       ext4    defaults,noatime    0 1
/dev/mmcblk0p1  /boot   vfat    defaults            0 2
FSTAB

        # locale
        chroot \$ROOTFS bash -c \"
            echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
            locale-gen
            update-locale LANG=en_US.UTF-8
        \" || true

        # SSH root login
        sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' \
            \$ROOTFS/etc/ssh/sshd_config 2>/dev/null || true

        # Password root = 'saxo'
        chroot \$ROOTFS bash -c \"echo 'root:saxo' | chpasswd\" || true

        # Limpiar qemu-arm-static
        rm -f \$ROOTFS/usr/bin/qemu-arm-static

        # ----------------------------------------------------------------
        # Etapa 4: exportar tarball al volumen macOS
        # ----------------------------------------------------------------
        echo ''
        echo '[4/4] Exportando rootfs a /output/debian_bookworm.tar.gz...'
        tar -czf /output/debian_bookworm.tar.gz -C /build debian_bookworm

        echo ''
        echo '===================================='
        echo ' Rootfs Debian Bookworm completado'
        echo '===================================='
        du -sh \$ROOTFS
    "

# -----------------------------------------------------------------------------
# Extraer tarball en macOS
# -----------------------------------------------------------------------------
if [ -f "$TARBALL" ]; then
    info "Extrayendo rootfs en $ROOTFS..."
    rm -rf "$ROOTFS"
    tar -xzf "$TARBALL" -C "$DEBIAN_FS"
    info "✅ Rootfs disponible en: $ROOTFS ($(du -sh "$ROOTFS" | cut -f1))"
    info "Tarball guardado en: $TARBALL"
else
    error "No se generó el tarball en $TARBALL"
fi

echo ""
info "Para flashear en la microSD ejecuta: sudo ./burn_microsd.sh"
