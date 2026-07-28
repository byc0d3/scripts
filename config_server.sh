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
# MÓDULO 1: SERVER BASE
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
        echo -e "${RO}🔄 El sistema se reiniciará en 10 segundos para aplicar los cambios de SELinux y Hostname.${CL}"
        echo "Presione Ctrl+C para cancelar el reinicio."
        echo
        sleep 10
        reboot
    else
        proceso_cancelado
    fi
}

# ==============================================================================
# MÓDULOS DE BASES DE DATOS (MARIADB)
# ==============================================================================

modulo_db_mariadb_instalar() {
    clear
    if rpm -qa | grep -qiE "mariadb.*-server|mysql.*-server" || [ -d "/var/lib/mysql" ]; then
        echo -e "${AM}Ya existe una instalación previa de MariaDB o MySQL.${CL}"
        echo "Abortando para proteger la integridad de los datos existentes."
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Instalar y Securizar MariaDB${CL}"
    echo -e "${AZ}======================================================${CL}"
    echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        ROCKY_VERSION=$(rpm -E %rhel)
        
        echo "[1/8] Detectando última versión estable desde la API de MariaDB..."
        MDB_V=$(curl -sS https://downloads.mariadb.org/rest-api/mariadb/ | jq -r '.major_releases[] | select(.release_status=="Stable") | .release_id' | sort -V | tail -n 1)
        if [[ -z "$MDB_V" ]]; then
            echo "❌ Error al detectar versión. Revise su conexión o asegúrese de que 'jq' esté instalado." >&2
            exit 1
        fi
        echo " ✓ Última estable detectada: $MDB_V"
        
        echo "[2/8] Configurando repositorio oficial e instalando MariaDB $MDB_V..."
        cat > /etc/yum.repos.d/mariadb.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/${MDB_V}/rhel/\$releasever/\$basearch
gpgkey = https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF
        dnf -qy module disable mariadb || true
        dnf install -y MariaDB-server MariaDB-client > /dev/null

        echo "[3/8] Configurando parámetros de red..."
        local MDB_CONF="/etc/my.cnf.d/server.cnf"
        if [ -f "$MDB_CONF" ]; then
            if ! grep -qE "^bind-address" "$MDB_CONF"; then
                if grep -q "^\[mariadb\]" "$MDB_CONF"; then
                    sed -i '/^\[mariadb\]/a bind-address = 0.0.0.0' "$MDB_CONF"
                fi
            fi
        fi

        echo "[4/8] Habilitando y reiniciando servicio MariaDB..."
        systemctl enable --now mariadb > /dev/null

        echo "[5/8] Configurando reglas de firewall para MariaDB..."
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-service=mysql > /dev/null
            firewall-cmd --reload > /dev/null
        fi

        echo "[6/8] Securizando instalación y creando usuarios..."
        DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)
        ADMIN_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)

        mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE USER 'admindb'@'%' IDENTIFIED BY '$ADMIN_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'admindb'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

        echo "[7/8] Tareas finales..."
        proceso_finalizado
        
        echo "Versión: MariaDB $MDB_V"
        echo ""
        echo "🛡️ Usuario Local (Bloqueado remotamente): root"
        echo "🔑 Password: $DB_PASS"
        echo ""
        echo "🌍 Usuario Remoto (Full privilegios): admindb"
        echo "🔑 Password: $ADMIN_PASS"
        echo "--------------------------------------------------"
        echo
        read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú..."
    else
        proceso_cancelado
    fi
}

modulo_db_mariadb_desinstalar() {
    clear
    if rpm -qa | grep -qiE "mariadb.*-server|mysql.*-server" || [ -d "/var/lib/mysql" ]; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${RO}   ➤ Desinstalar MariaDB${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -e "⚠️  ATENCIÓN: Esto eliminará la base de datos y todos sus datos."
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            echo "Deteniendo servicios..."
            systemctl stop mariadb || true
            echo "Eliminando paquetes..."
            dnf -y remove MariaDB-server MariaDB-client mariadb mariadb-server > /dev/null 2>&1 || true
            echo "Borrando datos residuales..."
            rm -rf /var/lib/mysql
            rm -rf /etc/my.cnf.d/server.cnf
            rm -f /etc/yum.repos.d/mariadb.repo
            dnf -y autoremove > /dev/null 2>&1
            dnf -y clean all > /dev/null 2>&1
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de MariaDB en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

# ==============================================================================
# MÓDULOS DE BASES DE DATOS (POSTGRESQL)
# ==============================================================================

modulo_db_postgres_instalar() {
    clear
    if rpm -qa | grep -q "postgresql.*-server" || [ -d "/var/lib/pgsql" ]; then
        echo -e "${AM}Ya existe una instalación previa de PostgreSQL.${CL}"
        echo "Abortando para proteger la integridad de los datos existentes."
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Instalar y Securizar PostgreSQL${CL}"
    echo -e "${AZ}======================================================${CL}"
    echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        ROCKY_VERSION=$(rpm -E %rhel)
        PG_REPO="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${ROCKY_VERSION}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
        PG_V="18"

        echo "[1/8] Instalando repositorios y paquetes de PostgreSQL $PG_V..."
        dnf install -y "$PG_REPO" > /dev/null
        dnf -qy module disable postgresql
        dnf install -y postgresql${PG_V}-server postgresql${PG_V}-contrib > /dev/null

        echo "[2/8] Inicializando cluster de base de datos..."
        if [ ! -d "/var/lib/pgsql/${PG_V}/data/base" ]; then
            /usr/pgsql-${PG_V}/bin/postgresql-${PG_V}-setup initdb > /dev/null
        fi

        echo "[3/8] Configurando red y seguridad (SCRAM-SHA-256)..."
        local PG_CONF="/var/lib/pgsql/${PG_V}/data/postgresql.conf"
        local PG_HBA="/var/lib/pgsql/${PG_V}/data/pg_hba.conf"

        sed -i "s/^[#]*\s*listen_addresses\s*=.*/listen_addresses = '*'/" "$PG_CONF"
        sed -i "s/^[#]*\s*password_encryption\s*=.*/password_encryption = scram-sha-256/" "$PG_CONF"
        
        sed -i '/0\.0\.0\.0\/0/d' "$PG_HBA"
        echo "host    all             postgres        0.0.0.0/0               reject" >> "$PG_HBA"
        echo "host    all             all             0.0.0.0/0               scram-sha-256" >> "$PG_HBA"

        echo "[4/8] Configurando reglas de firewall para PostgreSQL..."
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-service=postgresql > /dev/null
            firewall-cmd --reload > /dev/null
        fi

        echo "[5/8] Habilitando y reiniciando servicio PostgreSQL..."
        systemctl enable --now postgresql-${PG_V} > /dev/null
        systemctl restart postgresql-${PG_V}

        echo "[6/8] Configurando usuarios de base de datos..."
        DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)
        ADMIN_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)

        sudo -u postgres psql <<EOF > /dev/null
ALTER USER postgres WITH PASSWORD '$DB_PASS';
CREATE ROLE admindb WITH LOGIN SUPERUSER PASSWORD '$ADMIN_PASS';
EOF

        sed -i -e 's/peer/scram-sha-256/g' -e 's/ident/scram-sha-256/g' "$PG_HBA"
        systemctl reload postgresql-${PG_V}

        echo "[7/8] Tareas finales..."
        proceso_finalizado
        
        echo "Versión: PostgreSQL $PG_V"
        echo ""
        echo "🛡️ Usuario Local (Bloqueado remotamente): postgres"
        echo "🔑 Password: $DB_PASS"
        echo ""
        echo "🌍 Usuario Remoto (Full privilegios): admindb"
        echo "🔑 Password: $ADMIN_PASS"
        echo "--------------------------------------------------"
        echo
        read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú..."
    else
        proceso_cancelado
    fi
}

modulo_db_postgres_desinstalar() {
    clear
    if rpm -qa | grep -q "postgresql.*-server" || [ -d "/var/lib/pgsql" ]; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${RO}   ➤ Desinstalar PostgreSQL${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -e "⚠️  ATENCIÓN: Esto eliminará la base de datos y todos sus datos."
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            echo "Deteniendo servicios..."
            systemctl stop postgresql-18 || true
            systemctl stop postgresql-17 || true
            echo "Eliminando paquetes..."
            dnf -y remove postgresql*-server postgresql*-contrib > /dev/null 2>&1 || true
            echo "Borrando datos residuales..."
            rm -rf /var/lib/pgsql
            dnf -y autoremove > /dev/null 2>&1
            dnf -y clean all > /dev/null 2>&1
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver al menú..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de PostgreSQL en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

# ==============================================================================
# SUBMENÚS
# ==============================================================================

menu_db_mariadb() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🗄️  Base de Datos: MariaDB${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Instalar MariaDB"
        echo -e "${RO} x)${CL} Desinstalar MariaDB"
        echo
        echo -e "${CY} v)${CL} Volver"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una opción: " opc
        echo
        
        case $opc in
            1) modulo_db_mariadb_instalar ;;
            x|X) modulo_db_mariadb_desinstalar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}

menu_db_postgres() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🗄️  Base de Datos: PostgreSQL${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Instalar PostgreSQL"
        echo -e "${RO} x)${CL} Desinstalar PostgreSQL"
        echo
        echo -e "${CY} v)${CL} Volver"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una opción: " opc
        echo
        
        case $opc in
            1) modulo_db_postgres_instalar ;;
            x|X) modulo_db_postgres_desinstalar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}

menu_db() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🗄️  Gestor de Bases de Datos${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} MariaDB"
        echo -e "${CY} 2)${CL} PostgreSQL"
        echo
        echo -e "${CY} v)${CL} Volver al menú principal"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una opción: " opc
        echo
        
        case $opc in
            1) menu_db_mariadb ;;
            2) menu_db_postgres ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
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
        echo -e "${CY} 2)${CL} 🗄️  Bases de Datos (MariaDB / PostgreSQL)"
        echo
        echo -e "${RO} s)${CL} Salir del Asistente"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una opción: " opc
        echo
        
        case $opc in
            1) modulo_server ;;
            2) menu_db ;;
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
