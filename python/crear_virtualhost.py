import os
import getpass
import subprocess

def solicitar_dominio():
    while True:
        dominio = input("Ingrese el nombre del dominio: ")
        if dominio.isalnum():
            return f"{dominio}.local"
        else:
            print("El nombre del dominio solo puede contener letras y números. Inténtelo de nuevo.")

def solicitar_ruta_document_root():
    return input("Ingrese la ruta del DocumentRoot, ejem dominio/public: ")

def crear_virtual_host(dominio, document_root):
    vhost_conf = f"/etc/httpd/conf.d/{dominio}.conf"
    document_root_path = f"/var/www/{document_root}"

    if os.path.exists(vhost_conf):
        reemplazar = input(f"El virtual host {dominio} ya existe. ¿Desea reemplazarlo? (s/n): ")
        if reemplazar.lower() != "s":
            print("Operación cancelada. No se ha creado ni modificado ningún virtual host.")
            exit(1)

    vhost_content = f"""<VirtualHost *:80>
    DocumentRoot "{document_root_path}"
    ServerName {dominio}
    ServerAlias *.{dominio}

    ErrorLog /var/log/httpd/{dominio}-error_log
    CustomLog /var/log/httpd/{dominio}-access_log combined

    <Directory "{document_root_path}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>"""

    with open(vhost_conf, "w") as f:
        f.write(vhost_content)

    print(f"Virtual host creado en {vhost_conf}")

    return vhost_conf

def crear_virtual_host_ssl(dominio, document_root):
    ssl_vhost_conf = f"/etc/httpd/conf.d/{dominio}-ssl.conf"
    document_root_path = f"/var/www/{document_root}"

    ssl_vhost_content = f"""<VirtualHost *:443>
    DocumentRoot "{document_root_path}"
    ServerName {dominio}
    ServerAlias *.{dominio}

    # Redirigir todo el tráfico HTTP a HTTPS
    RewriteEngine On
    RewriteCond %{{HTTPS}} off
    RewriteRule ^(.*)$ https://%{{HTTP_HOST}}%{{REQUEST_URI}} [L,R=301]

    ErrorLog /var/log/httpd/{dominio}-ssl_error_log
    CustomLog /var/log/httpd/{dominio}-ssl_access_log combined

    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/wildcard.local.crt
    SSLCertificateKeyFile /etc/pki/tls/private/wildcard.local.key

    <Directory "{document_root_path}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>"""

    with open(ssl_vhost_conf, "w") as f:
        f.write(ssl_vhost_content)

    print(f"Virtual host SSL creado en {ssl_vhost_conf}")

    return ssl_vhost_conf

def reiniciar_httpd():
    try:
        subprocess.run(["systemctl", "restart", "httpd"], check=True)
        print("Servicio httpd reiniciado")
    except subprocess.CalledProcessError as e:
        print(f"Error al reiniciar el servicio httpd: {e}")

if __name__ == "__main__":
    dominio = solicitar_dominio()
    document_root = solicitar_ruta_document_root()

    vhost_conf = crear_virtual_host(dominio, document_root)

    crear_ssl = input("¿Desea crear también el virtual host SSL? (s/n): ")
    if crear_ssl.lower() == "s":
        ssl_vhost_conf = crear_virtual_host_ssl(dominio, document_root)
        # Agregar redirección al primer virtual host
        with open(vhost_conf, "a") as f:
            f.write(f'\n    # Redirigir todo el tráfico HTTP a HTTPS\n    RewriteEngine On\n    RewriteCond %{{HTTPS}} off\n    RewriteRule ^(.*)$ https://%{{HTTP_HOST}}%{{REQUEST_URI}} [L,R=301]\n')
        print(f"Redirección HTTP a HTTPS agregada en {vhost_conf}")

    reiniciar_httpd()
    print("Virtual hosts creados y servicio httpd reiniciado")
