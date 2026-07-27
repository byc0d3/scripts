#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: mariadb.sh
# Descripción: Script de instalación y configuración segura de MariaDB (10.11/11.4)
#              en Rocky Linux (9/10).
#
# Pasos generales que realiza:
#   1. Validación de root, versión del SO y verificación de instalaciones previas.
#   2. Detección automática de la última versión estable de MariaDB.
#   3. Configuración del repositorio oficial de MariaDB e instalación.
#   4. Configuración básica de red (bind-address).
#   5. Arranque del servicio MariaDB.
#   6. Configuración de Firewall (habilitar puerto mysql - 3306).
#   7. Ejecución de mysql_secure_installation automatizado (generación de clave).
#   8. Limpieza del instalador.
#
# Uso:
#   curl -fsSL "URL" -o /tmp/mariadb.sh && sudo bash /tmp/mariadb.sh
# ==============================================================================

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

check_existing_install() {
    echo "🔍 Verificando instalaciones previas..."
    if rpm -qa | grep -qiE "mariadb.*-server|mysql.*-server" || [ -d "/var/lib/mysql" ]; then
        echo "--------------------------------------------------"
        echo "❌ ERROR: Se detectó una instalación previa de MariaDB o MySQL."
        echo "Abortando para proteger la integridad de los datos existentes."
        echo "Si desea reinstalar, elimine manualmente los paquetes y el directorio /var/lib/mysql"
        echo "--------------------------------------------------"
        exit 1
    fi
}

select_mdb_version() {
    echo "[1/8] Detectando última versión estable desde la API de MariaDB..."
    
    # Consultar a la API oficial de MariaDB por la versión mayor catalogada como "Stable"
    MDB_V=$(curl -sS https://downloads.mariadb.org/rest-api/mariadb/ | jq -r '.major_releases[] | select(.release_status=="Stable") | .release_id' | sort -V | tail -n 1)
    
    if [[ -z "$MDB_V" ]]; then
        echo "❌ Error al detectar versión. Revise su conexión o asegúrese de que 'jq' esté instalado." >&2
        exit 1
    fi
    
    echo " ✓ Última estable detectada: $MDB_V"
    echo "✅ Iniciando instalación de MariaDB $MDB_V..."
}

install_mariadb() {
    echo "[2/8] Configurando repositorio oficial e instalando MariaDB $MDB_V..."
    
    cat > /etc/yum.repos.d/mariadb.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/${MDB_V}/rhel/\$releasever/\$basearch
gpgkey = https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF

    # Deshabilitar módulo mariadb de Rocky para evitar conflictos con el repositorio oficial
    dnf -qy module disable mariadb || true
    dnf install -y MariaDB-server MariaDB-client
}

configure_mariadb() {
    echo "[3/8] Configurando parámetros de red..."
    local MDB_CONF="/etc/my.cnf.d/server.cnf"
    
    # Forzar que escuche en todas las interfaces para permitir conexiones externas (si se requiere)
    if [ -f "$MDB_CONF" ]; then
        if ! grep -qE "^bind-address" "$MDB_CONF"; then
            if grep -q "^\[mariadb\]" "$MDB_CONF"; then
                sed -i '/^\[mariadb\]/a bind-address = 0.0.0.0' "$MDB_CONF"
                echo " ✓ bind-address configurado a 0.0.0.0"
            fi
        else
            echo " ✓ bind-address ya estaba configurado"
        fi
    fi
}

start_services() {
    echo "[4/8] Habilitando y reiniciando servicio MariaDB..."
    systemctl enable --now mariadb
}

configure_firewall() {
    echo "[5/8] Configurando reglas de firewall para MariaDB..."
    if systemctl is-active --quiet firewalld; then
        # MariaDB usa por defecto el servicio 'mysql' (puerto 3306) en firewalld
        firewall-cmd --permanent --add-service=mysql
        firewall-cmd --reload
        echo " ✓ Puerto de MariaDB (3306) abierto en el firewall."
    else
        echo "⚠️ Firewalld no está activo, omitiendo configuración de puertos."
    fi
}

secure_installation() {
    echo "[6/8] Securizando instalación y generando contraseña root..."
    # Generar password segura para root
    DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)

    # Equivalente automatizado a mysql_secure_installation
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
}

cleanup() {
    echo "[7/8] Tareas finales..."
    echo "--------------------------------------------------"
    echo "✅ DESPLIEGUE COMPLETADO CON ÉXITO"
    echo "--------------------------------------------------"
    echo "Versión: MariaDB $MDB_V"
    echo "Usuario: root"
    echo "Password: $DB_PASS"
    echo "--------------------------------------------------"
    
    echo "🗑️ Eliminando instalador..."
    rm -- "$0"
}

main() {
    echo "--- DB ARCHITECT: MariaDB Deployment (Safe Mode) ---"
    
    check_root
    detect_version
    check_existing_install
    select_mdb_version
    install_mariadb
    configure_mariadb
    start_services
    configure_firewall
    secure_installation
    cleanup
}

# Iniciar la ejecución
main
