#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: set_network.sh
# Descripción: Configuración avanzada de red en Rocky Linux mediante nmcli.
#              Configura IP Estática y opcionalmente Gateway y Policy Based
#              Routing (PBR) para evitar enrutamiento asimétrico.
#
# Pasos generales:
#   1. Validación de root.
#   2. Recopilación de parámetros (interactiva o por variables de entorno).
#   3. Eliminación de perfil previo para evitar conflictos.
#   4. Creación de nueva conexión con IP estática.
#   5. Configuración de Gateway y reglas de PBR (solo si se especifica Gateway).
#   6. Activación de la interfaz.
#
# Uso:
#   # Interactivo:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/set_network.sh?$(date +%s)" -o /tmp/set_network.sh && sudo bash /tmp/set_network.sh
#
#   # No interactivo (Con Gateway):
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/set_network.sh?$(date +%s)" -o /tmp/set_network.sh && sudo DEVICE="ens224" IP="192.169.1.111" PREFIX="25" GW="192.168.1.1" bash /tmp/set_network.sh
#
#   # No interactivo (Sin Gateway - Red local):
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/set_network.sh?$(date +%s)" -o /tmp/set_network.sh && sudo DEVICE="ens256" IP="192.169.1.111" PREFIX="32" GW="192.168.1.1" bash /tmp/set_network.sh
# ==============================================================================

# Variables globales (por defecto o desde entorno)
TABLE=${TABLE:-5000}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

gather_parameters() {
    echo "[1/4] Recopilando parámetros de red..."

    # Si no vienen por variables de entorno, los pedimos interactivamente
    if [[ -z "$DEVICE" ]]; then
        read -p "Nombre del dispositivo (ej. ens224): " DEVICE
    fi
    if [[ -z "$IP" ]]; then
        read -p "Dirección IP (ej. 10.31.196.49): " IP
    fi
    if [[ -z "$PREFIX" ]]; then
        read -p "Máscara/Prefijo (ej. 25): " PREFIX
    fi

    # El GW ahora es opcional. Usamos una comprobación especial para saber si
    # se pasó como variable vacía (GW="") o si simplemente no se pasó.
    if [[ -z "${GW+x}" ]]; then
        read -p "Gateway (Dejar en blanco si es interfaz local/no enrutada): " GW
    fi

    # Validación de variables obligatorias
    if [[ -z "$DEVICE" || -z "$IP" || -z "$PREFIX" ]]; then
        echo "❌ Error: Dispositivo, IP y Prefijo son obligatorios." >&2
        exit 1
    fi

    if [[ -n "$GW" ]]; then
        echo " ✓ Configuración a aplicar: $DEVICE ($IP/$PREFIX, GW: $GW, Tabla PBR: $TABLE)"
    else
        echo " ✓ Configuración a aplicar: $DEVICE ($IP/$PREFIX, Sin Gateway / Red Local)"
    fi
}

configure_profile() {
    echo "[2/4] Eliminando perfil anterior y creando nueva conexión..."

    # Eliminamos el perfil previo si existe para evitar conflictos
    nmcli con delete "$DEVICE" > /dev/null 2>&1 || true

    # Creamos la nueva conexión con ip estática
    nmcli con add con-name "$DEVICE" type ethernet ifname "$DEVICE" \
        ipv4.method manual \
        ipv4.addresses "${IP}/${PREFIX}" \
        ipv4.never-default yes \
        ipv6.method disabled > /dev/null

    echo " ✓ Perfil de red '$DEVICE' creado con éxito."
}

configure_routing() {
    # Si el usuario proporcionó un Gateway, aplicamos PBR
    if [[ -n "$GW" ]]; then
        echo "[3/4] Configurando enrutamiento y Policy Based Routing (PBR)..."

        # Gateway y enrutamiento a la tabla específica
        nmcli con mod "$DEVICE" ipv4.gateway "$GW"
        nmcli con mod "$DEVICE" ipv4.route-table "$TABLE"

        # Limpiamos reglas previas y aplicamos las nuevas con prioridad 5
        nmcli con mod "$DEVICE" ipv4.routing-rules ""
        nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 iif ${DEVICE} table ${TABLE}"
        nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 from ${IP} table ${TABLE}"

        echo " ✓ Reglas PBR aplicadas (Tabla: $TABLE, Prioridad: 5)."
    else
        # Si no hay Gateway, la interfaz solo sirve para la red directamente conectada
        echo "[3/4] Interfaz no enrutada. Omitiendo configuración de Gateway y PBR..."
    fi
}

apply_network() {
    echo "[4/4] Levantando interfaz de red..."
    # Levantamos la conexión
    nmcli con up "$DEVICE" > /dev/null

    echo "--------------------------------------------------"
    echo "✅ CONFIGURACIÓN DE RED COMPLETADA"
    echo "--------------------------------------------------"
    echo "Dispositivo : $DEVICE"
    echo "IP asignada : $IP/$PREFIX"
    if [[ -n "$GW" ]]; then
        echo "Gateway     : $GW"
        echo "Tabla (PBR) : $TABLE"
    else
        echo "Gateway     : Ninguno (Red Local interna)"
    fi
    echo "--------------------------------------------------"
}

main() {
    echo "--- SYSADMIN: Network Setup ---"

    check_root
    gather_parameters
    configure_profile
    configure_routing
    apply_network
}

# Iniciar la ejecución
main
