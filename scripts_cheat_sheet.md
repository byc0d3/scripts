# 🚀 Suite de Automatización Rocky Linux - Cheat Sheet

Esta es la guía de referencia rápida para ejecutar cualquiera de los scripts de infraestructura. Recuerda reemplazar `"URL"` por el enlace real (ej. GitHub Raw, GitLab o tu servidor web) donde estén alojados los scripts.

---

## 1. Servidor Base (`server.sh`)
*Prepara el servidor, aplica reglas sysctl, limits y Fail2Ban.*

**Modo Interactivo:**
```bash
curl -fsSL "URL/server.sh" -o /tmp/server.sh && sudo bash /tmp/server.sh
```

**Modo No Interactivo:**
```bash
curl -fsSL "URL/server.sh" -o /tmp/server.sh && sudo HOSTNAME="srv-app.dominio.local" bash /tmp/server.sh
```

---

## 2. PHP (`php.sh`)
*Instala PHP de Remi Repo con FPM optimizado.*

**Modo Interactivo:**
```bash
curl -fsSL "URL/php.sh" -o /tmp/php.sh && sudo bash /tmp/php.sh
```

**Modo No Interactivo:**
```bash
curl -fsSL "URL/php.sh" -o /tmp/php.sh && sudo PHP_VERSION="8.3" bash /tmp/php.sh
```

---

## 3. PostgreSQL (`postgres.sh`)
*Instala Postgres 18 bloqueando root y creando el usuario de red `admindb`.*

**Modo Único (100% Automático):**
```bash
curl -fsSL "URL/postgres.sh" -o /tmp/postgres.sh && sudo bash /tmp/postgres.sh
```

---

## 4. MariaDB (`mariadb.sh`)
*Detecta e instala la última versión estable, securiza y crea `admindb`.*

**Modo Único (100% Automático):**
```bash
curl -fsSL "URL/mariadb.sh" -o /tmp/mariadb.sh && sudo bash /tmp/mariadb.sh
```

---

## 5. Configuración de Red (`set_network.sh`)
*Configura IP estática y reglas PBR (Policy Based Routing).*

**Modo Interactivo:**
```bash
curl -fsSL "URL/set_network.sh" -o /tmp/set_network.sh && sudo bash /tmp/set_network.sh
```

**Modo No Interactivo (Tarjeta Enrutada - con Gateway):**
```bash
curl -fsSL "URL/set_network.sh" -o /tmp/set_network.sh && sudo DEVICE="ens224" IP="10.31.196.49" PREFIX="25" GW="10.31.196.1" bash /tmp/set_network.sh
```

**Modo No Interactivo (Red Local/Backend - Sin Gateway):**
```bash
curl -fsSL "URL/set_network.sh" -o /tmp/set_network.sh && sudo DEVICE="ens225" IP="192.168.10.5" PREFIX="24" GW="" bash /tmp/set_network.sh
```

---

## 6. Agregar Nuevo Disco (`extend_volume.sh`)
*Agrega un nuevo disco físico al servidor (ej. `/dev/sdc`) y expande el volumen LVM.*

**Modo Interactivo:**
```bash
curl -fsSL "URL/extend_volume.sh" -o /tmp/extend_volume.sh && sudo bash /tmp/extend_volume.sh
```

**Modo No Interactivo:**
```bash
curl -fsSL "URL/extend_volume.sh" -o /tmp/extend_volume.sh && sudo TARGET_DISK="/dev/sdc" TARGET_PATH="/home" bash /tmp/extend_volume.sh
```

---

## 7. Redimensionar Disco Existente (`resize_volume.sh`)
*Detecta crecimiento del disco desde VMware/AWS, estira la partición y expande el volumen LVM.*

**Modo Interactivo:**
```bash
curl -fsSL "URL/resize_volume.sh" -o /tmp/resize_volume.sh && sudo bash /tmp/resize_volume.sh
```

**Modo No Interactivo:**
```bash
curl -fsSL "URL/resize_volume.sh" -o /tmp/resize_volume.sh && sudo TARGET_PV="/dev/sda2" TARGET_PATH="/" bash /tmp/resize_volume.sh
```
