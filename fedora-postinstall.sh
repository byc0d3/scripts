#!/usr/bin/env bash
# ==================================================
# Fedora Post-Installation Script
# Autor: jpineda
# Descripción: Configura el entorno completo de trabajo
#              (Zsh, Oh-My-Zsh, RPMFusion, herramientas)
# Uso: sudo bash fedora-postinstall.sh
# ==================================================

set -euo pipefail

# --------------------------------------------------
# VARIABLES GLOBALES
# --------------------------------------------------
USUARIO="jpineda"
USUARIO_HOME="/home/${USUARIO}"
LOG_FILE="/var/log/fedora-postinstall.log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --------------------------------------------------
# FUNCIONES AUXILIARES
# --------------------------------------------------
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

ok() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root. Usa: sudo bash $0"
    fi
}

check_usuario() {
    if ! id "$USUARIO" &>/dev/null; then
        error "El usuario '$USUARIO' no existe. Créalo primero o cambia la variable USUARIO."
    fi
}

# --------------------------------------------------
# INICIO
# --------------------------------------------------
check_root
check_usuario

# Inicializar log
echo "==========================================" > "$LOG_FILE"
echo "Fedora Post-Install - $(date)" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

log "🚀 Iniciando post-instalación para Fedora..."

# --------------------------------------------------
# PASO 1: ACTUALIZAR EL SISTEMA
# --------------------------------------------------
log "📦 Paso 1/10: Actualizando el sistema..."
dnf update -y >> "$LOG_FILE" 2>&1
ok "Sistema actualizado."

# --------------------------------------------------
# PASO 2: INSTALAR RPMFUSION
# --------------------------------------------------
log "🔧 Paso 2/10: Instalando repositorios RPMFusion..."

FEDORA_VERSION=$(rpm -E %{fedora})
log "   Versión de Fedora detectada: ${FEDORA_VERSION}"

dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
    >> "$LOG_FILE" 2>&1 || warn "RPMFusion Free ya está instalado o falló."

dnf install -y \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm" \
    >> "$LOG_FILE" 2>&1 || warn "RPMFusion NonFree ya está instalado o falló."

ok "Repositorios RPMFusion configurados."

# --------------------------------------------------
# PASO 3: INSTALAR PAQUETES ESENCIALES
# --------------------------------------------------
log "🛠️  Paso 3/10: Instalando paquetes esenciales y herramientas..."

PAQUETES=(
    tree wget curl git
    unzip tar rsync util-linux-user
    nfs-utils bind-utils chrony
    zsh fontconfig bat lsd kitty gh
    dnf-plugins-core
)

dnf install -y "${PAQUETES[@]}" >> "$LOG_FILE" 2>&1
ok "Paquetes instalados: ${#PAQUETES[@]} paquetes."

# --------------------------------------------------
# PASO 4: HABILITAR SERVICIOS
# --------------------------------------------------
log "⚙️  Paso 4/10: Habilitando servicios..."

systemctl enable chronyd >> "$LOG_FILE" 2>&1
systemctl enable firewalld >> "$LOG_FILE" 2>&1 || true

ok "Chrony y Firewalld habilitados."

# --------------------------------------------------
# PASO 5: CONFIGURAR SUDO SIN CONTRASEÑA
# --------------------------------------------------
log "🔐 Paso 5/10: Configurando sudo sin contraseña para '$USUARIO'..."

echo "${USUARIO} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USUARIO}"
chmod 0440 "/etc/sudoers.d/${USUARIO}"

# Validar que el archivo sudoers no tenga errores
visudo -c -f "/etc/sudoers.d/${USUARIO}" >> "$LOG_FILE" 2>&1

ok "Sudo sin contraseña configurado."

# --------------------------------------------------
# PASO 6: CONFIGURAR TIMESTAMP EN HISTORIAL
# --------------------------------------------------
log "🕐 Paso 6/10: Configurando timestamp en el historial..."

cat > /etc/profile.d/hist_timestamp.sh << 'EOF'
export HISTTIMEFORMAT='%d-%m-%Y %H:%M:%S '
EOF
chmod +x /etc/profile.d/hist_timestamp.sh

ok "Timestamp del historial configurado."

# --------------------------------------------------
# PASO 7: ASEGURAR ZSH EN /etc/shells
# --------------------------------------------------
log "🐚 Paso 7/10: Registrando zsh en /etc/shells..."

grep -q '/usr/bin/zsh' /etc/shells || echo '/usr/bin/zsh' >> /etc/shells
ok "Zsh registrado."

# --------------------------------------------------
# PASO 8: CAMBIAR SHELL DEL USUARIO A ZSH
# --------------------------------------------------
log "🔄 Paso 8/10: Cambiando shell por defecto de '$USUARIO' a zsh..."

chsh -s /usr/bin/zsh "$USUARIO" >> "$LOG_FILE" 2>&1 || warn "No se pudo cambiar la shell (puede que ya esté en zsh)."
ok "Shell cambiada a zsh."

# --------------------------------------------------
# PASO 9: CONFIGURAR ENTORNO ZSH DEL USUARIO
# --------------------------------------------------
log "🎨 Paso 9/10: Configurando entorno Zsh para '$USUARIO'..."

cat > /tmp/setup-zsh.sh << 'USEREOF'
#!/usr/bin/env bash
set -e

# 1. Hack Nerd Font
echo "🔤 Instalando Hack Nerd Font..."
mkdir -p ~/.local/share/fonts
curl -sL -o /tmp/Hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
unzip -oq /tmp/Hack.zip -d ~/.local/share/fonts/
rm -f /tmp/Hack.zip
fc-cache -f ~/.local/share/fonts/ >/dev/null 2>&1

# 2. Oh-My-Zsh
echo "⚙️  Instalando Oh-My-Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh 2>/dev/null
fi
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

# 3. Plugins en .zshrc
sed -i -E 's/^plugins=\(.*\)/plugins=(sudo git z zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/g' ~/.zshrc
grep -q 'source ~/.alias' ~/.zshrc || echo "source ~/.alias" >> ~/.zshrc
grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc || \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 4. Clonar plugins externos
echo "🔌 Clonando plugins de Zsh..."
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$PLUGINS_DIR"

for plugin in zsh-syntax-highlighting zsh-autosuggestions zsh-completions; do
    if [ ! -d "$PLUGINS_DIR/$plugin" ]; then
        git clone --depth=1 "https://github.com/zsh-users/${plugin}.git" "$PLUGINS_DIR/$plugin" 2>/dev/null
    fi
done

# 5. Instalar sshs
echo "🧩 Instalando sshs..."
mkdir -p ~/.local/bin
if [ ! -f ~/.local/bin/sshs ]; then
    curl -sL https://github.com/quantumsheep/sshs/releases/latest/download/sshs-linux-amd64 -o ~/.local/bin/sshs
    chmod +x ~/.local/bin/sshs
fi

# 6. Crear ~/.alias
echo "📝 Creando ~/.alias..."
cat > ~/.alias <<'ALIAS_EOF'
# --- Modernización de comandos ---
alias cat='bat'
alias ll='lsd -lh --group-dirs=first'
alias la='lsd -a --group-dirs=first'
alias l='lsd --group-dirs=first'
alias lla='lsd -lha --group-dirs=first'
alias ls='lsd --group-dirs=first'
alias lst='lsd --tree --group-dirs=first'
alias cls='clear'
alias ssh="kitty +kitten ssh"

# --- Utilidades Git ---
gitp() {
    git add .
    git commit -m "${1:-update: $(date +'%d-%m-%Y %H:%M')}"
    git push origin main
}

unalias gnew 2>/dev/null || true
gnew() {
  git init -b main 2>/dev/null
  git branch -M main 2>/dev/null
  if [ -z "$(ls -A --ignore='.git' 2>/dev/null)" ]; then
    echo "# $(basename "$PWD")" > README.md
  fi
  git add -A
  git commit -m "init" 2>/dev/null || git commit -m "init" --allow-empty
  gh repo create --source . --remote origin --push --private
}

alias sshs='\sshs -c ~/.ssh/servers'
ALIAS_EOF

# 7. Archivos SSH
mkdir -p ~/.ssh
touch ~/.ssh/servers ~/.ssh/config
chmod 700 ~/.ssh
chmod 600 ~/.ssh/servers ~/.ssh/config

echo "✅ Entorno Zsh configurado."
USEREOF

chmod +x /tmp/setup-zsh.sh
sudo -u "$USUARIO" bash /tmp/setup-zsh.sh >> "$LOG_FILE" 2>&1
rm -f /tmp/setup-zsh.sh

ok "Entorno Zsh configurado para '$USUARIO'."

# --------------------------------------------------
# PASO 10: LIMPIEZA
# --------------------------------------------------
log "🧹 Paso 10/10: Limpiando caché de dnf..."
dnf clean all >> "$LOG_FILE" 2>&1
ok "Caché limpiada."

# --------------------------------------------------
# RESUMEN FINAL
# --------------------------------------------------
echo ""
echo "=========================================="
echo -e "${GREEN}🎉 POST-INSTALACIÓN COMPLETADA${NC}"
echo "=========================================="
echo ""
echo "📋 Resumen:"
echo "   • Usuario configurado: $USUARIO"
echo "   • Shell por defecto: zsh"
echo "   • Log completo: $LOG_FILE"
echo ""
echo "📌 Próximos pasos manuales:"
echo "   1. Cierra sesión y vuelve a entrar (o ejecuta: exec zsh)"
echo "   2. Autentícate en GitHub: gh auth login"
echo "   3. Edita ~/.ssh/servers con tus servidores SSH"
echo "   4. Configura Konsole para usar la fuente 'Hack Nerd Font'"
echo ""
