import socket
import concurrent.futures
from datetime import datetime
import os

def scan_port(ip, port):
    """Escanea un puerto específico en la dirección IP proporcionada."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # Mejora el rendimiento del socket
            sock.settimeout(0.5)  # Reduce el tiempo de espera de conexión
            if sock.connect_ex((ip, port)) == 0:
                print(f"Puerto {port} abierto")
    except Exception:
        pass  # Evita imprimir errores innecesarios para acelerar la ejecución

def scan_port_range(ip, ports):
    """Escanea un conjunto de puertos usando múltiples hilos en cada proceso."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=256) as executor:
        executor.map(lambda port: scan_port(ip, port), ports, chunksize=100)  # Ajuste de chunk_size para eficiencia

def scan_all_ports(ip):
    """Divide el escaneo en múltiples procesos para aprovechar todos los núcleos de la CPU."""
    start_time = datetime.now()

    cpu_cores = os.cpu_count() or 1
    num_processes = min(cpu_cores, 8)  # Evita la sobrecarga de demasiados procesos
    print(f"Usando {num_processes} procesos con 256 hilos cada uno...")

    port_ranges = [list(range(start, min(start + 8192, 65536))) for start in range(1, 65536, 8192)]  # Dividir puertos

    with concurrent.futures.ProcessPoolExecutor(max_workers=num_processes) as executor:
        executor.map(scan_port_range, [ip] * len(port_ranges), port_ranges, chunksize=1)  # Ejecuta en paralelo

    end_time = datetime.now()
    print(f"Escaneo completado en: {end_time - start_time}")

if __name__ == "__main__":
    target_ip = input("Introduce la dirección IP a escanear: ")
    scan_all_ports(target_ip)
