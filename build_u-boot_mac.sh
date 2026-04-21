#!/bin/bash
# =============================================================================
# build_u-boot_mac.sh — Compila U-Boot para T113-S3 SAXO desde macOS
# Requiere: Docker o OrbStack corriendo
# =============================================================================

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
IMAGE_NAME="t113-build"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.build"

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
    device-tree-compiler git wget curl \
    python3-setuptools libgnutls28-dev \
    cpio rsync kmod \
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
# Verificar que existen los archivos de patch
# -----------------------------------------------------------------------------
PATCH_DIR="$SCRIPT_DIR/u-boot-patch-v2025.07"
[ -d "$PATCH_DIR" ] || error "No se encontró el directorio $PATCH_DIR"
[ -d "$SCRIPT_DIR/u-boot" ] || error "No se encontró el directorio u-boot. Ejecuta: git submodule update --init"

# -----------------------------------------------------------------------------
# Compilar U-Boot dentro de Docker
# -----------------------------------------------------------------------------
info "Iniciando compilación de U-Boot..."

docker run --rm \
    --privileged \
    -v "$SCRIPT_DIR:/work" \
    "$IMAGE_NAME" bash -c '
        set -e
        cd /work

        echo "[1/4] Copiando archivos de configuración..."
        cp u-boot-patch-v2025.07/t113s_saxo_uart0_defconfig u-boot/configs/t113s_saxo_defconfig
        cp u-boot-patch-v2025.07/sun8i-t113s-saxo.dts      u-boot/arch/arm/dts/
        cp u-boot-patch-v2025.07/sunxi-d1s-t113s-saxo.dtsi u-boot/arch/arm/dts/
        cp u-boot-patch-v2025.07/sunxi-d1s-t113.dtsi       u-boot/arch/riscv/dts/

        cd u-boot

        echo "[2/4] Aplicando patch..."
        patch -d . -p1 --forward < ../u-boot-patch-v2025.07/0001-saxo-dtb.patch || \
            echo "Patch ya aplicado o sin cambios, continuando..."

        echo "[3/4] Configurando U-Boot..."
        make ARCH=arm CROSS_COMPILE=arm-none-eabi- t113s_saxo_defconfig

        echo "[4/4] Compilando U-Boot..."
        make ARCH=arm CROSS_COMPILE=arm-none-eabi- \
            HOSTCFLAGS="-I/usr/include" \
            NO_PYTHON=1 \
            -j$(nproc)

        echo ""
        echo "===================================="
        echo " U-Boot compilado exitosamente"
        echo "===================================="
        ls -lh /work/u-boot/u-boot-sunxi-with-spl.bin 2>/dev/null || \
            ls -lh /work/u-boot/u-boot.bin /work/u-boot/spl/sunxi-spl.bin
    '

# -----------------------------------------------------------------------------
# Verificar resultado
# -----------------------------------------------------------------------------
SPL="$SCRIPT_DIR/u-boot/u-boot-sunxi-with-spl.bin"
if [ -f "$SPL" ]; then
    info "✅ Archivo generado: $SPL ($(du -h "$SPL" | cut -f1))"
else
    warning "u-boot-sunxi-with-spl.bin no encontrado, verificando alternativas..."
    ls "$SCRIPT_DIR/u-boot/"*.bin "$SCRIPT_DIR/u-boot/spl/"*.bin 2>/dev/null || \
        error "No se generaron archivos .bin"
fi
