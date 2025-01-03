import os
import subprocess

def crear_virtualhost():
    """Crea un virtualhost para Apache con configuración HTTP y HTTPS."""

    # Solicitar el nombre de dominio al usuario
    dominio = input("Ingrese el nombre del dominio, ejem: midominio.con: ")

    # Solicitar el nombre del proyecto este se guarda en /var/www/
    name_proyect = input("Ingrese el nombre del proyecto, este estara ubicado en /vaw/www/, ejem: miproyecto: ")

    # Construir la ruta completa del documento raiz
    root = f"/var/www/{name_proyect}"

    conf_file = f"/etc/httpd/conf.d/{dominio}.conf"
    ssl_conf_file = f"/etc/httpd/conf.d/{dominio}.ssl.conf"

    # Verificar si el archivo de configuración ya existe
    if os.path.exists(conf_file):
        reemplazar = input(f'Ya existe un virtualhost para el dominio "{dominio}" ¿Desea reemplazarlo? (y/n): ')
        if reemplazar.lower() != 'y':
            print("Operación cancelada. No se ha modificado el virtualhost actual.")
            return

    # Generar el archivo de configuración HTTP
    with open(conf_file, "w") as f:
        f.write(f"""<VirtualHost *:80>
    DocumentRoot "{root}"
    ServerName {dominio}
    ServerAlias *.{dominio}

    ErrorLog /var/log/httpd/{dominio}-error_log
    CustomLog /var/log/httpd/{dominio}-access_log combined

    <Directory "{root}">
        AllowOverride All
        Require all granted
    </Directory>

    # Redirigir todo el tráfico HTTP a HTTPS
    RewriteEngine On
    RewriteCond %{{HTTPS}} off
    RewriteRule ^(.*)$ https://%{{HTTP_HOST}}%{{REQUEST_URI}} [L,R=301]
</VirtualHost>
""")

    # Generar el archivo de configuración HTTPS
    with open(ssl_conf_file, "w") as f:
        f.write(f"""<VirtualHost *:443>
    DocumentRoot "{root}"
    ServerName {dominio}
    ServerAlias *.{dominio}

    ErrorLog /var/log/httpd/{dominio}-ssl_error_log
    CustomLog /var/log/httpd/{dominio}-ssl_access_log combined

    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/wildcard.local.crt
    SSLCertificateKeyFile /etc/pki/tls/private/wildcard.local.key

    <Directory "{root}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
""")

    # Reiniciar Apache
    try:
        subprocess.run(["systemctl", "restart", "httpd"], check=True)
        print(f'Virtualhost creado para el dominio "{dominio}" con éxito !!!.')
    except subprocess.CalledProcessError as e:
        print(f'Error al reiniciar Apache: {e}')


if __name__ == "__main__":
    crear_virtualhost()
