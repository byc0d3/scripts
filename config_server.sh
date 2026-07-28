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
    echo -e "${AM}Proceso culminado satisfactoriamente !!!.${CL}"
    echo
}

proceso_cancelado() {
    echo
    echo -e "${AM}Proceso cancelado !!!${CL}"
    echo
    read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
}

opcion_invalida() {
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
# MÓDULOS WEB (APACHE / NGINX)
# ==============================================================================

virtualhost_nginx() {
    read -p "Ingrese el nombre del dominio, ejem: midominio.com: " DOMINIO
    read -p "Ingrese la ruta del proyecto, ejem: /var/www/miproyecto: " ROOT
    CONF_FILE="/etc/nginx/conf.d/${DOMINIO}.conf"
    cat << EOF > "$CONF_FILE"
server {
    listen 80;
    server_name ${DOMINIO} *.${DOMINIO};
    root ${ROOT};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMINIO}-access.log;
    error_log /var/log/nginx/${DOMINIO}-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}
EOF
}

virtualhost_apache() {
    read -p "Ingrese el nombre del dominio, ejem: midominio.com: " DOMINIO
    read -p "Ingrese la ruta del proyecto, ejem: /var/www/miproyecto: " ROOT
    CONF_FILE="/etc/httpd/conf.d/${DOMINIO}.conf"
    cat << EOF > "$CONF_FILE"
<VirtualHost *:80>
    DocumentRoot "${ROOT}"
    ServerName ${DOMINIO}
    ServerAlias *.${DOMINIO}
    ErrorLog /var/log/httpd/${DOMINIO}-error_log
    CustomLog /var/log/httpd/${DOMINIO}-access_log combined
    <Directory "${ROOT}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
}

modulo_web_nginx_instalar() {
    clear
    if nginx -v &> /dev/null; then
        echo -e "${AM}Ya existe una instalación de Nginx.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    else
        echo -e "${AZ}======================================================${CL}"
        echo -e "${VE}   ➤ Instalar Nginx${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            dnf -y --assumeyes install nginx > /dev/null
            systemctl enable nginx --now > /dev/null
            systemctl start nginx > /dev/null
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    fi
}

modulo_web_nginx_vhost() {
    clear
    if nginx -v &> /dev/null; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${VE}   ➤ Configurar ServerBlock Nginx${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            virtualhost_nginx
            systemctl restart nginx
            echo -e "\n${VE}ServerBlock creado para el dominio con éxito !!!.${CL}"
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de Nginx en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

modulo_web_nginx_desinstalar() {
    clear
    if nginx -v &> /dev/null; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${RO}   ➤ Desinstalar Nginx${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            systemctl stop nginx || true
            dnf -y remove nginx > /dev/null
            dnf -y autoremove > /dev/null
            dnf -y clean all > /dev/null
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de Nginx en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

modulo_web_apache_instalar() {
    clear
    if httpd -v &> /dev/null; then
        echo -e "${AM}Ya existe una instalación de Apache.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    else
        echo -e "${AZ}======================================================${CL}"
        echo -e "${VE}   ➤ Instalar Apache${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            dnf -y --assumeyes install httpd > /dev/null
            systemctl enable httpd --now > /dev/null
            systemctl start httpd > /dev/null
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    fi
}

modulo_web_apache_vhost() {
    clear
    if httpd -v &> /dev/null; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${VE}   ➤ Configurar VirtualHost Apache${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            virtualhost_apache
            systemctl restart httpd
            echo -e "\n${VE}VirtualHost creado para el dominio con éxito !!!.${CL}"
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de Apache en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

modulo_web_apache_desinstalar() {
    clear
    if httpd -v &> /dev/null; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${RO}   ➤ Desinstalar Apache${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            systemctl stop httpd || true
            dnf -y remove httpd > /dev/null
            dnf -y autoremove > /dev/null
            dnf -y clean all > /dev/null
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de Apache en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
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
        
        cat <<EOF_CREDS >> /home/db_credentials.txt
==================================================
MariaDB Installation (\$(date))
Versión: $MDB_V
Usuario Local: root | Password: $DB_PASS
Usuario Remoto: admindb | Password: $ADMIN_PASS
==================================================
EOF_CREDS
        chmod 600 /home/db_credentials.txt
        echo -e "${VE}* Credenciales guardadas de forma segura en: /home/db_credentials.txt${CL}"
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
        
        cat <<EOF_CREDS >> /home/db_credentials.txt
==================================================
MariaDB Installation (\$(date))
Versión: $MDB_V
Usuario Local: root | Password: $DB_PASS
Usuario Remoto: admindb | Password: $ADMIN_PASS
==================================================
EOF_CREDS
        chmod 600 /home/db_credentials.txt
        echo -e "${VE}* Credenciales guardadas de forma segura en: /home/db_credentials.txt${CL}"
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

menu_web_nginx() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🌐  Servidor Web: Nginx${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Instalar Nginx"
        echo -e "${CY} 2)${CL} Configurar ServerBlock"
        echo -e "${RO} x)${CL} Desinstalar Nginx"
        echo
        echo -e "${CY} v)${CL} Volver"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_web_nginx_instalar ;;
            2) modulo_web_nginx_vhost ;;
            x|X) modulo_web_nginx_desinstalar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}

menu_web_apache() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🌐  Servidor Web: Apache${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Instalar Apache"
        echo -e "${CY} 2)${CL} Configurar VirtualHost"
        echo -e "${RO} x)${CL} Desinstalar Apache"
        echo
        echo -e "${CY} v)${CL} Volver"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_web_apache_instalar ;;
            2) modulo_web_apache_vhost ;;
            x|X) modulo_web_apache_desinstalar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}

menu_web() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🌐  Gestor de Servidores Web${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Nginx"
        echo -e "${CY} 2)${CL} Apache"
        echo
        echo -e "${CY} v)${CL} Volver al menú principal"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) menu_web_nginx ;;
            2) menu_web_apache ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}

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
# MÓDULOS DE PHP
# ==============================================================================

instalar_php() {
    local PHP_V=$1
    clear
    if php -v &> /dev/null; then
        php_version=$(php -v | awk '/^PHP/ {print $2}')
        echo -e "${AM}Ya existe una instalación de PHP, en su versión ${php_version}.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Instalar PHP ${PHP_V}${CL}"
    echo -e "${AZ}======================================================${CL}"
    echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        ROCKY_VERSION=$(rpm -E %rhel)

        echo "[1/4] Preparando repositorios REMI y CRB..."
        dnf config-manager --set-enabled crb > /dev/null 2>&1 || dnf config-manager --set-enabled powertools > /dev/null 2>&1 || true
        dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${ROCKY_VERSION}.rpm > /dev/null 2>&1 || true

        echo "[2/4] Instalando PHP ${PHP_V} y extensiones..."
        dnf -y module reset php > /dev/null 2>&1 || true
        dnf -y module install php:remi-${PHP_V} > /dev/null 2>&1
        dnf -y install php-fpm php-cli php-mysqlnd php-gd php-curl php-zip php-mbstring php-xml php-intl > /dev/null 2>&1

        echo "[3/4] Configurando PHP-FPM..."
        if nginx -v &> /dev/null; then
            echo "      > Detectado Nginx: Ajustando /etc/php-fpm.d/www.conf"
            sed -i 's/^\s*user\s*=\s*.*/user = nginx/' /etc/php-fpm.d/www.conf
            sed -i 's/^\s*group\s*=\s*.*/group = nginx/' /etc/php-fpm.d/www.conf
            sed -i 's/^\s*;\?\s*listen\.owner\s*=.*/listen.owner = nginx/' /etc/php-fpm.d/www.conf
            sed -i 's/^\s*;\?\s*listen\.group\s*=.*/listen.group = nginx/' /etc/php-fpm.d/www.conf
            sed -i 's/^\s*;\?\s*listen\.mode\s*=.*/listen.mode = 0660/' /etc/php-fpm.d/www.conf
        fi

        echo "[4/4] Reiniciando servicios web y PHP-FPM..."
        systemctl enable --now php-fpm > /dev/null 2>&1
        systemctl restart php-fpm > /dev/null 2>&1

        if nginx -v &> /dev/null; then systemctl restart nginx > /dev/null 2>&1; fi
        if httpd -v &> /dev/null; then systemctl restart httpd > /dev/null 2>&1; fi

        # Crear archivo de prueba
        echo "<?php phpinfo(); ?>" > /var/www/html/info.php 2>/dev/null || true

        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

modulo_php_desinstalar() {
    clear
    if php -v &> /dev/null; then
        echo -e "${AZ}======================================================${CL}"
        echo -e "${RO}   ➤ Desinstalar PHP${CL}"
        echo -e "${AZ}======================================================${CL}"
        echo -n "¿Deseas continuar con el proceso? Escribe yes para continuar: "
        read confirmar
        if [ "$confirmar" == "yes" ]; then
            check_root
            echo "Deteniendo PHP-FPM..."
            systemctl stop php-fpm > /dev/null 2>&1 || true
            echo "Eliminando paquetes..."
            dnf -y module reset php > /dev/null 2>&1 || true
            dnf -y remove php* > /dev/null 2>&1 || true
            dnf -y autoremove > /dev/null 2>&1
            dnf -y clean all > /dev/null 2>&1
            rm -f /var/www/html/info.php
            proceso_finalizado
            read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
        else
            proceso_cancelado
        fi
    else
        echo -e "${RO}No existe una instalación de PHP en el sistema.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    fi
}

menu_php() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🐘  Gestor de PHP${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Instalar PHP 7.4"
        echo -e "${CY} 2)${CL} Instalar PHP 8.0"
        echo -e "${CY} 3)${CL} Instalar PHP 8.1"
        echo -e "${CY} 4)${CL} Instalar PHP 8.2"
        echo -e "${CY} 5)${CL} Instalar PHP 8.3"
        echo -e "${CY} 6)${CL} Instalar PHP 8.4"
        echo -e "${CY} 7)${CL} Instalar PHP 8.5"
        echo
        echo -e "${RO} x)${CL} Desinstalar PHP"
        echo
        echo -e "${CY} v)${CL} Volver al menú principal"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) instalar_php "7.4" ;;
            2) instalar_php "8.0" ;;
            3) instalar_php "8.1" ;;
            4) instalar_php "8.2" ;;
            5) instalar_php "8.3" ;;
            6) instalar_php "8.4" ;;
            7) instalar_php "8.5" ;;
            x|X) modulo_php_desinstalar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}


# ==============================================================================
# MÓDULOS DE REDES
# ==============================================================================

modulo_redes_con_ruta() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Configurar red con ruta (PBR)${CL}"
    echo -e "${AZ}======================================================${CL}"

    read -p "Nombre del dispositivo (ej. ens224): " DEVICE
    read -p "Dirección IP (ej. 10.31.196.49): " IP
    read -p "Máscara/Prefijo (ej. 25): " PREFIX
    read -p "Gateway (ej. 10.31.196.1): " GW
    TABLE=5000

    if [[ -z "$DEVICE" || -z "$IP" || -z "$PREFIX" || -z "$GW" ]]; then
        echo -e "${RO}❌ Error: Dispositivo, IP, Prefijo y Gateway son obligatorios.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -n "¿Deseas aplicar esta configuración? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        echo "Eliminando perfil anterior..."
        nmcli con delete "$DEVICE" > /dev/null 2>&1 || true

        echo "Creando nueva conexión..."
        nmcli con add con-name "$DEVICE" type ethernet ifname "$DEVICE" \
            ipv4.method manual \
            ipv4.addresses "${IP}/${PREFIX}" \
            ipv4.never-default yes \
            ipv6.method disabled > /dev/null

        echo "Configurando enrutamiento y Policy Based Routing (PBR)..."
        nmcli con mod "$DEVICE" ipv4.gateway "$GW"
        nmcli con mod "$DEVICE" ipv4.route-table "$TABLE"
        nmcli con mod "$DEVICE" ipv4.routing-rules ""
        nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 iif ${DEVICE} table ${TABLE}"
        nmcli con mod "$DEVICE" +ipv4.routing-rules "priority 5 from ${IP} table ${TABLE}"

        echo "Levantando interfaz de red..."
        nmcli con up "$DEVICE" > /dev/null
        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

modulo_redes_sin_ruta() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Configurar red sin ruta (Red Local)${CL}"
    echo -e "${AZ}======================================================${CL}"

    read -p "Nombre del dispositivo (ej. ens224): " DEVICE
    read -p "Dirección IP (ej. 192.168.1.10): " IP
    read -p "Máscara/Prefijo (ej. 24): " PREFIX

    if [[ -z "$DEVICE" || -z "$IP" || -z "$PREFIX" ]]; then
        echo -e "${RO}❌ Error: Dispositivo, IP y Prefijo son obligatorios.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -n "¿Deseas aplicar esta configuración? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        echo "Eliminando perfil anterior..."
        nmcli con delete "$DEVICE" > /dev/null 2>&1 || true

        echo "Creando nueva conexión (sin Gateway)..."
        nmcli con add con-name "$DEVICE" type ethernet ifname "$DEVICE" \
            ipv4.method manual \
            ipv4.addresses "${IP}/${PREFIX}" \
            ipv4.never-default yes \
            ipv6.method disabled > /dev/null

        echo "Levantando interfaz de red..."
        nmcli con up "$DEVICE" > /dev/null
        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

modulo_redes_eliminar() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${RO}   ➤ Eliminar una interfaz de red${CL}"
    echo -e "${AZ}======================================================${CL}"

    read -p "Nombre del dispositivo a eliminar (ej. ens224): " DEVICE

    if [[ -z "$DEVICE" ]]; then
        echo -e "${RO}❌ Error: El nombre del dispositivo es obligatorio.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -e "⚠️  ATENCIÓN: Se eliminará la conexión '$DEVICE'."
    echo -n "¿Deseas continuar? Escribe yes para confirmar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        echo "Eliminando conexión de red..."
        nmcli con delete "$DEVICE" > /dev/null 2>&1 || true
        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

menu_redes() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   🔌  Gestor de Redes e Interfaces${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Configurar red con ruta (PBR)"
        echo -e "${CY} 2)${CL} Configurar red sin ruta (Local)"
        echo -e "${RO} x)${CL} Eliminar una interfaz"
        echo
        echo -e "${CY} v)${CL} Volver al menú principal"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_redes_con_ruta ;;
            2) modulo_redes_sin_ruta ;;
            x|X) modulo_redes_eliminar ;;
            v|V) break ;;
            *) opcion_invalida ;;
        esac
    done
}


# ==============================================================================
# MÓDULOS DE ALMACENAMIENTO (LVM)
# ==============================================================================

modulo_lvm_nuevo_disco() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Añadir disco nuevo a LVM${CL}"
    echo -e "${AZ}======================================================${CL}"

    read -p "Introduce el nuevo disco (ej. /dev/sdc): " NUEVO_DISCO
    read -p "Introduce la ruta a extender (ej. /home): " RUTA

    if [[ -z "$NUEVO_DISCO" || -z "$RUTA" ]]; then
        echo -e "${RO}❌ Error: El disco y la ruta son obligatorios.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    if [[ ! -b "$NUEVO_DISCO" ]]; then
        echo -e "${RO}❌ Error: El disco '$NUEVO_DISCO' no existe o no es válido.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    if [[ ! -d "$RUTA" ]]; then
        echo -e "${RO}❌ Error: El directorio '$RUTA' no existe.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -n "¿Deseas aplicar esta configuración? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        LV_PATH=$(df "$RUTA" --output=source | tail -1)
        if ! lvs "$LV_PATH" > /dev/null 2>&1; then
            echo -e "${RO}❌ Error: '$LV_PATH' no parece ser un Volumen Lógico de LVM.${CL}"
            read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
            return
        fi

        VG_NAME=$(lvs --noheadings -o vg_name "$LV_PATH" | xargs)
        if pvs "$NUEVO_DISCO" > /dev/null 2>&1; then
            echo -e "${RO}❌ Error: El disco ya forma parte de un LVM existente.${CL}"
            read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
            return
        fi

        echo "Creando Physical Volume (PV)..."
        pvcreate -y "$NUEVO_DISCO" > /dev/null
        echo "Añadiendo el disco al Volume Group '$VG_NAME'..."
        vgextend "$VG_NAME" "$NUEVO_DISCO" > /dev/null
        echo "Extendiendo Logical Volume y File System..."
        lvextend -l +100%FREE "$LV_PATH" -r > /dev/null

        echo -e "\n${VE}Estado final:${CL}"
        df -h "$RUTA" | awk 'NR==2{print "  Tamaño: "$2" | Usado: "$3" | Disp: "$4" ("$5")"}'
        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

modulo_lvm_extender_existente() {
    clear
    echo -e "${AZ}======================================================${CL}"
    echo -e "${VE}   ➤ Extender un disco existente en LVM${CL}"
    echo -e "${AZ}======================================================${CL}"

    read -p "Físico ampliado (ej. /dev/sda2 o /dev/sdb): " PV_DISK
    read -p "Ruta a extender (ej. / o /home): " RUTA

    if [[ -z "$PV_DISK" || -z "$RUTA" ]]; then
        echo -e "${RO}❌ Error: El disco y la ruta son obligatorios.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    if [[ ! -b "$PV_DISK" ]]; then
        echo -e "${RO}❌ Error: '$PV_DISK' no existe o no es válido.${CL}"
        read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
        return
    fi

    echo -n "¿Deseas aplicar esta configuración? Escribe yes para continuar: "
    read confirmar
    if [ "$confirmar" == "yes" ]; then
        check_root
        PKNAME=$(lsblk -no PKNAME "$PV_DISK" | tr -d ' ' | head -n 1)

        if [[ -n "$PKNAME" ]]; then
            PARENT_DISK="/dev/$PKNAME"
            PART_NUM=$(echo "$PV_DISK" | grep -oE '[0-9]+$')
            echo "Solicitando rescan al Kernel e inyectando espacio a la partición..."
            echo 1 > "/sys/class/block/${PKNAME}/device/rescan" 2>/dev/null || true

            if command -v parted &> /dev/null; then
                parted -s -a opt "$PARENT_DISK" "resizepart" "$PART_NUM" "100%" > /dev/null 2>&1 || true
            elif command -v growpart &> /dev/null; then
                growpart "$PARENT_DISK" "$PART_NUM" > /dev/null 2>&1 || true
            else
                echo -e "${RO}❌ Error: No se encontraron 'parted' ni 'growpart' en el sistema.${CL}"
                read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
                return
            fi
        else
            echo "Solicitando rescan al Kernel..."
            DISK_NAME=$(basename "$PV_DISK")
            echo 1 > "/sys/class/block/${DISK_NAME}/device/rescan" 2>/dev/null || true
        fi

        echo "Actualizando Physical Volume (pvresize)..."
        pvresize "$PV_DISK" > /dev/null

        LV_PATH=$(df "$RUTA" --output=source | tail -1)
        if ! lvs "$LV_PATH" > /dev/null 2>&1; then
            echo -e "${RO}❌ Error: '$LV_PATH' no parece ser un Volumen Lógico.${CL}"
            read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
            return
        fi

        echo "Extendiendo Logical Volume y File System en cascada..."
        lvextend -l +100%FREE "$LV_PATH" -r > /dev/null

        echo -e "\n${VE}Estado final:${CL}"
        df -h "$RUTA" | awk 'NR==2{print "  Tamaño: "$2" | Usado: "$3" | Disp: "$4" ("$5")"}'
        proceso_finalizado
        read -n 1 -s -r -p "Presiona cualquier tecla para volver..."
    else
        proceso_cancelado
    fi
}

menu_lvm() {
    while true; do
        clear
        echo -e "${AZ}==================================================${CL}"
        echo -e "${VE}   💾  Gestor de Almacenamiento (LVM)${CL}"
        echo -e "${AZ}==================================================${CL}"
        echo -e "${CY} 1)${CL} Añadir disco nuevo a un LVM existente"
        echo -e "${CY} 2)${CL} Extender un disco existente en LVM"
        echo
        echo -e "${CY} v)${CL} Volver al menú principal"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_lvm_nuevo_disco ;;
            2) modulo_lvm_extender_existente ;;
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
        echo -e "${CY} 1)${CL} 🛠️   Configuraciones Iniciales del S.O (Server Base)"
        echo -e "${CY} 2)${CL} 🗄️   Bases de Datos (MariaDB / PostgreSQL)"
        echo -e "${CY} 3)${CL} 🌐  Servidores Web (Nginx / Apache)"
        echo -e "${CY} 4)${CL} 🐘  Gestor de PHP (Multi-versión)"
        echo -e "${CY} 5)${CL} 🔌  Gestor de Redes (Interfaces / PBR)"
        echo -e "${CY} 6)${CL} 💾  Gestor de Almacenamiento (LVM)"
        echo
        echo -e "${RO} s)${CL} Salir del Asistente"
        echo -e "${AZ}==================================================${CL}"

        read -n 1 -p "Seleccione una opción: " opc
        echo

        case $opc in
            1) modulo_server ;;
            2) menu_db ;;
            3) menu_web ;;
            4) menu_php ;;
            5) menu_redes ;;
            6) menu_lvm ;;
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
