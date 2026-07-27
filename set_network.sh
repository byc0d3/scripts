#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: set_network.sh
# Descripción: Configuración avanzada de red en Rocky Linux mediante nmcli.
#              Configura IP Estática, Gateway y Policy Based Routing (PBR)
#              para evitar enrutamiento asimétrico en múltiples interfaces.
#
# Pasos generales:
#   1. Validación de root.
#   2. Recopilación de parámetros (interactiva o por variables de entorno).
#   3. Eliminación de perfil previo para evitar conflictos.
#   4. Creación de nueva conexión con IP estática y Gateway.
#   5. Configuración de reglas de enrutamiento en tabla específica.
#   6. Activación de la interfaz.
#
# Uso:
#   # Interactivo:
#   curl -fsSL "URL" -o /tmp/set_network.sh && sudo bash /tmp/set_network.sh
#
#   # No interactivo:
#   sudo DEVICE="ens224" IP="10.31.196.49" PREFIX="25" GW="10.31.196.1" bash /tmp/set_network.sh
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
    if [[ -z "$GW" ]]; then
        read -p "Gateway (ej. 10.31.196.1): " GW
    fi
    
    # Validación de variables vacías
    if [[ -z "$DEVICE" || -z "$IP" || -z "$PREFIX" || -z "$GW" ]]; then
        echo "❌ Error: Todos los parámetros de red son obligatorios." >&2
        exit 1
    fi
    
    echo " ✓ Configuración a aplicar en: $DEVICE ($IP/$PREFIX, GW: $GW, Tabla: $TABLE)"
}

configure_profile() {
    echo "[2/4] Eliminando perfil anterior y creando nueva conexión..."
    
    # Eliminamos el perfil previo si existe para evitar conflictos (el "|| true" evita que falle si no existe)
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
    echo "[3/4] Configurando enrutamiento y Policy Based Routing (PBR)..."
    
    # Gateway y enrutamiento a la tabla específica
    nmcli con mod "$DEVICE" ipv4.gateway "$GW"
    nmcli con mod "$DEVICE" ipv4.route-table "$TABLE"
    
    # Limpiamos reglas previas y aplicamos las nuevas con prioridad 5
    nmcli con mod "$DEVICE" ipv4.routing-rules ""
    nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 iif ${DEVICE} table ${TABLE}"
    nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 from ${IP} table ${TABLE}"
    
    echo " ✓ Reglas PBR aplicadas (Tabla: $TABLE, Prioridad: 5)."
}

apply_network() {
    echo "[4/4] Levantando interfaz de red..."
    # Levantamos la conexión (esto aplica inmediatamente los cambios a nivel sistema)
    nmcli con up "$DEVICE" > /dev/null
    
    echo "--------------------------------------------------"
    echo "✅ CONFIGURACIÓN DE RED COMPLETADA"
    echo "--------------------------------------------------"
    echo "Dispositivo : $DEVICE"
    echo "IP asignada : $IP/$PREFIX"
    echo "Gateway     : $GW"
    echo "Tabla (PBR) : $TABLE"
    echo "--------------------------------------------------"
}

main() {
    echo "--- SYSADMIN: Network Setup (PBR & Static IP) ---"
    
    check_root
    gather_parameters
    configure_profile
    configure_routing
    apply_network
}

# Iniciar la ejecución
main
