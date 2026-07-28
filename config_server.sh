#!/bin/bash
# ==============================================================================
# Script: config_server.sh
# Descripción: Menú Maestro Monolítico para configuración de servidores.
# ==============================================================================
set -e

# --- Variables de Color ---
AM="\e[1;33m"
AZ="\e[1;34m"
CY="\e[1;36m"
RO="\e[1;31m"
VE="\e[1;32m"
BL="\e[1;37m"
CL="\e[0m"

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RO}❌ Este script debe ejecutarse como root.${CL}" >&2
        exit 1
    fi
}

proceso_finalizado() {
	echo
	echo -e "${AM}Proceso culminado satifactoriamente !!!.${CL}"
	echo
}

proceso_cancelado(){
	echo
	echo -e "${AM}Proceso cancelado !!!${CL}"
	echo
	read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

opcion_invalida(){
	echo -e -n "${RO}* Opción inválida.${CL} Por favor, seleccione una opción válida."
	sleep 1
}

# ==============================================================================
# MÓDULOS DE CONFIGURACIÓN
# ==============================================================================

modulo_server() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Configuración Inicial del Sistema Base${CL}"
    echo -e "${AZ}======================================================${CL}"
    
    echo -e -n "¿Deseas continuar con el proceso? Escribe ${RO}yes${CL} para continuar, u oprima enter para cancelar: "
    read confirmar
    
    if [ "$confirmar" == "yes" ]; then
        check_root
        
        ROCKY_VERSION=$(rpm -E %rhel)
        echo -e "\n📌 Versión detectada: Rocky Linux $ROCKY_VERSION"
        
        echo "[1/10] Configurando EPEL y repositorio de desarrollo (CRB)..."
        dnf config-manager --set-enabled crb > /dev/null 2>&1 || true
        dnf install -y epel-release > /dev/null 2>&1
        
        echo "[2/10] Actualizando el sistema..."
        dnf upgrade -y > /dev/null
        
        echo "[3/10] Instalando herramientas de administración..."
        dnf install -y dnf-utils nano vim tree wget btop traceroute iproute \
            telnet nmap tcpdump iputils unzip tar rsync util-linux-user \
            nfs-utils bind-utils chrony > /dev/null 2>&1
        
        echo
        read -p "Introduce el nombre del servidor (Hostname): " TARGET_HOSTNAME
        echo
        
        echo "[4/10] Configurando hostname y zona horaria..."
        hostnamectl set-hostname "${TARGET_HOSTNAME:-server-app01}"
        timedatectl set-timezone America/Caracas
        systemctl enable --now chronyd > /dev/null 2>&1
        
        echo "[5/10] Ajustando SELinux a modo permisivo (solo para pruebas)..."
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
        setenforce 0 || true
        
        echo "[6/10] Configurando historial con timestamp..."
        cat > /etc/profile.d/hist_timestamp.sh << 'EOF'
export HISTTIMEFORMAT='%d-%m-%Y %H:%M:%S '
EOF
        chmod 644 /etc/profile.d/hist_timestamp.sh
        
        echo "[7/10] Agregando repositorios RPM Fusion..."
        dnf install -y "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-${ROCKY_VERSION}.noarch.rpm" > /dev/null 2>&1 || true
        dnf install -y "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-${ROCKY_VERSION}.noarch.rpm" > /dev/null 2>&1 || true
        
        echo "[8/10] Instalando y configurando Fail2Ban..."
        dnf install -y fail2ban > /dev/null 2>&1
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
        systemctl enable --now fail2ban > /dev/null 2>&1
        
        echo "[9/10] Aplicando tuning del sistema (sysctl y limits)..."
        cat > /etc/security/limits.d/99-custom-limits.conf << 'EOF'
* soft nofile 100000
* hard nofile 100000
root soft nofile 100000
root hard nofile 100000
EOF
        cat > /etc/sysctl.d/99-custom-sysctl.conf << 'EOF'
fs.file-max = 100000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
EOF
        sysctl --system > /dev/null 2>&1
        
        echo "[10/10] Limpiando paquetes innecesarios y cache..."
        dnf autoremove -y > /dev/null 2>&1
        dnf clean all > /dev/null 2>&1
        
        proceso_finalizado
        
        echo "⚠️  SELinux está en modo permisivo. Si es producción, cambie a enforcing."
        echo -e "${RO}🔄 Se recomienda reiniciar el sistema para aplicar todos los cambios de SELinux y Hostname.${CL}"
        echo
        read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú principal..."
    else
        proceso_cancelado
    fi
}

# ==============================================================================
# MENÚ PRINCIPAL
# ==============================================================================

menu_principal() {
    while true; do
        clear
        echo -e "${AZ}██████╗ ██╗   ██╗ ██████╗ ██████╗ ██████╗ ██████╗${CL}"
        echo -e "${AZ}██╔══██╗╚██╗ ██╔╝██╔════╝██╔═████╗██╔══██╗╚════██╗${CL}"
        echo -e "${AZ}██████╔╝ ╚████╔╝ ██║     ██║██╔██║██║  ██║ █████╔╝${CL}"
        echo -e "${AZ}██╔══██╗  ╚██╔╝  ██║     ████╔╝██║██║  ██║ ╚═══██╗${CL}"
        echo -e "${AZ}██████╔╝   ██║   ╚██████╗╚██████╔╝██████╔╝██████╔╝${CL}"
        echo -e "${AZ}╚═════╝    ╚═╝    ╚═════╝ ╚═════╝ ╚═════╝ ╚═════╝ ${CL}"
        echo -e "${BL}          ROCKY LINUX AUTOMATION SUITE${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} 🛠️  Configuraciones Iniciales del S.O (Server Base)"
        echo
        echo -e "${RO} s)${CL} Salir del Asistente"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una opción: " opc
        echo
        
        case $opc in
            1) modulo_server ;;
            s|S)
                echo -e "\n${VE}¡Hasta pronto!${CL}"
                exit 0
                ;;
            *)
                opcion_invalida
                ;;
        esac
    done
}

# Iniciar aplicación
menu_principal
