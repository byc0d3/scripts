#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: postgres.sh
# Descripción: Script de instalación y configuración segura de PostgreSQL 17/18
#              en Rocky Linux (9/10).
#
# Pasos generales que realiza:
#   1. Validación de root, versión del SO y verificación de instalaciones previas.
#   2. Preparación de la instalación de PostgreSQL 18.
#   3. Instalación de repositorios oficiales de PostgreSQL y binarios.
#   4. Inicialización del cluster de base de datos.
#   5. Configuración de red y seguridad (listen_addresses, SCRAM-SHA-256).
#   6. Configuración de Firewall (habilitar postgresql).
#   7. Arranque del servicio postgresql.
#   8. Bloqueo remoto del usuario 'postgres' y creación del usuario 'admindb'.
#   9. Limpieza del instalador.
#
# Uso:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/scripts/refs/heads/main/postgres.sh?$(date +%s)" -o /tmp/postgres.sh && sudo bash /tmp/postgres.sh
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

    PG_REPO="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${ROCKY_VERSION}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
}

check_existing_install() {
    echo "🔍 Verificando instalaciones previas..."
    if rpm -qa | grep -q "postgresql.*-server" || [ -d "/var/lib/pgsql" ]; then
        echo "--------------------------------------------------"
        echo "❌ ERROR: Se detectó una instalación previa de PostgreSQL."
        echo "Abortando para proteger la integridad de los datos existentes."
        echo "--------------------------------------------------"
        exit 1
    fi
}

select_pg_version() {
    PG_V="18"
    echo "[1/8] Preparando instalación de PostgreSQL $PG_V (Última versión)..."
}

install_postgres() {
    echo "[2/8] Instalando repositorios y paquetes de PostgreSQL $PG_V..."
    dnf install -y "$PG_REPO"
    dnf -qy module disable postgresql
    dnf install -y postgresql${PG_V}-server postgresql${PG_V}-contrib
}

init_db() {
    echo "[3/8] Inicializando cluster de base de datos..."
    if [ ! -d "/var/lib/pgsql/${PG_V}/data/base" ]; then
        /usr/pgsql-${PG_V}/bin/postgresql-${PG_V}-setup initdb
    else
        echo "⚠️ El directorio de datos ya existe, omitiendo initdb."
    fi
}

configure_postgres() {
    echo "[4/8] Configurando red y seguridad (SCRAM-SHA-256)..."
    local PG_CONF="/var/lib/pgsql/${PG_V}/data/postgresql.conf"
    local PG_HBA="/var/lib/pgsql/${PG_V}/data/pg_hba.conf"

    if grep -qE "^listen_addresses\s*=\s*'\*'" "$PG_CONF"; then
        echo " ✓ listen_addresses ya está configurado"
    else
        sed -i "s/^[#]*\s*listen_addresses\s*=.*/listen_addresses = '*'/" "$PG_CONF"
    fi

    if grep -qE "^password_encryption\s*=\s*scram-sha-256" "$PG_CONF"; then
        echo " ✓ password_encryption ya es scram-sha-256"
    else
        sed -i "s/^[#]*\s*password_encryption\s*=.*/password_encryption = scram-sha-256/" "$PG_CONF"
    fi

    if grep -qE "^host\s+all\s+postgres\s+0\.0\.0\.0/0\s+reject" "$PG_HBA"; then
        echo " ✓ La regla de acceso global y bloqueo de postgres remoto ya existe."
    else
        # Limpiamos reglas previas de acceso total (si existen por ejecuciones anteriores)
        sed -i '/0\.0\.0\.0\/0/d' "$PG_HBA"

        # Bloqueamos estrictamente al usuario 'postgres' desde el exterior
        echo "host    all             postgres        0.0.0.0/0               reject" >> "$PG_HBA"
        # Permitimos acceso al resto de usuarios (como admindb) desde el exterior
        echo "host    all             all             0.0.0.0/0               scram-sha-256" >> "$PG_HBA"
    fi
}

configure_firewall() {
    echo "[5/8] Configurando reglas de firewall para PostgreSQL..."
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=postgresql
        firewall-cmd --reload
        echo " ✓ Puerto de PostgreSQL (5432) abierto en el firewall."
    else
        echo "⚠️ Firewalld no está activo, omitiendo configuración de puertos."
    fi
}

start_services() {
    echo "[6/8] Habilitando y reiniciando servicio PostgreSQL..."
    systemctl enable --now postgresql-${PG_V}
    systemctl restart postgresql-${PG_V}
}

configure_users() {
    echo "[7/8] Configurando usuarios de base de datos..."
    DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)
    ADMIN_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)

    # Creamos contraseñas para postgres y el nuevo usuario admindb con privilegios máximos
    sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD '$DB_PASS';
CREATE ROLE admindb WITH LOGIN SUPERUSER PASSWORD '$ADMIN_PASS';
EOF

    echo " 🔒 Reforzando seguridad local en pg_hba.conf..."
    local PG_HBA="/var/lib/pgsql/${PG_V}/data/pg_hba.conf"
    sed -i -e 's/peer/scram-sha-256/g' -e 's/ident/scram-sha-256/g' "$PG_HBA"
    systemctl reload postgresql-${PG_V}
}

cleanup() {
    echo "[8/8] Tareas finales..."
    echo "--------------------------------------------------"
    echo "✅ DESPLIEGUE COMPLETADO CON ÉXITO"
    echo "--------------------------------------------------"
    echo "Versión: PostgreSQL $PG_V"
    echo ""
    echo "🛡️ Usuario Local (Bloqueado remotamente): postgres"
    echo "🔑 Password: $DB_PASS"
    echo ""
    echo "🌍 Usuario Remoto (Full privilegios): admindb"
    echo "🔑 Password: $ADMIN_PASS"
    echo "--------------------------------------------------"

    echo "🗑️ Eliminando instalador..."
    rm -- "$0"
}

main() {
    echo "--- DB ARCHITECT: PostgreSQL Deployment (Safe Mode) ---"

    check_root
    detect_version
    check_existing_install
    select_pg_version
    install_postgres
    init_db
    configure_postgres
    configure_firewall
    start_services
    configure_users
    cleanup
}

# Iniciar la ejecución
main
