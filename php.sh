#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: php.sh
# Descripción: Script para instalar Nginx y PHP (vía Remi Repository) en
#              sistemas Rocky Linux (9/10) y Fedora (43/44). 
#              Configura PHP-FPM para trabajar con Nginx de forma automática.
#
# Pasos generales que realiza:
#   1. Validación de root y detección del SO (Rocky o Fedora).
#   2. Selección de versión de PHP (interactiva o por variable de entorno).
#   3. Instalación de repositorios necesarios (EPEL, CRB, Remi).
#   4. Instalación de Nginx.
#   5. Habilitación del módulo de PHP deseado e instalación de dependencias.
#   6. Configuración de PHP-FPM (ajusta usuario y grupo a nginx).
#   7. Configuración de Firewall (habilitar http y https).
#   8. Habilitación y reinicio de servicios (nginx, php-fpm).
#   9. Limpieza del instalador.
#
# Uso:
#   # Interactivo:
#   curl -fsSL "URL" -o /tmp/php.sh && sudo bash /tmp/php.sh
#   # No interactivo:
#   curl -fsSL "URL" -o /tmp/php.sh && sudo PHP_VERSION="8.3" bash /tmp/php.sh
# ==============================================================================

# Permite pasar la versión de PHP como variable de entorno
TARGET_PHP_VERSION="${PHP_VERSION:-}"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

detect_version() {
    ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
    VERSION_ID=$(grep -oP '(?<=VERSION_ID=")\d+' /etc/os-release)

    # Validar combinaciones soportadas
    if [[ "$ID" == "rocky" && ( "$VERSION_ID" == "9" || "$VERSION_ID" == "10" ) ]]; then
        OS="rocky"
        REMI_REPO="https://rpms.remirepo.net/enterprise/remi-release-${VERSION_ID}.rpm"
    elif [[ "$ID" == "fedora" && ( "$VERSION_ID" == "43" || "$VERSION_ID" == "44" ) ]]; then
        OS="fedora"
        REMI_REPO="https://rpms.remirepo.net/fedora/remi-release-${VERSION_ID}.rpm"
    else
        echo "❌ Error: Sistema operativo o versión no soportado." >&2
        echo "Soportados: Rocky 9/10, Fedora 43/44" >&2
        exit 1
    fi

    echo "--------------------------------------------------"
    echo "📌 Sistema detectado: ${ID^} $VERSION_ID"
    echo "📦 Repositorio Remi : $REMI_REPO"
    echo "--------------------------------------------------"
}

select_php_version() {
    if [[ -n "$TARGET_PHP_VERSION" ]]; then
        PHP_V="$TARGET_PHP_VERSION"
        echo "[1/8] Usando versión de PHP proporcionada por entorno: $PHP_V"
        
        # Validar que la versión pasada sea una de las soportadas
        if [[ ! "$PHP_V" =~ ^(7\.4|8\.1|8\.2|8\.3|8\.4|8\.5)$ ]]; then
            echo "❌ Error: Versión $PHP_V no soportada por este script." >&2
            exit 1
        fi
    else
        echo "[1/8] Seleccione la versión de PHP que desea instalar:"
        echo "1) PHP 7.4"
        echo "2) PHP 8.1"
        echo "3) PHP 8.2"
        echo "4) PHP 8.3"
        echo "5) PHP 8.4"
        echo "6) PHP 8.5"
        read -p "Elija una opción [1-6]: " OPCION
        
        case $OPCION in
            1) PHP_V="7.4" ;;
            2) PHP_V="8.1" ;;
            3) PHP_V="8.2" ;;
            4) PHP_V="8.3" ;;
            5) PHP_V="8.4" ;;
            6) PHP_V="8.5" ;;
            *) echo "❌ Opción no válida. Abortando."; exit 1 ;;
        esac
    fi
    echo "✅ Has seleccionado PHP $PHP_V. Iniciando instalación..."
}

install_repos() {
    echo "[2/8] Instalando repositorios necesarios (EPEL, CRB, Remi)..."
    
    if [[ "$OS" == "rocky" ]]; then
        dnf config-manager --set-enabled crb
        dnf install -y epel-release
    fi
    
    dnf install -y "$REMI_REPO"
}

install_nginx() {
    echo "[3/8] Instalando Nginx..."
    dnf install -y nginx
}

install_php() {
    echo "[4/8] Activando módulo e instalando paquetes de PHP $PHP_V..."
    dnf module reset php -y
    dnf module enable php:remi-$PHP_V -y
    
    dnf install -y php-fpm php-cli php-common php-intl php-mbstring \
        php-xml php-gd php-curl php-mysqlnd php-pgsql php-opcache \
        php-zip php-bcmath php-soap
}

configure_php_fpm() {
    echo "[5/8] Configurando PHP-FPM para Nginx..."
    local FILE="/etc/php-fpm.d/www.conf"
    
    if [[ -f "$FILE" ]]; then
        sed -i 's/^user =.*/user = nginx/' "$FILE"
        sed -i 's/^group =.*/group = nginx/' "$FILE"
        sed -i 's/^;*listen.owner =.*/listen.owner = nginx/' "$FILE"
        sed -i 's/^;*listen.group =.*/listen.group = nginx/' "$FILE"
        sed -i 's/^;*listen.mode =.*/listen.mode = 0660/' "$FILE"
    else
        echo "⚠️ Advertencia: No se encontró el archivo $FILE"
    fi
}

configure_firewall() {
    echo "[6/8] Configurando reglas de firewall..."
    # Verificar si firewalld está activo antes de intentar agregar reglas
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    else
        echo "⚠️ Firewalld no está activo, omitiendo configuración de puertos."
    fi
}

enable_services() {
    echo "[7/8] Habilitando y reiniciando servicios (Nginx, PHP-FPM)..."
    systemctl enable --now nginx php-fpm
    systemctl restart php-fpm
    systemctl restart nginx
}

cleanup() {
    echo "[8/8] Tareas finales..."
    echo "✅ ¡Instalación de PHP $PHP_V en ${ID^} $VERSION_ID finalizada con éxito!"
    
    # Autoeliminación del script
    echo "🗑️ Eliminando instalador..."
    rm -- "$0"
}

main() {
    echo "--- Iniciando Instalación de Servidor Web (Nginx + PHP) ---"
    
    check_root
    detect_version
    select_php_version
    install_repos
    install_nginx
    install_php
    configure_php_fpm
    configure_firewall
    enable_services
    cleanup
}

# Iniciar la ejecución
main
