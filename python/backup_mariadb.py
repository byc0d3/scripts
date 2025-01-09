import os
import subprocess
import mysql.connector
from mysql.connector import errorcode
from datetime import datetime, timedelta
import zipfile

# Configuración de la base de datos
db_config = {
    'user': 'backup',
    'password': 'backup',
    'host': 'localhost'
}

# Directorio base donde se guardarán los respaldos
backup_dir = '/home'

# Días de retención de los respaldos diarios
retention_days = 7

# Conexión a la base de datos
try:
    cnx = mysql.connector.connect(**db_config)
    cursor = cnx.cursor()
    cursor.execute("SHOW DATABASES")
    databases = cursor.fetchall()
except mysql.connector.Error as err:
    if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
        print("Error: Usuario o contraseña incorrectos")
    else:
        print(err)
else:
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)

    for (database,) in databases:
        if database in ('information_schema', 'mysql', 'performance_schema', 'sys'):
            continue  # Excluir bases de datos del sistema

        # Crear carpetas para respaldos diarios y mensuales
        db_backup_dir = os.path.join(backup_dir, database)
        daily_backup_dir = os.path.join(db_backup_dir, 'diario')
        monthly_backup_dir = os.path.join(db_backup_dir, 'mensual')

        if not os.path.exists(daily_backup_dir):
            os.makedirs(daily_backup_dir)
        if not os.path.exists(monthly_backup_dir):
            os.makedirs(monthly_backup_dir)

        # Formatear el nombre del respaldo
        timestamp = datetime.now().strftime('%d-%m-%Y_%H-%M-%S')
        backup_file = f"{daily_backup_dir}/{database}_{timestamp}.sql"

        # Ejecutar el comando mysqldump
        dump_cmd = f"mysqldump -u{db_config['user']} -p{db_config['password']} -h {db_config['host']} {database} > {backup_file}"
        subprocess.run(dump_cmd, shell=True)

        # Comprimir el archivo .sql en un archivo zip
        zip_file = f"{backup_file}.zip"
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, os.path.basename(backup_file))

        # Eliminar el archivo .sql original
        os.remove(backup_file)
        print(f"Backup de la base de datos '{database}' completado y comprimido en '{zip_file}'")

        # Guardar el respaldo mensual si es el primer día del mes
        if datetime.now().day == 1:
            monthly_backup_file = os.path.join(monthly_backup_dir, os.path.basename(zip_file))
            os.rename(zip_file, monthly_backup_file)
            print(f"Respaldo mensual guardado en '{monthly_backup_file}'")

        # Eliminar respaldos diarios antiguos
        current_time = datetime.now()
        for filename in os.listdir(daily_backup_dir):
            file_path = os.path.join(daily_backup_dir, filename)
            if os.path.isfile(file_path):
                file_time = datetime.fromtimestamp(os.path.getmtime(file_path))
                if current_time - file_time > timedelta(days=retention_days):
                    os.remove(file_path)
                    print(f"Archivo antiguo eliminado: {file_path}")

    cursor.close()
    cnx.close()
