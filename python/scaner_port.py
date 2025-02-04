import socket
import concurrent.futures
from datetime import datetime
import os

def scan_port(ip, port):
    """
    Escanea un puerto específico en la dirección IP proporcionada.
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex((ip, port))
        if result == 0:
            print(f"Puerto {port} está abierto")
        sock.close()
    except Exception as e:
        print(f"Error al escanear el puerto {port}: {e}")

def scan_all_ports(ip):
    """
    Escanea todos los puertos (1-65535) en la dirección IP proporcionada.
    """
    print(f"Escaneando todos los puertos en {ip}...")
    start_time = datetime.now()

    # Ajustar max_workers basado en los núcleos de la CPU
    cpu_cores = os.cpu_count() or 1  # Si os.cpu_count() devuelve None, usa 1
    max_workers = cpu_cores * 128  # Ajusta el multiplicador según sea necesario
    print(f"Usando {max_workers} hilos para el escaneo...")

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(scan_port, ip, port) for port in range(1, 65536)]
        concurrent.futures.wait(futures)

    end_time = datetime.now()
    print(f"Escaneo completado en: {end_time - start_time}")

if __name__ == "__main__":
    target_ip = input("Introduce la dirección IP a escanear: ")
    scan_all_ports(target_ip)
