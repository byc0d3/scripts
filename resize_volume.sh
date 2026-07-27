#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: resize_volume.sh
# Descripción: Automatiza la expansión de un Volumen Lógico (LVM) cuando el
#              disco subyacente ha sido ampliado desde el hipervisor (VMware/AWS).
#              Detecta automáticamente si el LVM vive en un disco crudo o en
#              una partición (usando growpart) y redimensiona todo en cascada.
#
# Pasos generales:
#   1. Recopilación de la partición/disco ampliado y la ruta de montaje.
#   2. Re-escaneo del bus SCSI del disco para detectar el nuevo espacio.
#   3. Uso automático de 'growpart' si el PV es una partición.
#   4. Ejecución de pvresize para actualizar LVM sobre el nuevo espacio.
#   5. Ejecución de lvextend con auto-resize del File System (xfs/ext4).
#
# Uso:
#   # Interactivo:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/resize_volume.sh?$(date +%s)" -o /tmp/resize_volume.sh && sudo bash /tmp/resize_volume.sh
#
#   # No interactivo:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/resize_volume.sh?$(date +%s)" -o /tmp/resize_volume.sh && sudo TARGET_DISK="/dev/sxx" TARGET_PATH="/directory" bash /tmp/resize_volume.sh
# ==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

gather_parameters() {
    echo "[1/5] Recopilando parámetros del sistema..."

    if [[ -n "$TARGET_PV" ]]; then
        PV_DISK="$TARGET_PV"
    else
        read -p "Físico ampliado (ej. /dev/sda2 o /dev/sdb): " PV_DISK
    fi

    if [[ -n "$TARGET_PATH" ]]; then
        RUTA="$TARGET_PATH"
    else
        read -p "Ruta a extender (ej. / o /home): " RUTA
    fi

    if [[ -z "$PV_DISK" || -z "$RUTA" ]]; then
        echo "❌ Error: El disco y la ruta son obligatorios." >&2
        exit 1
    fi

    if [[ ! -b "$PV_DISK" ]]; then
        echo "❌ Error: '$PV_DISK' no existe o no es un dispositivo de bloques." >&2
        exit 1
    fi

    if [[ ! -d "$RUTA" ]]; then
        echo "❌ Error: La ruta '$RUTA' no existe." >&2
        exit 1
    fi
}

analyze_and_grow() {
    echo "[2/5] Analizando topología física del disco..."

    # Extraemos el nombre del disco padre (PKNAME). Ej: Si PV es /dev/sda2, PKNAME es sda
    PKNAME=$(lsblk -no PKNAME "$PV_DISK" | tr -d ' ' | head -n 1)

    if [[ -n "$PKNAME" ]]; then
        PARENT_DISK="/dev/$PKNAME"
        PART_NUM=$(lsblk -no PARTN "$PV_DISK" | tr -d ' ' | head -n 1)
        echo " ✓ Detectado LVM sobre Partición (Disco Padre: $PARENT_DISK, Partición: $PART_NUM)"

        echo "[3/5] Solicitando rescan al Kernel e inyectando espacio a la partición..."
        echo 1 > "/sys/class/block/${PKNAME}/device/rescan" 2>/dev/null || true

        # Verificar que la herramienta growpart exista
        if ! command -v growpart &> /dev/null; then
            echo "   -> Instalando 'cloud-utils-growpart'..."
            dnf install -y cloud-utils-growpart > /dev/null 2>&1
        fi

        # Growpart puede fallar (código 1) si la partición ya estaba crecida, usamos || true
        echo "   -> Ejecutando growpart..."
        growpart "$PARENT_DISK" "$PART_NUM" > /dev/null 2>&1 || echo "   -> (Info: La partición ya estaba extendida o no hubo cambios físicos)."

    else
        echo " ✓ Detectado LVM sobre Disco Crudo (Sin particiones)."
        echo "[3/5] Solicitando rescan al Kernel..."
        DISK_NAME=$(basename "$PV_DISK")
        echo 1 > "/sys/class/block/${DISK_NAME}/device/rescan" 2>/dev/null || true
    fi
}

resize_lvm() {
    echo "[4/5] Actualizando estructuras LVM y File System..."

    echo " -> Actualizando Physical Volume (pvresize)..."
    pvresize "$PV_DISK" > /dev/null

    # Extraer el volumen lógico asociado a la ruta
    LV_PATH=$(df "$RUTA" --output=source | tail -1)

    if ! lvs "$LV_PATH" > /dev/null 2>&1; then
        echo "❌ Error: '$LV_PATH' no parece ser un Volumen Lógico." >&2
        exit 1
    fi

    echo " -> Extendiendo Logical Volume y File System en cascada..."
    lvextend -l +100%FREE "$LV_PATH" -r > /dev/null
}

cleanup() {
    echo "[5/5] Tareas finales..."
    echo "--------------------------------------------------"
    echo "✅ REDIMENSIÓN DE VOLUMEN COMPLETADA"
    echo "--------------------------------------------------"
    echo "Disco/Partición : $PV_DISK"
    echo "Ruta ampliada   : $RUTA"
    echo "Estado final    :"
    df -h "$RUTA" | awk 'NR==2{print "  Tamaño: "$2" | Usado: "$3" | Disp: "$4" ("$5")"}'
    echo "--------------------------------------------------"
}

main() {
    echo "--- SYSADMIN: LVM Hot Resize (Hypervisor Grow) ---"

    check_root
    gather_parameters
    analyze_and_grow
    resize_lvm
    cleanup
}

# Iniciar la ejecución
main
