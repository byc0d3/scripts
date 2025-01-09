import subprocess

def run_command(command):
    """Ejecuta un comando y muestra la salida."""
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        print(result.stdout)
    else:
        print(f"Error al ejecutar el comando: {command}")
        print(result.stderr)

# Solicitar información al usuario
ip = input("Introduce la dirección IP del Servidor (IP): ")
prefix = input("Introduce la Prefijo de la mascara IP (PREFIX): ")
gw = input("Introduce la puerta de enlace (GW): ")
device = input("Introduce el nombre del dispositivo (DEVICE): ")

# Resto de la información fija
table = 5000

# Configurar la conexión con nmcli
run_command(f"nmcli con add con-name {device} type ethernet ifname {device} ipv4.method manual ipv4.address {ip}/{prefix} ipv6.method disabled")

# Activar la conexión
run_command(f"nmcli con up {device}")

# Modificar la configuración de la conexión
run_command(f"nmcli con mod {device} ip4 {ip}/{prefix} gw4 {gw}")
run_command(f"nmcli con mod {device} ipv4.route-table {table}")
run_command(f"nmcli con mod {device} ipv4.routing-rules \"priority 5 iif {device} table {table}\"")
run_command(f"nmcli con mod {device} +ipv4.routing-rules \"priority 5 from {ip} table {table}\"")

# Desactivar y activar la conexión para aplicar los cambios
run_command(f"nmcli con down {device}")
run_command(f"nmcli con up {device}")

# Mostrar la información de la conexión
run_command(f"nmcli con show {device}")
