import subprocess
import getpass

def recreate_database(db_name, password):
    """
    Recrea una base de datos MariaDB con el juego de caracteres utf8mb4 y colación utf8mb4_unicode_ci.

    Args:
        db_name (str): El nombre de la base de datos.
        password (str): La contraseña del usuario root de MariaDB.
    """
    try:
        # Eliminar la base de datos si existe
        drop_command = [
            "mariadb",
            "-u", "root",
            f"-p{password}",
            "-e", f"DROP DATABASE IF EXISTS `{db_name}`;"
        ]
        subprocess.run(drop_command, check=True, capture_output=True)

        # Crear la base de datos nuevamente
        create_command = [
            "mariadb",
            "-u", "root",
            f"-p{password}",
            "-e", f"CREATE DATABASE `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        ]
        subprocess.run(create_command, check=True, capture_output=True)


        print(f"La base de datos '{db_name}' ha sido recreada con el conjunto de caracteres utf8mb4_unicode_ci")

    except subprocess.CalledProcessError as e:
      print(f"Error al ejecutar comandos de MariaDB: {e.stderr.decode()}")
      exit(1)
    except Exception as e:
        print(f"Ocurrió un error inesperado: {e}")
        exit(1)

def run_php_migrate():
    """Ejecuta el comando 'php spark migrate'."""
    try:
        migrate_command = ["php", "spark", "migrate"]
        subprocess.run(migrate_command, check=True, capture_output=True)
        print("Comando 'php spark migrate' ejecutado con éxito.")
    except subprocess.CalledProcessError as e:
         print(f"Error al ejecutar 'php spark migrate': {e.stderr.decode()}")
         exit(1)
    except Exception as e:
         print(f"Ocurrió un error inesperado: {e}")
         exit(1)


if __name__ == "__main__":
    # Solicitar el nombre de la base de datos
    db_name = input("Ingrese el nombre de la base de datos: ")

    # Solicitar la contraseña de MariaDB de forma segura
    password = getpass.getpass("Ingrese la contraseña de MariaDB: ")

    # Recrear la base de datos
    recreate_database(db_name, password)

    # Ejecutar el comando de migración
    run_php_migrate()
