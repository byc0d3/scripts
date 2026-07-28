#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: server.sh
# Descripción: Script de aprovisionamiento base (bootstrap) para servidores
#              nuevos basados en Rocky Linux (soporta v9 y v10).
#              Prepara el entorno con configuraciones esenciales de sistema,
#              seguridad y repositorios.
#
# Pasos generales que realiza:
#   1. Validación de permisos (root) y detección de versión del SO.
#   2. Habilitación de repositorios extra (EPEL, CRB/Powertools, RPM Fusion).
#   3. Actualización completa del sistema operativo.
#   4. Instalación de herramientas base de red y administración.
#   5. Configuración del Hostname (por variable de entorno) y Zona Horaria.
#   6. Ajustes de seguridad: SELinux en permisivo e instalación de Fail2Ban para SSH.
#   7. Mejoras de entorno: Historial de bash con fecha y hora.
#   8. Tuning de rendimiento: Incremento de límites de red y descriptores (sysctl/limits).
#   9. Limpieza de paquetes huérfanos/caché y reinicio automático del servidor.
#
# Uso:
# curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/main/server.sh?$(date +%s)" -o /tmp/server.sh && sudo HOSTNAME="mi-server" bash /tmp/server.sh
# ==============================================================================

# Configuración por defecto
TARGET_HOSTNAME="${HOSTNAME:-server-app01-pro}"

# Verificar que se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

detect_version() {
    ROCKY_VERSION=$(rpm -E %rhel)
    echo "📌 Versión detectada: Rocky Linux $ROCKY_VERSION"
    
    if [[ "$ROCKY_VERSION" -ne 9 && "$ROCKY_VERSION" -ne 10 ]]; then
        echo "❌ Error: Versión no soportada. Este script requiere Rocky Linux 9 o 10." >&2
        exit 1
    fi
}

setup_repos() {
    echo "[1/10] Configurando EPEL y repositorio de desarrollo (CRB)..."
    dnf config-manager --set-enabled crb
    dnf install -y epel-release
}

update_system() {
    echo "[2/10] Actualizando el sistema..."
    dnf upgrade -y
}

install_packages() {
    echo "[3/10] Instalando herramientas de administración..."
    dnf install -y dnf-utils nano vim tree wget btop traceroute iproute \
        telnet nmap tcpdump iputils unzip tar rsync util-linux-user \
        nfs-utils bind-utils chrony
}

configure_system() {
    echo "[4/10] Configurando hostname y zona horaria..."
    hostnamectl set-hostname "$TARGET_HOSTNAME"
    timedatectl set-timezone America/Caracas
    systemctl enable --now chronyd
}

configure_selinux() {
    echo "[5/10] Ajustando SELinux a modo permisivo (solo para pruebas)..."
    sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    # El uso de '|| true' previene que el script aborte si SELinux ya está deshabilitado
    setenforce 0 || true
}

configure_history() {
    echo "[6/10] Configurando historial con timestamp..."
    cat > /etc/profile.d/hist_timestamp.sh << 'EOF'
export HISTTIMEFORMAT='%d-%m-%Y %H:%M:%S '
EOF
    chmod 644 /etc/profile.d/hist_timestamp.sh
}

add_rpm_fusion() {
    echo "[7/10] Agregando repositorios RPM Fusion..."
    dnf install -y "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${ROCKY_VERSION}.noarch.rpm"
    dnf install -y "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${ROCKY_VERSION}.noarch.rpm"
}

configure_fail2ban() {
    echo "[8/10] Instalando y configurando Fail2Ban..."
    dnf install -y fail2ban

    # Crear configuración local para SSH
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF

    systemctl enable --now fail2ban
}

configure_sysctl() {
    echo "[9/10] Aplicando tuning del sistema (sysctl y limits)..."

    # Tuning de file descriptors y usuarios (limits.conf)
    cat > /etc/security/limits.d/99-custom-limits.conf << 'EOF'
* soft nofile 100000
* hard nofile 100000
root soft nofile 100000
root hard nofile 100000
EOF

    # Tuning de sysctl (red y file descriptors globales)
    cat > /etc/sysctl.d/99-custom-sysctl.conf << 'EOF'
fs.file-max = 100000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
EOF
    # Aplicar los cambios sin mostrar toda la salida
    sysctl --system > /dev/null
}

cleanup_system() {
    echo "[10/10] Limpiando paquetes innecesarios y cache..."
    # Elimina dependencias que ya no se usan
    dnf autoremove -y
    # Limpia el cache de dnf
    dnf clean all
}

main() {
    echo "--- Iniciando Preparación del Sistema (Rocky Linux) ---"

    check_root
    detect_version
    setup_repos
    update_system
    install_packages
    configure_system
    configure_selinux
    configure_history
    add_rpm_fusion
    configure_fail2ban
    configure_sysctl
    cleanup_system

    echo "--------------------------------------------------"
    echo "✅ Proceso finalizado correctamente."
    echo "⚠️  SELinux está en modo permisivo. Si es producción, cambie a enforcing."
    echo "🔄 El sistema se reiniciará en 10 segundos. Presione Ctrl+C para cancelar."
    echo "--------------------------------------------------"
    
    echo "🗑️ Eliminando instalador..."
    rm -f -- "$0" 2>/dev/null || true
    
    sleep 10
    reboot
}

# Iniciar la ejecución
main
