#!/bin/bash
# =============================================================================
# build_kernel_mac.sh — Compila kernel Linux para T113-S3 SAXO desde macOS
# Requiere: Docker o OrbStack corriendo
# Uso:
#   ./build_kernel_mac.sh           — compilación normal
#   ./build_kernel_mac.sh menuconfig — abrir menuconfig antes de compilar
# =============================================================================

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
IMAGE_NAME="t113-build"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.build"
MODE="${1:-build}"   # "menuconfig" o "build"

# Versión del kernel y patch (ajustar si cambia)
KERNEL_VER="6.16.9"
PATCH_DIR="$SCRIPT_DIR/linux-patch-${KERNEL_VER}"

# Direcciones de carga para uImage
LOAD_ADDR="0x41800000"
ENTRY_ADDR="0x41800000"

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
    cpio rsync kmod linux-firmware \
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
# Verificar directorios
# -----------------------------------------------------------------------------
[ -d "$PATCH_DIR" ] || error "No se encontró el directorio $PATCH_DIR"
[ -d "$SCRIPT_DIR/linux" ] || error "No se encontró el directorio linux. Ejecuta: git submodule update --init"

# -----------------------------------------------------------------------------
# Modo menuconfig (interactivo)
# -----------------------------------------------------------------------------
if [ "$MODE" = "menuconfig" ]; then
    info "Abriendo menuconfig..."
    docker run --rm -it \
        --privileged \
        -v "$SCRIPT_DIR:/work" \
        "$IMAGE_NAME" bash -c "
            set -e
            cd /work
            cp linux-patch-${KERNEL_VER}/sun8i-t113s-saxo-gateway.dts linux/arch/arm/boot/dts/allwinner/
            cp linux-patch-${KERNEL_VER}/sunxi-d1s-t113s-saxo.dtsi     linux/arch/arm/boot/dts/allwinner/
            cp linux-patch-${KERNEL_VER}/config linux/.config
            cd linux
            make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- menuconfig
        "
    info "menuconfig completado. El .config fue guardado. Ejecuta sin argumentos para compilar."
    exit 0
fi

# -----------------------------------------------------------------------------
# Compilar kernel dentro de Docker
# -----------------------------------------------------------------------------
info "Iniciando compilación del kernel Linux ${KERNEL_VER}..."

docker run --rm \
    --privileged \
    -v "$SCRIPT_DIR:/work" \
    "$IMAGE_NAME" bash -c "
        set -e
        cd /work

        echo '[1/5] Copiando archivos de patch...'
        cp linux-patch-${KERNEL_VER}/sun8i-t113s-saxo-gateway.dts linux/arch/arm/boot/dts/allwinner/
        cp linux-patch-${KERNEL_VER}/sunxi-d1s-t113s-saxo.dtsi     linux/arch/arm/boot/dts/allwinner/
        cp linux-patch-${KERNEL_VER}/config linux/.config

        cd linux

        echo '[2/5] Restaurando árbol limpio...'
        git checkout -f

        echo '[3/5] Aplicando patch...'
        patch -d . -p1 --forward < ../linux-patch-${KERNEL_VER}/0001-saxo-dtb-reference.patch || \
            echo 'Patch ya aplicado o sin cambios, continuando...'

        echo '[4/5] Deshabilitando firmware builtin problemático...'
        sed -i 's/CONFIG_EXTRA_FIRMWARE=.*/CONFIG_EXTRA_FIRMWARE=\"\"/' .config

        echo '[5/5] Compilando kernel (zImage + DTBs + módulos)...'
        make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- \
            zImage dtbs modules \
            -j\$(nproc) 2>&1

        echo ''
        echo '===================================='
        echo ' Kernel compilado exitosamente'
        echo '===================================='
        ls -lh arch/arm/boot/zImage
        ls -lh arch/arm/boot/dts/allwinner/sun8i-t113s-saxo*.dtb 2>/dev/null || true
    "

# -----------------------------------------------------------------------------
# Generar uImage desde macOS (u-boot-tools)
# -----------------------------------------------------------------------------
info "Generando uImage..."

ZIMAGE="$SCRIPT_DIR/linux/arch/arm/boot/zImage"
UIMAGE="$SCRIPT_DIR/uImage"

if [ ! -f "$ZIMAGE" ]; then
    error "zImage no encontrado en $ZIMAGE"
fi

# Usar mkimage del contenedor para evitar problemas de versión en macOS
docker run --rm \
    -v "$SCRIPT_DIR:/work" \
    "$IMAGE_NAME" bash -c "
        mkimage -A arm -O linux -T kernel -C none \
            -a ${LOAD_ADDR} -e ${ENTRY_ADDR} \
            -n 'SAXO Linux Kernel (T113-S3)' \
            -d /work/linux/arch/arm/boot/zImage \
            /work/uImage
    "

# -----------------------------------------------------------------------------
# Verificar resultados
# -----------------------------------------------------------------------------
echo ""
info "✅ Archivos generados:"
[ -f "$UIMAGE" ]  && echo "   $(ls -lh "$UIMAGE")"
[ -f "$ZIMAGE" ]  && echo "   $(ls -lh "$ZIMAGE")"
find "$SCRIPT_DIR/linux/arch/arm/boot/dts/allwinner" \
    -name "sun8i-t113s-saxo*.dtb" 2>/dev/null | \
    while read f; do echo "   $(ls -lh "$f")"; done

echo ""
info "Para flashear en la microSD ejecuta: sudo ./burn_microsd.sh"
