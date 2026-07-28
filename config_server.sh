#!/bin/bash
# ==============================================================================
# Script: config_server.sh
# Descripción: Menú maestro interactivo para la suite de automatización Rocky Linux.
# Arquitectura: Lanza de forma modular los scripts individuales de infraestructura.
# ==============================================================================
set -e

# --- Variables de Color ---
AM="\e[1;33m"  # Amarillo
AZ="\e[1;34m"  # Azul
CY="\e[1;36m"  # Cyan
RO="\e[1;31m"  # Rojo
VE="\e[1;32m"  # Verde
BL="\e[1;37m"  # Blanco
CL="\e[0m"     # Limpiar

BASE_URL="https://raw.githubusercontent.com/byc0d3/tools/main/scripts/bash"

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
        echo -e "${CY} 1)${CL} 🛠️  Sistema Base"
        echo -e "${CY} 2)${CL} 🌐  Servicios Web (PHP, Apache)"
        echo -e "${CY} 3)${CL} 🗄️  Bases de Datos (MariaDB, PostgreSQL)"
        echo -e "${CY} 4)${CL} 🔌  Redes (Interfaces, PBR)"
        echo -e "${CY} 5)${CL} 💾  Almacenamiento (LVM, Discos)"
        echo
        echo -e "${RO} s)${CL} Salir del Asistente"
        echo -e "${AZ}==================================================${CL}"
        
        read -n 1 -p "Seleccione una categoría: " opc
        echo
        
        case $opc in
            1) menu_sistema ;;
            2) menu_web ;;
            3) menu_db ;;
            4) menu_redes ;;
            5) menu_almacenamiento ;;
            s|S)
                echo -e "\n${VE}¡Hasta pronto!${CL}"
                exit 0
                ;;
            *)
                echo -e "${RO}Opción inválida.${CL}"
                sleep 1
                ;;
        esac
    done
}

# Iniciar aplicación
menu_principal
