import socket
import concurrent.futures
from tqdm import tqdm
import os

# Función para escanear un puerto específico en una dirección IP
def scan_port(ip, port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)  # Establecer un tiempo de espera de 1 segundo
            result = sock.connect_ex((ip, port))
            return port, result == 0
    except socket.error:
        return port, False  # Devuelve False si hay un error de socket


# Función para escanear todos los puertos en una dirección IP
def scan_all_ports(ip, max_workers=None, ports_to_scan=None):
    open_ports = []

    if not max_workers:
        max_workers = os.cpu_count() * 2

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(scan_port, ip, port): port for port in ports_to_scan}
        for future in tqdm(concurrent.futures.as_completed(futures), total=len(ports_to_scan), desc="Escaneando puertos"):
            try:
                port, is_open = future.result()
                if is_open:
                    open_ports.append(port)
            except Exception as e:
                print(f"Error al escanear el puerto {port}: {e}")

    return open_ports


# Puertos comunes predefinidos
common_ports = [21, 22, 23, 25, 53, 80, 110, 139, 443, 445, 3389, 8080]

# Solicitar al usuario la dirección IP o el dominio
ip_or_domain = input("Ingrese la dirección IP o el dominio a escanear: ")

# Obtener la dirección IP del dominio
try:
    ip = socket.gethostbyname(ip_or_domain)
    print(f"Escaneando {ip_or_domain} ({ip})...")
except socket.gaierror:
    print("Error: No se pudo resolver la dirección IP del dominio.")
    exit(1)


# Pregunta al usuario y muestra los puertos comunes
use_common_ports = input(f"¿Escanear solo puertos comunes? (s/n, por defecto n) Los puertos comunes son: {common_ports}: ").strip().lower()

if use_common_ports == "s":
    ports_to_scan = common_ports
    print(f"Escaneando puertos comunes: {ports_to_scan}")
elif use_common_ports == "n" or use_common_ports == "":
    ports_to_scan = range(1, 65536)
    print(f"Escaneando todos los puertos (1-65535)")
else:
    print("Respuesta no válida. Escaneando todos los puertos por defecto")
    ports_to_scan = range(1, 65536)


open_ports = scan_all_ports(ip, ports_to_scan=ports_to_scan)

if open_ports:
    open_ports.sort()  # Ordenar la lista de puertos abiertos de menor a mayor
    print(f"Puertos abiertos en {ip_or_domain} ({ip}):")
    for port in open_ports:
        print(f"  - {port}")  # Imprimir cada puerto en una nueva línea con sangría
else:
    print(f"No se encontraron puertos abiertos en {ip_or_domain} ({ip}).")
