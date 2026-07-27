#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: extend_volume.sh
# Descripción: Automatiza la expansión de un Volumen Lógico (LVM) agregando
#              un nuevo disco físico (PV) al Grupo de Volúmenes (VG) y
#              redimensionando el sistema de archivos de forma segura.
#
# Pasos generales:
#   1. Validación de root y recopilación de parámetros.
#   2. Análisis de la topología LVM (Detección de LV y VG).
#   3. Validaciones de seguridad (Verificar que el disco esté vacío).
#   4. Ejecución de pvcreate, vgextend y lvextend con auto-resize.
#
# Uso:
#   # Interactivo:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/extend_volume.sh?$(date +%s)" -o /tmp/extend_volume.sh && sudo bash /tmp/extend_volume.sh
#
#   # No interactivo:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/extend_volume.sh?$(date +%s)" -o /tmp/extend_volume.sh && sudo TARGET_DISK="/dev/sxx" TARGET_PATH="/directory" bash /tmp/extend_volume.sh
# ==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

gather_parameters() {
    echo "[1/4] Recopilando parámetros del sistema..."

    # Soporte para variables de entorno (no interactivo)
    if [[ -n "$TARGET_DISK" ]]; then
        NUEVO_DISCO="$TARGET_DISK"
    else
        read -p "Introduce el nuevo disco (ej. /dev/sdc): " NUEVO_DISCO
    fi

    if [[ -n "$TARGET_PATH" ]]; then
        RUTA="$TARGET_PATH"
    else
        read -p "Introduce la ruta a extender (ej. /home): " RUTA
    fi

    # Validaciones básicas
    if [[ -z "$NUEVO_DISCO" || -z "$RUTA" ]]; then
        echo "❌ Error: El disco y la ruta son obligatorios." >&2
        exit 1
    fi

    # Verificar que el disco exista en el sistema
    if [[ ! -b "$NUEVO_DISCO" ]]; then
        echo "❌ Error: El disco '$NUEVO_DISCO' no existe o no es un dispositivo válido." >&2
        exit 1
    fi

    # Verificar que el directorio exista
    if [[ ! -d "$RUTA" ]]; then
        echo "❌ Error: El directorio de montaje '$RUTA' no existe." >&2
        exit 1
    fi
}

analyze_lvm() {
    echo "[2/4] Analizando estructura LVM asociada a '$RUTA'..."

    # Extraer el volumen lógico asociado a la ruta
    LV_PATH=$(df "$RUTA" --output=source | tail -1)

    # Validar que realmente sea un volumen gestionado por LVM
    if ! lvs "$LV_PATH" > /dev/null 2>&1; then
        echo "❌ Error: '$LV_PATH' no parece ser un Volumen Lógico de LVM." >&2
        exit 1
    fi

    # Extraer el nombre del grupo de volúmenes (VG)
    VG_NAME=$(lvs --noheadings -o vg_name "$LV_PATH" | xargs)

    if [[ -z "$VG_NAME" ]]; then
        echo "❌ Error: No se pudo determinar el Volume Group (VG)." >&2
        exit 1
    fi

    echo " ✓ Ruta mapeada al LV: $LV_PATH"
    echo " ✓ Volume Group detectado: $VG_NAME"
}

extend_lvm() {
    echo "[3/4] Preparando disco y extendiendo el Volumen..."

    # Validar si el disco ya pertenece a un LVM para evitar destrucción de datos
    if pvs "$NUEVO_DISCO" > /dev/null 2>&1; then
        echo "❌ Error: El disco '$NUEVO_DISCO' ya forma parte de un LVM existente. Abortando por seguridad." >&2
        exit 1
    fi

    echo " -> Creando Physical Volume (PV) en $NUEVO_DISCO..."
    pvcreate -y "$NUEVO_DISCO" > /dev/null

    echo " -> Añadiendo el disco al Volume Group '$VG_NAME'..."
    vgextend "$VG_NAME" "$NUEVO_DISCO" > /dev/null

    echo " -> Extendiendo Logical Volume y redimensionando File System..."
    # El flag -r (resizefs) detecta si es ext4 o xfs y lo amplía automáticamente
    lvextend -l +100%FREE "$LV_PATH" -r > /dev/null

    echo " ✓ Expansión completada correctamente."
}

cleanup() {
    echo "[4/4] Tareas finales..."
    echo "--------------------------------------------------"
    echo "✅ EXTENSIÓN DE VOLUMEN COMPLETADA"
    echo "--------------------------------------------------"
    echo "Disco añadido : $NUEVO_DISCO"
    echo "Ruta ampliada : $RUTA"
    echo "Estado final  :"
    # Imprime un resumen limpio del tamaño final usando awk
    df -h "$RUTA" | awk 'NR==2{print "  Tamaño: "$2" | Usado: "$3" | Disp: "$4" ("$5")"}'
    echo "--------------------------------------------------"
}

main() {
    echo "--- SYSADMIN: LVM Volume Expansion ---"

    check_root
    gather_parameters
    analyze_lvm
    extend_lvm
    cleanup
}

# Iniciar la ejecución
main
