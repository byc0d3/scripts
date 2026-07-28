#!/bin/bash
# ==============================================================================
# Script: config_server.sh
<<<<<<< HEAD
# Descripción: Menú maestro interactivo para la suite de automatización Rocky Linux.
# Arquitectura: Lanza de forma modular los scripts individuales de infraestructura.
=======
# Descripción: Menú Maestro Monolítico para configuración de servidores.
>>>>>>> 36ed6fa (update: 28-07-2026 11:10)
# ==============================================================================
set -e

# --- Variables de Color ---
<<<<<<< HEAD
AM="\e[1;33m"  # Amarillo
AZ="\e[1;34m"  # Azul
CY="\e[1;36m"  # Cyan
RO="\e[1;31m"  # Rojo
VE="\e[1;32m"  # Verde
BL="\e[1;37m"  # Blanco
CL="\e[0m"     # Limpiar

BASE_URL="https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main"

# ==============================================================================
# NÚCLEO DEL MENÚ (Motor de Ejecución)
# ==============================================================================

# Ejecuta los scripts de forma local (si existe) o los descarga de GitHub
run_module() {
    local script_name="$1"
    
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Iniciando módulo: ${BL}${script_name}${CL}"
    echo -e "${AZ}======================================================${CL}"
    
    local TARGET_PATH="./$script_name"
    
    # Comprobar si el archivo existe localmente para entorno de desarrollo
    if [ ! -f "$TARGET_PATH" ]; then
        echo -e "${AM}Descargando última versión de $script_name desde GitHub...${CL}"
        TARGET_PATH="/tmp/$script_name"
        curl -fsSL "${BASE_URL}/${script_name}?$(date +%s)" -o "$TARGET_PATH"
    else
        echo -e "${CY}Ejecutando versión local del script...${CL}"
    fi

    echo -e "------------------------------------------------------\n"
    
    # zsh.sh no requiere sudo inicial
    if [[ "$script_name" == "zsh.sh" ]]; then
        bash "$TARGET_PATH"
    else
        sudo bash "$TARGET_PATH"
    fi
    
    echo -e "\n${VE}=== Ejecución de módulo finalizada ===${CL}"
    read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú..."
}

# ==============================================================================
# SUBMENÚS POR CATEGORÍA
# ==============================================================================

menu_sistema() {
    while true; do
        clear
        echo -e "${AZ}=========================================${CL}"
        echo -e "${VE}   🛠️  CONFIGURACIÓN DEL SISTEMA${CL}"
        echo -e "${AZ}=========================================${CL}"
        echo -e "${CY} 1)${CL} Servidor Base (Paquetes, SELinux, Limits)"
        echo -e "${CY} 2)${CL} Terminal Avanzada Zsh (Oh-My-Zsh)"
        echo -e "${RO} v)${CL} Volver al Menú Principal"
        echo
        read -n 1 -p "Seleccione una opción: " opc
        echo
        case $opc in
            1) run_module "server.sh" ;;
            2) run_module "zsh.sh" ;;
            v|V) return ;;
            *) echo -e "${RO}Opción inválida.${CL}"; sleep 1 ;;
        esac
    done
}

menu_web() {
    while true; do
        clear
        echo -e "${AZ}=========================================${CL}"
        echo -e "${VE}   🌐  SERVICIOS WEB Y APLICACIONES${CL}"
        echo -e "${AZ}=========================================${CL}"
        echo -e "${CY} 1)${CL} Instalar Apache / VirtualHost (Próximamente)"
        echo -e "${CY} 2)${CL} Instalar PHP (Remi Repo)"
        echo -e "${CY} 3)${CL} Instalar Composer (Próximamente)"
        echo -e "${RO} v)${CL} Volver al Menú Principal"
        echo
        read -n 1 -p "Seleccione una opción: " opc
        echo
        case $opc in
            1) 
                echo -e "\n${AM}Nota: Debes extraer el código de Apache a un archivo apache.sh${CL}"
                sleep 2 
                ;;
            2) 
                read -p "Ingrese versión de PHP deseada (Ej: 8.1, 8.2, 8.3) [8.3]: " phpver
                export PHP_VERSION="${phpver:-8.3}"
                run_module "php.sh" 
                ;;
            3) 
                echo -e "\n${AM}Nota: Debes extraer el código de Composer a un archivo composer.sh${CL}"
                sleep 2 
                ;;
            v|V) return ;;
            *) echo -e "${RO}Opción inválida.${CL}"; sleep 1 ;;
        esac
    done
}

menu_db() {
    while true; do
        clear
        echo -e "${AZ}=========================================${CL}"
        echo -e "${VE}   🗄️  BASES DE DATOS${CL}"
        echo -e "${AZ}=========================================${CL}"
        echo -e "${CY} 1)${CL} Instalar MariaDB (Última versión)"
        echo -e "${CY} 2)${CL} Instalar PostgreSQL (Versión 18)"
        echo -e "${RO} v)${CL} Volver al Menú Principal"
        echo
        read -n 1 -p "Seleccione una opción: " opc
        echo
        case $opc in
            1) run_module "mariadb.sh" ;;
            2) run_module "postgres.sh" ;;
            v|V) return ;;
            *) echo -e "${RO}Opción inválida.${CL}"; sleep 1 ;;
        esac
    done
}

menu_redes() {
    while true; do
        clear
        echo -e "${AZ}=========================================${CL}"
        echo -e "${VE}   🔌  REDES Y COMUNICACIONES${CL}"
        echo -e "${AZ}=========================================${CL}"
        echo -e "${CY} 1)${CL} Configurar Interfaz de Red Estática / PBR"
        echo -e "${RO} v)${CL} Volver al Menú Principal"
        echo
        read -n 1 -p "Seleccione una opción: " opc
        echo
        case $opc in
            1) run_module "set_network.sh" ;;
            v|V) return ;;
            *) echo -e "${RO}Opción inválida.${CL}"; sleep 1 ;;
        esac
    done
}

menu_almacenamiento() {
    while true; do
        clear
        echo -e "${AZ}=========================================${CL}"
        echo -e "${VE}   💾  ALMACENAMIENTO LVM${CL}"
        echo -e "${AZ}=========================================${CL}"
        echo -e "${CY} 1)${CL} Añadir disco totalmente nuevo a LVM"
        echo -e "${CY} 2)${CL} Redimensionar un disco existente"
        echo -e "${RO} v)${CL} Volver al Menú Principal"
        echo
        read -n 1 -p "Seleccione una opción: " opc
        echo
        case $opc in
            1) run_module "extend_volume.sh" ;;
            2) run_module "resize_volume.sh" ;;
            v|V) return ;;
            *) echo -e "${RO}Opción inválida.${CL}"; sleep 1 ;;
        esac
    done
=======
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
>>>>>>> 36ed6fa (update: 28-07-2026 11:10)
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
<<<<<<< HEAD
        echo -e "${CY} 1)${CL} 🛠️  Sistema Base"
        echo -e "${CY} 2)${CL} 🌐  Servicios Web (PHP, Apache)"
        echo -e "${CY} 3)${CL} 🗄️  Bases de Datos (MariaDB, PostgreSQL)"
        echo -e "${CY} 4)${CL} 🔌  Redes (Interfaces, PBR)"
        echo -e "${CY} 5)${CL} 💾  Almacenamiento (LVM, Discos)"
=======
        echo -e "${CY} 1)${CL} 🛠️  Configuraciones Iniciales del S.O (Server Base)"
>>>>>>> 36ed6fa (update: 28-07-2026 11:10)
        echo
        echo -e "${RO} s)${CL} Salir del Asistente"
        echo -e "${AZ}==================================================${CL}"
<<<<<<< HEAD
        
<<<<<<< HEAD
        read -n 1 -p "Seleccione una categoría: " opc
        echo
        
        case $opc in
            1) menu_sistema ;;
            2) menu_web ;;
            3) menu_db ;;
            4) menu_redes ;;
            5) menu_almacenamiento ;;
=======
=======

>>>>>>> 7e2a83a (update: 28-07-2026 11:10)
        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_server ;;
>>>>>>> 36ed6fa (update: 28-07-2026 11:10)
            s|S)
                echo -e "\n${VE}¡Hasta pronto!${CL}"
                exit 0
                ;;
            *)
<<<<<<< HEAD
                echo -e "${RO}Opción inválida.${CL}"
                sleep 1
=======
                opcion_invalida
>>>>>>> 36ed6fa (update: 28-07-2026 11:10)
                ;;
        esac
    done
}

# Iniciar aplicación
menu_principal
