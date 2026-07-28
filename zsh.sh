#!/bin/bash
set -eo pipefail

# ==============================================================================
# Script: zsh.sh
# Descripción: Instala y configura Zsh, Oh-My-Zsh, plugins (syntax-highlighting,
#              autosuggestions, completions) y alias mejorados (bat, lsd).
#
# Pasos generales:
#   1. Validación de root y dependencias.
#   2. Instalación de paquetes y utilidades de terminal.
#   3. Instalación desatendida de Oh-My-Zsh y clonación de plugins.
#   4. Inyección de plugins en .zshrc y creación de .alias.
#   5. Establecer Zsh como shell por defecto.
#
# Uso:
#   curl -fsSL "https://raw.githubusercontent.com/byc0d3/tools/main/scripts/bash/zsh.sh?$(date +%s)" -o /tmp/zsh.sh && sudo bash /tmp/zsh.sh && rm -f /tmp/zsh.sh
# ==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script debe ejecutarse como root." >&2
        exit 1
    fi
}

install_packages() {
    echo "[1/4] Instalando dependencias (zsh, bat, lsd, git, util-linux-user)..."
    
    # Habilitamos EPEL por si bat o lsd lo necesitan
    dnf install -y epel-release > /dev/null 2>&1 || true
    
    # util-linux-user es necesario en Rocky 9 para tener el comando 'chsh'
    dnf install -y zsh bat lsd git wget curl util-linux-user > /dev/null
}

install_ohmyzsh() {
    echo "[2/4] Instalando Oh-My-Zsh y clonando plugins..."
    
    local OMZ_DIR="$HOME/.oh-my-zsh"
    
    if [ -d "$OMZ_DIR" ]; then
        echo " ✓ Oh-My-Zsh ya está instalado, omitiendo instalación base..."
    else
        # Instalación desatendida de Oh-My-Zsh
        echo " -> Descargando script oficial..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" > /dev/null 2>&1
    fi
    
    local PLUGINS_DIR="${OMZ_DIR}/custom/plugins"
    mkdir -p "$PLUGINS_DIR"
    
    # Instalar Zsh Syntax Highlighting
    if [ ! -d "${PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
        echo " -> Instalando zsh-syntax-highlighting..."
        git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting.git "${PLUGINS_DIR}/zsh-syntax-highlighting"
    fi
    
    # Instalar Zsh Autosuggestions
    if [ ! -d "${PLUGINS_DIR}/zsh-autosuggestions" ]; then
        echo " -> Instalando zsh-autosuggestions..."
        git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "${PLUGINS_DIR}/zsh-autosuggestions"
    fi
    
    # Instalar Zsh Completions
    if [ ! -d "${PLUGINS_DIR}/zsh-completions" ]; then
        echo " -> Instalando zsh-completions..."
        git clone --quiet https://github.com/zsh-users/zsh-completions "${PLUGINS_DIR}/zsh-completions"
    fi
}

configure_zsh() {
    echo "[3/4] Configurando ~/.zshrc y ~/.alias..."
    
    local ZSHRC="$HOME/.zshrc"
    local ALIAS_FILE="$HOME/.alias"
    
    if [ -f "$ZSHRC" ]; then
        # Reemplazar la línea de plugins por defecto con nuestros plugins
        # Usamos una sola línea para evitar problemas con sed multilínea
        sed -i -E 's/^plugins=\(.*\)/plugins=(sudo git z zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/g' "$ZSHRC"
        
        # Asegurarnos de que el archivo de alias se cargue al final
        if ! grep -q "source ~/.alias" "$ZSHRC"; then
            echo "" >> "$ZSHRC"
            echo "source ~/.alias" >> "$ZSHRC"
        fi
    else
        echo "⚠️  Advertencia: No se encontró ~/.zshrc."
    fi

    # Sobreescribir o crear archivo de alias
    cat > "$ALIAS_FILE" << 'EOF'
# --- Modernización de comandos ---
alias cat='bat'
alias ll='lsd -lh --group-dirs=first'
alias la='lsd -a --group-dirs=first'
alias l='lsd --group-dirs=first'
alias lla='lsd -lha --group-dirs=first'
alias ls='lsd --group-dirs=first'
alias lst='lsd --tree --group-dirs=first'
alias cls='clear'

# --- Utilidades Git ---
gitp() {
    git add .
    git commit -m "${1:-update: $(date +'%d-%m-%Y %H:%M')}"
    git push origin main
}

# --- VPN ---
alias vpn="sudo openfortivpn -c /etc/openfortivpn/config --cipher-list 'DEFAULT:!DH'"
EOF
}

finalize() {
    echo "[4/4] Estableciendo Zsh como shell por defecto..."
    
    chsh -s $(which zsh) "$USER" > /dev/null 2>&1 || true
    
    echo "--------------------------------------------------"
    echo "✅ CONFIGURACIÓN DE ZSH COMPLETADA"
    echo "--------------------------------------------------"
    echo "Tus plugins y alias (bat, lsd, gitp) están listos."
    echo "Para aplicar los cambios, ejecuta:"
    echo "    exec zsh"
    echo "--------------------------------------------------"
    
    echo "🗑️ Eliminando instalador..."
    rm -f -- "$0" 2>/dev/null || true
}

main() {
    echo "--- SYSADMIN: Zsh & Oh-My-Zsh Setup ---"
    
    check_root
    install_packages
    install_ohmyzsh
    configure_zsh
    finalize
}

# Iniciar la ejecución
main
