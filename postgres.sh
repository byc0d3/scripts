#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: postgres.sh
# Descripción: Script de instalación y configuración segura de PostgreSQL 17/18
#              en Rocky Linux (9/10).
#
# Pasos generales que realiza:
#   1. Validación de root, versión del SO y verificación de instalaciones previas.
#   2. Selección de versión de PostgreSQL (interactiva o por variable de entorno).
#   3. Instalación de repositorios oficiales de PostgreSQL y binarios.
#   4. Inicialización del cluster de base de datos.
#   5. Configuración de red y seguridad (listen_addresses, SCRAM-SHA-256).
#   6. Configuración de Firewall (habilitar postgresql).
#   7. Arranque del servicio postgresql.
#   8. Generación de contraseña segura aleatoria para el superusuario 'postgres'.
#   9. Limpieza del instalador.
#
# Uso:
#   # Interactivo:
#   curl -fsSL "URL" -o /tmp/postgres.sh && sudo bash /tmp/postgres.sh
#   # No interactivo:
#   curl -fsSL "URL" -o /tmp/postgres.sh && sudo PG_VERSION="17" bash /tmp/postgres.sh
# ==============================================================================

# Permite pasar la versión como variable de entorno
TARGET_PG_VERSION="${PG_VERSION:-}"

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

    # Repositorio oficial de PostgreSQL según versión de OS
    PG_REPO="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${ROCKY_VERSION}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
}

check_existing_install() {
    echo "🔍 Verificando instalaciones previas..."
    if rpm -qa | grep -q "postgresql.*-server" || [ -d "/var/lib/pgsql" ]; then
        echo "--------------------------------------------------"
        echo "❌ ERROR: Se detectó una instalación previa de PostgreSQL."
        echo "Abortando para proteger la integridad de los datos existentes."
        echo "Si desea reinstalar, elimine manualmente los paquetes y el directorio /var/lib/pgsql"
        echo "--------------------------------------------------"
        exit 1
    fi
}

select_pg_version() {
    if [[ -n "$TARGET_PG_VERSION" ]]; then
        PG_V="$TARGET_PG_VERSION"
        echo "[1/8] Usando versión de PostgreSQL proporcionada por entorno: $PG_V"
        
        if [[ ! "$PG_V" =~ ^(17|18)$ ]]; then
            echo "❌ Error: Versión $PG_V no soportada. Use 17 o 18." >&2
            exit 1
        fi
    else
        echo "[1/8] Seleccione la versión de PostgreSQL:"
        echo "1) PostgreSQL 17"
        echo "2) PostgreSQL 18"
        read -p "Elija una opción [1-2]: " OPCION
        
        case $OPCION in
            1) PG_V="17" ;;
            2) PG_V="18" ;;
            *) echo "❌ Opción no válida. Abortando."; exit 1 ;;
        esac
    fi
    echo "✅ Has seleccionado PostgreSQL $PG_V. Iniciando instalación..."
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

    if grep -qE "^host\s+all\s+all\s+0\.0\.0\.0/0\s+scram-sha-256" "$PG_HBA"; then
        echo " ✓ La regla de acceso global ya existe en pg_hba.conf"
    else
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

configure_password() {
    echo "[7/8] Generando contraseña para el superusuario 'postgres'..."
    # Filtramos la contraseña para evitar carácteres prohibidos en clientes como DBeaver
    DB_PASS=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 16)

    sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD '$DB_PASS';
EOF
}

cleanup() {
    echo "[8/8] Tareas finales..."
    echo "--------------------------------------------------"
    echo "✅ DESPLIEGUE COMPLETADO CON ÉXITO"
    echo "--------------------------------------------------"
    echo "Versión: PostgreSQL $PG_V"
    echo "Usuario: postgres"
    echo "Password: $DB_PASS"
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
    configure_password
    cleanup
}

# Iniciar la ejecución
main
