# Despliegue de WordPress Multisite, Adminer como gestor gráfico de BBDD y Nginx como proxy inverso paso a paso.

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

En este tutorial vamos a mostrar como realizar un despliegue de `WordPress` multisite para un entorno de desarrollo, por lo tanto necesitaremos levantar un contenedor con `MySQL` (en este caso `MariaDB`), también haremos uso de `Adminer` para tener un gestor gráfico de BBDD y usaremos el servidor web `Nginx` como proxy inverso para simplificar las URL's evitando escribir puertos y securizando las conexiones con https.

### Ejemplo de `docker-compose.yaml` para un despliegue básico

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress

  wp:
    image: wordpress 
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: rootpassword

  adminer:
    image: adminer
    ports: 
      - "8000:8080"
```

Una vez ejecutado:

```bash
docker-compose up -d
```

podremos acceder a nuestro `WordPress` en la URL:

```http
http://localhost
```

![localhost.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/localhost.PNG)

Igualmente para `Adminer` en la URL:

```http
http://localhost:8000
```

![localhost_8000.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/localhost_8000.PNG)

Como podemos observar tanto el acceso a `WordPress` como a `Adminer` no estan securizados, además de tener que escribir en la URL el puerto. Para simplificar el acceso usaremos `Nginx` como proxy inverso, asi nuestra URL de la app `Adminer` sería:

```http
http://localhost/adminer
```

Además crearemos un certificado autofirmado para que el acceso sea `https` en vez de `http`.

También comentar que no estamos haciendo uso de volumenes persistentes para poder acceder a nuestros datos en caso de querer realizar un `backup` comodamente y además nuestras constraseñas están en texto plano en las variables de entorno.

### Añadimos `Nginx` a nuestro `docker-compose.yaml`

Levantamos un contenedor con `Nginx`, aunque aún seguiremos accediendo via `http`. Posteriormente crearemos un certificado autofirmado y configuraremos en nuestro container el puerto `443`. También debemos volcar la configuración de nuestro servidor `Nginx` en el contenedor, para ello usaremos un punto de montaje llamado `Bind` (con esto, lo que hacemos es mapear un directorio de nuestro `Host` al container en cuestión).

Nuestro fichero `docker-compose.yaml` quedaría de la siguiente forma:

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress

  wp:
    image: wordpress 
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: rootpassword

  adminer:
    image: adminer

  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./services/nginx:/etc/nginx/conf.d
```

Como se puede observar, hemos creado un directorio llamado `services` y dentro otro llamado `nginx` donde ubicaremos el fichero de configuración de nuestro servidor web que hará las funciones de servidor proxy inverso. Para volcar la configuración en nuestro contenedor de `nginx` montamos dicho `bind` con el fichero `nginx.conf` en el directorio del container `/etc/nginx/conf.d`.

Nuestro fichero `nginx.conf` sería el siguiente:

```nginx
server {
  proxy_set_header Host $host;

  location / {
    proxy_pass http://wp;
  }

  location /adminer {
    proxy_pass http://adminer:8080;
  }
}
```

Directivas:

- **`server`**: Establece el bloque para la configuración de un servidor virtual. De forma predeterminada, nuestro servidor escuchará en el puerto 80. Nuestra configuración de servidor virtual, tiene una única directiva simple, `proxy_set_header`, y dos directivas de bloque `location`.

- **`proxy_set_header Host`**: De forma predeterminada, `nginx` modifica el encabezado de solicitud pasado al servidor proxy para reflejar el bloque `location` correspondiente y los parámetros `proxy_pass`. Sin embargo, esta directiva anula este comportamiento y sustituye la variable `$host` en su lugar. Para nuestras directivas `proxy_pass` , el resultado es como si la solicitud viniera del propio host en lugar de pasar por el servidor proxy.

- **`location / or location /adminer`**: `nginx` usa la directiva `location` para determinar cómo manejar las peticiones del navegador. En nuestra configuración, tenemos dos bloques de `location`. La directiva `location /` actúa como valor predeterminado y se utilizará si no se encuentran otras directivas `location` que coincidan con el URI solicitado. Por lo tanto, cualquier solicitud dirigida a `http://<host>/adminer` será manejada por el bloque `location /adminer` y pasará a través de su directiva `proxy_pass`. Todas las demás solicitudes serán manejadas por la directiva `locatin /` y pasadas al servicio WordPress. 

- **`proxy_pass`**: Establece el protocolo y la dirección del servicio proxy. Nuestros dos servicios usan el protocolo http. Hemos usado el nombre del servicio para enviar el URI solicitado. Docker reemplazará el nombre del servicio, `wp` o `adminer` en nuestro caso, con la dirección IP apropiada del servicio. 

Para más información disponemos de la documentación oficial:

[nginx documentation](https://nginx.org/en/docs/)

Ahora si ejecutamos:

```bash
docker-compose up -d
```

Podremos acceder a nuestros servicios de la siguiente forma:

WordPress:

```http
http://localhost
```

![localhost_nginx_http.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/localhost_nginx_http.PNG)

Adminer:

```http
http://localhost/adminer
```

![localhost_nginx_http_adminer.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/localhost_nginx_http_adminer.PNG)

Como hemos citado anteriormente, para configurar nuestro contenedor con el servidor `nginx` como proxy inverso, hemos usado un punto de montaje `Bind`. Lo hemos declarado en nuestro fichero `docker-compose.yaml` de la siguiente forma:

```yaml
nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./services/nginx:/etc/nginx/conf.d
```

Los volumenes de tipo `Bind` no tenemos que declararlos en la raiz de nuestro fichero `docker-compose.yaml` tal como hacemos con la directiva `services`. 

Además como es de suponer los servicios `db` y `wp` almacenan sus datos, en este caso al no declararlos nosotros mismos, Docker lo hace de forma `anónima` (posteriormente los declararemos con otro tipo que no son ni `Bind` ni `Anónimos`, son los volumenes llamados `Named`).

### Gestionando la información de los Volumenes

Tenemos varias formas de ver la información y los datos almacenados en los volumenes de nuestros containers.

Ejecutamos el siguiente comando para ver todos los volumenes creados:

```bash
docker volume ls
```

la salida será algo similar a lo siguiente:

```bash
DRIVER    VOLUME NAME
local     894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559
local     eb5726acd56632c02e3ffcd4136231e07d5dd19e34eb9bf8fcc2c52c57ac0f94
```

Ahora inspeccionamos uno de los volumenes ejecutando:

```bash
docker inspect 894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559
```

Y obtendremos una salida similar a esta:

```bash
"CreatedAt": "2023-01-30T10:24:45Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559/_data",
        "Name": "894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559",
        "Options": null,
        "Scope": "local"
```

Como se puede ver en `Mountpoint` los ficheros están montados en nuestro `Host` local en `/var/lib/docker/volumes`. El comando anterior lo podemos ejecutar contra el container directamente y no sobre el volumen, lo que nos mostrará más información y un dato importante que sería `Destination`.

```bash
docker inspect wordpress-wp-1
```

```bash
"Mounts": [
            {
                "Type": "volume",
                "Name": "894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559",
                "Source": "/var/lib/docker/volumes/894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559/_data",
                "Destination": "/var/www/html",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ]
```

Vemos que el punto de montaje de destino en el contenedor es `/var/www/html`, es decir el directorio de `Apache` (servidor web que usa `WordPress`) y que nos será de utilidad para ver otra forma de inspeccionar los datos de nuestros contenedores.

Al ejecutar un listado del directorio en este caso vemos lo siguiente:

```bash
sudo ls -l /var/lib/docker/volumes/894fdc0ef8e26b047187761ad0143449b4d4a911c575e131bd94ac148fc17559/_data
total 244
-rw-r--r--  1 www-data www-data   405 Feb  6  2020 index.php
-rw-r--r--  1 www-data www-data 19915 Jan  1  2022 license.txt
-rw-r--r--  1 www-data www-data  7389 Sep 16 22:27 readme.html
-rw-r--r--  1 www-data www-data  7205 Sep 16 23:13 wp-activate.php
drwxr-xr-x  9 www-data www-data  4096 Nov 15 19:03 wp-admin
-rw-r--r--  1 www-data www-data   351 Feb  6  2020 wp-blog-header.php
-rw-r--r--  1 www-data www-data  2338 Nov  9  2021 wp-comments-post.php
-rw-rw-r--  1 www-data www-data  5480 Jan 12 00:03 wp-config-docker.php
-rw-r--r--  1 www-data www-data  5584 Jan 30 10:24 wp-config.php
-rw-r--r--  1 www-data www-data  3001 Dec 14  2021 wp-config-sample.php
drwxr-xr-x  5 www-data www-data  4096 Jan 30 10:24 wp-content
-rw-r--r--  1 www-data www-data  5543 Sep 20 15:44 wp-cron.php
drwxr-xr-x 27 www-data www-data 16384 Nov 15 19:03 wp-includes
-rw-r--r--  1 www-data www-data  2494 Mar 19  2022 wp-links-opml.php
-rw-r--r--  1 www-data www-data  3985 Sep 19 08:59 wp-load.php
-rw-r--r--  1 www-data www-data 49135 Sep 19 22:26 wp-login.php
-rw-r--r--  1 www-data www-data  8522 Oct 17 11:06 wp-mail.php
-rw-r--r--  1 www-data www-data 24587 Sep 26 10:17 wp-settings.php
-rw-r--r--  1 www-data www-data 34350 Sep 17 00:35 wp-signup.php
-rw-r--r--  1 www-data www-data  4914 Oct 17 11:22 wp-trackback.php
-rw-r--r--  1 www-data www-data  3236 Jun  8  2020 xmlrpc.php
```

Como podemos observer se trata de la aplicacion `WordPress`.

Otra forma sería conectandonos a nuestro contenedor desde una `bash` ejecutando el siguiente comando:

```bash
docker exec -it wordpress-wp-1 /bin/bash
```

Como se puede ver nos conectamos como usuario `root` y directamente al directorio de trabajo del contenedor `/var/www/html`, ejecutamos un listado del directorio y verémos el mismo resultado:

```bash
root@81dea7f08b79:/var/www/html# ls -l
total 244
-rw-r--r--  1 www-data www-data   405 Feb  6  2020 index.php
-rw-r--r--  1 www-data www-data 19915 Jan  1  2022 license.txt
-rw-r--r--  1 www-data www-data  7389 Sep 16 22:27 readme.html
-rw-r--r--  1 www-data www-data  7205 Sep 16 23:13 wp-activate.php
drwxr-xr-x  9 www-data www-data  4096 Nov 15 19:03 wp-admin
-rw-r--r--  1 www-data www-data   351 Feb  6  2020 wp-blog-header.php
-rw-r--r--  1 www-data www-data  2338 Nov  9  2021 wp-comments-post.php
-rw-rw-r--  1 www-data www-data  5480 Jan 12 00:03 wp-config-docker.php
-rw-r--r--  1 www-data www-data  3001 Dec 14  2021 wp-config-sample.php
-rw-r--r--  1 www-data www-data  5584 Jan 30 10:24 wp-config.php
drwxr-xr-x  5 www-data www-data  4096 Jan 30 10:24 wp-content
-rw-r--r--  1 www-data www-data  5543 Sep 20 15:44 wp-cron.php
drwxr-xr-x 27 www-data www-data 16384 Nov 15 19:03 wp-includes
-rw-r--r--  1 www-data www-data  2494 Mar 19  2022 wp-links-opml.php
-rw-r--r--  1 www-data www-data  3985 Sep 19 08:59 wp-load.php
-rw-r--r--  1 www-data www-data 49135 Sep 19 22:26 wp-login.php
-rw-r--r--  1 www-data www-data  8522 Oct 17 11:06 wp-mail.php
-rw-r--r--  1 www-data www-data 24587 Sep 26 10:17 wp-settings.php
-rw-r--r--  1 www-data www-data 34350 Sep 17 00:35 wp-signup.php
-rw-r--r--  1 www-data www-data  4914 Oct 17 11:22 wp-trackback.php
-rw-r--r--  1 www-data www-data  3236 Jun  8  2020 xmlrpc.php
```

En el caso de conectarnos al contendor del servicio `db` navegariamos hasta el directorio de `MySQL` en `/var/lib/mysql` donde encontrariamos nuestra base de datos.

### docker-compose.override.yaml

Documentación oficial:

[Share Compose configurations between files and projects | Docker Documentation](https://docs.docker.com/compose/extends/)

Aunque hemos mencionado anteriormente que usaremos volumenes de tipo `Named` para montar los datos de nuestros servicios (`db` y `wp`), también podriamos hacer uso de puntos de montaje `bind`, este tipo es más apropiado para montar configuraciones de los servicios, lo importante es que son volumenes persistentes que harán que nuestros datos estén disponibles aunque los contenedores o aplicaciones sean eliminados.

Esta configuración la podriamos agregar a nuestro fichero `docker-compose.yaml` pero haremos uso de otro fichero llamado `docker-compose.override.yaml`.

El archivo `docker-compose.override.yaml` nos permite agregar o anular configuraciones de servicio especificadas en nuestro archivo `docker-compose.yaml` al inicio. Si `docker-compose` encuentra un archivo `docker-compose.override.yaml` presente en el directorio de proyecto, lo combinará con el archivo `docker-compose.yaml` y levantará la aplicación o servicios a partir de ambos archivos. En general, los elementos especificados en el archivo `docker-compose.override.yaml` se agregarán o anularán en el archivo principal de `docker-compose`. 

Nuestro archivo `docker-compose.override.yaml` quedaría de la siguiente forma:

```yaml
version: '3.7'

services:
  db:
    volumes:
      - ./services/db:/var/lib/mysql

  wp:
    volumes:
      - ./services/wp:/var/www/html
```

##### **NOTA:**

**Hay que mencionar, que la estructura de directorios que montemos con `Bind` no será necesario crear la previamente en el directorio del proyecto de nuestro `Host`, ya que al declar la en el código de nuestro fichero `docker-compose` se generará automaticamente.**

y la estructura del directorio de proyecto sería la siguiente:

```bash
vagrant@masterVM:~/wordpress$ tree
.
├── docker-compose.override.yaml
├── docker-compose.yaml
└── services
    ├── db
    ├── nginx
    │   └── nginx.conf
    └── wp
```

Ahora al ejecutar `docker-compose up -d` podremos listar el contenido de nuestros volumenes en los directorios que hemos creado para cada servicio:

```bash
vagrant@masterVM:~/wordpress$ ls -l services/db/
total 139320
-rw-rw---- 1 systemd-coredump systemd-coredump  16785408 Jan 31 11:49 aria_log.00000001
-rw-rw---- 1 systemd-coredump systemd-coredump        52 Jan 31 11:49 aria_log_control
-rw-rw---- 1 systemd-coredump systemd-coredump         9 Jan 31 11:49 ddl_recovery.log
-rw-rw---- 1 systemd-coredump systemd-coredump       868 Jan 31 11:49 ib_buffer_pool
-rw-rw---- 1 systemd-coredump systemd-coredump  12582912 Jan 31 11:49 ibdata1
-rw-rw---- 1 systemd-coredump systemd-coredump 100663296 Jan 31 11:51 ib_logfile0
-rw-rw---- 1 systemd-coredump systemd-coredump  12582912 Jan 31 11:49 ibtmp1
-rw-rw---- 1 systemd-coredump systemd-coredump         0 Jan 31 11:49 multi-master.info
drwx------ 2 systemd-coredump systemd-coredump      4096 Jan 31 11:49 mysql
-rw-r--r-- 1 systemd-coredump systemd-coredump        15 Jan 31 11:49 mysql_upgrade_info
drwx------ 2 systemd-coredump systemd-coredump      4096 Jan 31 11:49 performance_schema
drwx------ 2 systemd-coredump systemd-coredump     12288 Jan 31 11:49 sys
drwx------ 2 systemd-coredump systemd-coredump      4096 Jan 31 11:49 wordpress
```

### Volumenes `Named`

Al igual que con los puntos de montaje `Bind`, usamos la directiva `volumes` en nuestro archivo `docker-compose.yaml`, anidada dentro de la directiva `services`, con la diferencia de que usamos un formato de `nombre: contenedor`. Otra diferencia es que también debemos especificar otra directiva `volumes`  pero de nivel superior, con cada volumen de tipo `Named` creado en nuestro proyecto.

Al igual que hemos usado anteriormente el fichero `docker-compose.override.yml`

Opcionalmente, podemos usar la opción -f para especificar un archivo o archivos adicionales de configuración que queramos usar para iniciar el proyecto. Vamos a crear un archivo, llamado `docker-compose-volumes.yml`, que contenga el código necesario para añadir nuestros volumenes de tipo `Named`, para demostrar esta característica.

El fichero quedaría de la siguiente forma:

```yaml
version: '3.7'

services:
  db:
    volumes:
      - db:/var/lib/mysql

  wp:
    volumes:
      - wp:/var/www/html

volumes:
  db:
  wp:
```

Y nuestro directorio de proyecto:

```bash
vagrant@masterVM:~/wordpress$ tree
.
├── docker-compose-volumes.yaml
├── docker-compose.yaml
└── services
    └── nginx
        └── nginx.conf
```

Ahora ejecutamos `docker-compose up -d` pero deberemos usar el parámetro `-f` para indicar los ficheros:

```bash
docker-compose -f docker-compose.yaml -f docker-compose-volumes.yaml up -d
```

Podemos explorar los volumenes:

```bash
vagrant@masterVM:~/wordpress$ docker volume ls
DRIVER    VOLUME NAME
local     wordpress_db
local     wordpress_wp
```

Podemos apagar la aplicación ejecutando `docker-compose down -v`, pero si volvemos a explorar los volúmenes veremos que todavía están allí. En este caso, utilizamos el archivo `docker-compose.yaml` para cerrar nuestro proyecto, pero tenemos que recordar que nuestros volúmenes de tipo `Named` se especificaron en el archivo `docker-compose-volumes.yaml` y no especificamos este archivo en nuestro comando de apagado, por lo tanto, nuestros volúmenes `db` y `wp` no se eliminaron. 

Podríamos eliminar los volúmenes correctamente al volver a ejecutar el comando de apagado con nuestros archivos de configuración, de la siguiente forma:

```bash
docker-compose -f docker-compose.yaml -f docker-compose-volumes.yaml down -v
```

### Backup y gestión de datos de nuestros contenedores

Llegados a este punto, vamos a explicar como realizar `backup` de los datos usando puntos de montaje `Bind` y volumenes `Named`, ya que como hemos citado anteriormente son persistentes.

Para este proceso, crearemos unos puntos de montaje `Bind` llamados `backup` para nuestros servicios `db` y `wp`, estos directorios se montarán en la carpeta `/home/backup` de cada contenedor.

Algo que se suele hacer también con la apliación `WordPress` es usar puntos de montaje `Bind` para los directorios `plugins` y `themes`, de esta forma podemos tener un mayor control a la hora de personalizar nuestro proyecto.

Para realizar esto, volveremos a hacer uso ficheros `docker-compose` adicionales al principal, en este caso lo llamaremos `docker-compose-backup.yaml` y el código será el siguiente:

```yaml
version: '3.7'

services:
  db:
    volumes:
      - db:/var/lib/mysql
      - ./services/db/backup:/home/backup

  wp:
    volumes:
      - wp:/var/www/html
      - ./services/wp/backup:/home/backup
      - ./services/wp/themes:/var/www/html/wp-content/themes
      - ./services/wp/plugins:/var/www/html/wp-content/plugins

volumes:
  db:
  wp:
```

y nuestro directorio de proyecto quedaría así:

```bash
vagrant@masterVM:~/wordpress$ tree
.
├── docker-compose-backup.yaml
├── docker-compose.yaml
└── services
    ├── db
    │   └── backup
    ├── nginx
    │   └── nginx.conf
    └── wp
        ├── backup
        ├── plugins
        └── themes
```

Procedemos a levantar el proyecto:

```bash
docker-compose -f docker-compose.yaml -f docker-compose-backup.yaml up -d
```

Si listamos el contenido de los directorios `plugins` y `themes` veremos el contenido de ellos:

```bash
vagrant@masterVM:~/wordpress$ ls -l services/wp/plugins/
total 12
drwxr-xr-x 4 www-data www-data 4096 Nov 15 19:03 akismet
-rw-r--r-- 1 www-data www-data 2578 Mar 18  2019 hello.php
-rw-r--r-- 1 www-data www-data   28 Jun  5  2014 index.php
vagrant@masterVM:~/wordpress$ ls -l services/wp/themes/
total 16
-rw-r--r-- 1 www-data www-data   28 Jun  5  2014 index.php
drwxr-xr-x 6 www-data www-data 4096 Nov 15 19:03 twentytwentyone
drwxr-xr-x 7 www-data www-data 4096 Nov 15 19:03 twentytwentythree
drwxr-xr-x 7 www-data www-data 4096 Nov 15 19:03 twentytwentytwo
```

Podremos modificar el contenido desde nuestro `Host` y éste se verá modificado en nuestro contenedor `wp`.

##### **Copia de seguridad de la BD `wordpress` del contenedor `db`**

##### **NOTA:**

**El procedimiento más fácil es usar nuestro gestor de BBDD gráfico `Adminer` ya que hemos levantado un servicio para una gestión de la BD `wordpress` más comoda (no lo voy a comentar ya que es muy intuitivo). Las posibilidades de gestionar volumenes y datos que se comentan a continuación son muy útiles y de caracter general.**

Lo siguiente que haremos, será realizar una `copia de seguridad de la Base de Datos` de `WordPress`, para ello accederemos al contenedor y volcaremos una copia de la BD llamada `wordpress` en el directorio `/home/backup` que a su vez estará montado en la carpeta `services/db/backup` de nuestro `Host`.

Accedemos al contenedor `db`:

```bash
docker exec -it wordpress-db-1 /bin/bash
```

Una vez dentro del container usaremos la herramienta `mysqldump` para volcar el contenido de la BD `wordpress` en el directorio `/home/backup` del container. Nos pedirá la contraseña que especificamos en nuestor fichero `docker-compose.yaml` (rootpassword)

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
```

```bash
root@0ec595222e58:/# mysqldump -u root -p wordpress > /home/backup/wordpress.sql
Enter password:
```

Y ahora si listamos el contenido del directorio `/home/backup` veremos nuestro script `sql` :

```bash
root@0ec595222e58:/# ls -l /home/backup/
total 4
-rw-r--r-- 1 root root 1308 Feb  1 10:44 wordpress.sql
```

Éste a su vez estará en el directorio `services/db/backup` del proyecto en nuestro `Host` :

```bash
vagrant@masterVM:~/wordpress$ ls -l services/db/backup/
total 4
-rw-r--r-- 1 root root 1308 Feb  1 10:44 wordpress.sql
```

De manera similar, podemos importar la base de datos desde el contenedor `db` con el comando `mysql` de la siguiente manera:

```bash
mysql -u root -p wordpress < /home/backup/wordpress.sql
```

Otra forma de importar la copia de seguridad de la base de datos sería ejecutar el comando directamente sin entrar en la `bash` del contenedor:

```bash
docker exec -i wordpress-db-1 mysql -u root -p"rootpassword" wordpress < ./services/db/backup/wordpress.sql
```

o también

```bash
docker exec wordpress-db-1 bash -c 'mysql -uroot -p"rootpassword" wordpress < /home/backup/wordpress.sql'
```

Esto funcionará en el caso de haber perdido datos o alguna tabla de nuestra BD `wordpress`, en caso de haber perdido la BD entera, deberemos crear la previamente:

```bash
docker exec wordpress-db-1 bash -c 'mysql -uroot -p"rootpassword" -e "CREATE DATABASE wordpress"'
```

Una vez creada, podremos ejecutar los comandos anteriores para restaurar la BD.

Y para exportar la BD usariamos el comando:

```bash
docker exec -i wordpress-db-1 mysqldump -uroot -p wordpress > ./services/db/backup/wordpress.sql
```

##### **Copia de seguridad de la aplicacion `WordPress` del contenedor `wp`**

Realizamos la copia de seguridad logandonos en el contenedor y haciendo uso de la utilidad de linea de comando `tar`.

```bash
docker exec -it wordpress-wp-1 /bin/bash
```

como podemos observar, nos ubica en el directorio de trabajo del contenedor que en este caso es donde se aloja la apliación `WordPress`

```bash
root@0838c869e7b5:/var/www/html#
```

Solamente deberemos ejecutar el siguiente comando y crearemos una copia de seguridad de la apliación `WordPress` con el nombre `backup.tar` en el directorio `/home/backup`.

```bash
root@0838c869e7b5:/var/www/html# tar -cf /home/backup/backup.tar .
```

Para restaurar los archivos de `WordPress` desde el archivo `backup.tar` que creamos anteriormente ejecutaremos el siguiente comando (desde el directorio `/var/www/html` del contenedor).

```bash
root@0838c869e7b5:/var/www/html# tar -xf /home/backup/backup.tar
```

Para realizar la copia de seguridad sin conectarnos a la `bash` del contenedor ejecutariamos el siguiente comando:

```bash
docker exec wordpress-wp-1 bash -c "tar -cz *" > ./services/wp/backup/backup.tar.gz
```

##### **Copia de seguridad usando un container intermedio**

Si nuestro container no está operativo, no arranca el servicio, se borró accidentalmente, pero los volumenes asociados los conservamos, la forma de recuperar los datos es usando un contenedor intermedio. Basicamente lo que haremos será arrancar un contenedor (con Ubuntu por ejemplo) en el cual montaremos los volumenes que estaban asociados al contenedor que perdimos y realizar la copia.

Describo el procedimiento en un `docker-compose` que levanta el stack `LEMP`:

[Docker/docker-compose-LEMP at main · jpaybar/Docker · GitHub](https://github.com/jpaybar/Docker/tree/main/docker-compose-LEMP#docker-backup-saving-and-restoring-volumes)

### Segurizar la información sensible de nuestro fichero `docker-compose.yaml`

El problema de especificar información confidencial en variables de entorno `environment` en nuestro fichero `docker-compose.yaml`, es que dicha información es fácilmente visible para cualquier persona con acceso al archivo.

En este caso, el nombre de usuario, la contraseña y el nombre de la base de datos de nuestra aplicación de `WordPress` son visibles en texto plano. 

Una opción sería mover información sensible o cualquier otro dato de las variables de entorno a uno o más ficheros usando la directiva `env_file`. Esto mantiene los datos separados del archivo `docker-compose.yaml` y reduce la posibilidad de que se expongan accidentalmente. 

Vamos a ver como quedaría nuestro fichero `docker-compose.yaml` y los ficheros que contendrán las variables de entorno en la raiz de nuestro directorio de proyecto.

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    env_file:
      - ./db.env

  wp:
    image: wordpress 
    env_file:
      - ./wp.env
```

el contenido de los ficheros `db.env` y `wp.env` sería el siguiente:

```bash
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=wordpress
```

```bash
WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=root
WORDPRESS_DB_PASSWORD=rootpassword
```

Se pueden especificar varios archivos `.env` para un servicio determinado y también se pueden usar archivos `.env` además de variables definidas en la directiva `environment`. Hay que tener en cuenta que cualquier variable especificada en la directiva `environment` prevalece y anula a la misma variable si estuviera definida en un fichero `.env`.

Sin embargo, el uso de un archivo `.env` no asegura los datos sensibles en el sistema. Ya que aún se encuentran en texto plano en un archivo al que apunta una línea de código de nuestro fichero `docker-compose.yaml`. Además, la información confidencial se almacena de forma visible dentro del contenedor del servicio y se puede ver simplemente ejecutando el siguiente comando:

```bash
docker inspect "nombre_contenedor"
```

##### **Secrets**

`Docker` permite especificar información sensible como un `secret`, que se cifra y se administra de forma centralizada, además se transmite solo a los contenedores que estén autorizados.

Los `secrets` se especifican en nuestro archivo `docker-compose.yaml` usando la directiva `secrets`, tanto en la raíz del fichero como a nivel de servicio. Además hay que especificar un archivo fuente para cada información que queremos convertir en `secrets`.

Crearemos un directorio llamado `secrets` en la carpeta raíz del proyecto y dentro ubicaremos los ficheros que almacenarán la información sensible.

##### **NOTA:**

**Aprovecharemos para crear un usuario que no será `root` con su correspondiente contraseña, usando los ficheros `secrets` (./secrets/mysql_user y ./secrets/mysql_password).**

La estructura del fichero `docker-compose.yaml` sería más o menos así:

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    secrets:
      - mysql_root_password
      - mysql_database

  wp:
    image: wordpress 
    secrets:
      - mysql_database
      - mysql_user
      - mysql_password

secrets:
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_database:
    file: ./secrets/mysql_database
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password
```

y la estructura del proyecto:

```bash
vagrant@masterVM:~/wordpress$ tree
.
├── docker-compose.yaml
├── secrets
│   ├── mysql_database
│   ├── mysql_password
│   ├── mysql_root_password
│   └── mysql_user
└── services
    ├── db
    │   └── backup
    ├── nginx
    │   └── nginx.conf
    └── wp
        ├── backup
        ├── plugins
        └── themes
```

Similar a un punto de montaje de tipo `Bind`, `docker-compose` montará el archivo definido para cada `secrets` dentro del contenedor especificado. 

De forma predeterminada, el punto de montaje está en `/run/secrets/<nombre_secret>` dentro del contenedor.

Adicionalmente, podemos usar las variables de entorno junto con los `secrets`. En las variables de entorno que usamos anteriormente haremos referencia al archivo `secret` dentro del contenedor que está en la ruta `/run/secrets/<nombre_secrets>`. 

Nuestro fichero `docker-compose.yaml` quedaría de la siguiente forma:

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    secrets:
      - mysql_root_password
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
      MYSQL_DATABASE_FILE: /run/secrets/mysql_database
      MYSQL_USER_FILE: /run/secrets/mysql_user
      MYSQL_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - db:/var/lib/mysql

  wp:
    image: wordpress
    secrets:
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME_FILE: /run/secrets/mysql_database
      WORDPRESS_DB_USER_FILE: /run/secrets/mysql_user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - wp:/var/www/html

  adminer:
    image: adminer

  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx:/etc/nginx/conf.d

volumes:
  db:
  wp:      

secrets:
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_database:
    file: ./secrets/mysql_database
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password    
```

Al usar el comando `docker inspect` podemos verificar que nuestros datos confidenciales ya no estén expuestos mediante una simple inspección del contenedor. 

Sin embargo, los `secrets` aún se almacenan en texto plano dentro del contenedor y se puede acceder a ellos mediante el comando `docker exec` y una vez dentro del contenedor editar el `secrets` para ver la información.

##### **NOTA:**

**Mencionar que para sacar el máximo rendimiento a los `secrets` docker debe de correr en modo `swarm`, aunque con `docker-compose` se pueda hacer uso de algunas caracteristicas.**

**Para más información visitar documentación oficial:**

[Manage sensitive data with Docker secrets | Docker Documentation](https://docs.docker.com/engine/swarm/secrets/)

### Protegiendo las conexiones de red con HTTPS

Hasta ahora hemos usado `nginx` como servidor proxy inverso, haciendo que todas las peticiones a los servicios `wp` y `adminer` pasen a través de él. Con esto hemos simplificado la URL (no tener que especificar puerto en el acceso a `adminer`, puerto 8080 por defecto) pero las comunicaciones se han hecho hasta hora con el protocolo HTTP al puerto 80, por lo que los datos fluyen en texto plano.

Para hacer uso del protocolo HTTPS y hacer que las peticiones a la aplicación de `WordPress` y `Adminer` nuestro gestor gráfico de BBDD vayan por el puerto 443, necesitamos configurar de nuevo `nginx` y al menos crear un certificado autofirmado que alojaremos en el servidor.

##### **NOTA:**

**Si nuestro sitio web tuviera un nombre de dominio público, lo más adecuado sería obtener un certificado de una Autoridad de certificación. Los certificados autofirmados no están validados por una autoridad de certificación comercial, de forma que si un usuario accede al sitio via `https`, el navegador le avisará informandole de que el certificado no es de confianza.**

##### **NOTA II:**

**Como no disponemos de un dominio público, para mayor comodidad a la hora de escribir la URL y como hemos declarado en el fichero de configuración de `nginx` la directiva `server_name`, editaremos el fichero `/etc/hosts` (en windows `c:\Windows\System32\Drivers\etc\hosts`) y añadiremos las siguientes entradas:**

```
192.168.1.10    wordpress
192.168.1.10    adminer
```

Lo primero que haremos será crear un directorio llamado `certs` en la ruta `./services/nginx/certs` de nuestra carpeta de proyecto, dentro de ella añadiremos los certificados y posteriormente declararemos un punto de montaje `Bind` en nuestro fichero `docker-compose.yaml` para volcar la configuración dentro del container `nginx`.

Para crear nuestro certificado autofirmado haremos uso de la utilidad `openssl`, si ejecutamos el siguiente comando nos creará una clave privada `.key` y el certificado autofirmado `.crt` en el directorio actual, en este caso el que hemos creado para tal fina (`./services/nginx/certs`):

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./private.key -out ./certificate.crt
```

 Usamos las siguientes opciones con el comando `openssl req`:

- **x509**: Genera un certificado autofirmado en lugar de una solicitud de certificado.
- **nodes**: La clave privada no está cifrada.
- **days 365**: El certificado tendrá una validez de 365 días. Podemos establecer el número de días que deseemos. El valor predeterminado es 30 días.
- **newkey rsa:2048**: Crea una nueva clave privada RSA de 2048 bits de tamaño.
- **keyout**: La clave privada, denominada private.key, se creará en la carpeta actual.
- **out**: El certificado autofirmado, denominado certificate.crt, se creará en la carpeta actual.

El comando `openssl req` nos solicitará información sobre el certificado autofirmado. La línea requerida más importante es la que comienza con `Common Name`. En esta línea, debemos ingresar la `dirección IP` o el `nombre de host` del equipo que aloja `nginx`. En mi caso estoy ejecutando `docker` desde una máquina virtual con `Vagrant` sobre `VirtualBox` y he introducido la ip de mi equipo `Host`. 

Para las otras líneas, podemos ingresar la información que deseemos o simplemente omitirlas presionando la tecla enter.

##### **Modificación del fichero `docker-compose.yaml`**

Agregamos el puerto 443 al servicio `nginx` y añadimos un punto de montaje `Bind` para volcar en nuestro container el certificado autofirmado y la clave privada:

```yaml
nginx:
    image: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./services/nginx:/etc/nginx/conf.d
      - ./services/nginx/certs:/etc/nginx/certs
```

Nos queda modificar el fichero de configuración de `nginx` que quedará ahora de la siguiente forma:

```nginx
server {
  listen 80;
  listen [::]:80;

  server_name wordpress;

  return 301 https://wordpress$request_uri;
}

server {
  listen 80;
  listen [::]:80;

  server_name adminer;

  return 301 https://adminer$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name wordpress;

  ssl_certificate /etc/nginx/certs/certificate.crt;
  ssl_certificate_key /etc/nginx/certs/private.key;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto https;

  location / {
    proxy_pass http://wp;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name adminer;

  ssl_certificate /etc/nginx/certs/certificate.crt;
  ssl_certificate_key /etc/nginx/certs/private.key;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto https;

  location / {
    proxy_pass http://adminer:8080;
  }
}
```

`listen`: Esta directiva configura el puerto de escucha por defecto en `nginx` al 80.

`server_name`: Determina qué bloque de servidor se utiliza para una solicitud determinada. Se pueden definir usando nombres exactos, nombres comodín o expresiones regulares.

`return 301 https://$host$request_uri;`: Esta línea redirigirá todo el tráfico `http` a nuestro servicio de `WordPress` o `Adminer` a un nuevo bloque de servidor `https`.

`listen`: De nuevo esta directiva, pero indica que el servidor estará a la escucha en el puerto 443 por defecto para `https` y `ssl`.

`ssl_certificate` y `ssl_certificate_key`: Especifican la ubicación del certificado autofirmado y la clave privada dentro del contenedor nginx.

`proxy_set_header X-Forwarded-Proto https`: Esta directiva agrega un encabezado a la solicitud que se pasa al servicio de `WordPress` especificando que el cliente usó el protocolo `https` para conectarse al servicio. Necesario para hacer el tunel `https`.

Por último nuestro fichero `docker-compose.yaml` quedaría de la siguiente forma:

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    secrets:
      - mysql_root_password
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
      MYSQL_DATABASE_FILE: /run/secrets/mysql_database
      MYSQL_USER_FILE: /run/secrets/mysql_user
      MYSQL_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - db:/var/lib/mysql

  wp:
    image: wordpress
    secrets:
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME_FILE: /run/secrets/mysql_database
      WORDPRESS_DB_USER_FILE: /run/secrets/mysql_user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - wp:/var/www/html

  adminer:
    image: adminer

  nginx:
    image: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx:/etc/nginx/conf.d
      - ./secrets/certs:/etc/nginx/certs

volumes:
  db:
  wp:      

secrets:
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_database:
    file: ./secrets/mysql_database
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password
```

Ahora podremos acceder a `adminer` via `http` o `https`:

```http
http://adminer
```

automáticamente nos dirigirá a:

```http
https://adminer
```

Nuestro navegador nos advertirá que el sitio web no es de confianza como hemos comentado ya que estamos usando un certificado autofirmado.

![warning_certificado.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/warning_certificado.PNG)

Aceptamos y continuamos.

![adminer_https.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/adminer_https.PNG)

### Configuración multisite de `WordPress`

Hasta ahora, tenemos funcionando nuestra aplicación `WordPress` conectada a nuestro container con `MariaDB` `db`, el gestor gráfico de BBDD `Adminer` y también hemos configurado nuestro servidor web `nginx` como proxy inverso simplificando asi las URL's y reenviando las peticiones de nuestros servicios al puerto 443 para securizar las conexiones web via `https`.

En el enunciado de este tutorial, también citabamos la configuración de un proyecto con `WordPress` multisite. Existen varias formas de hacer esto, en la misma página de `WordPress` nos muestran las diferentes formas de llevar a cabo este cometido. Podemos configurar la apliación en los siguientes modos; multiples instancias de `WordPress` con multiples BBDD, multiples instancias de `WordPress` con una sola BD y varios usuarios o multiples BBDD con un solo usuario. 

Basicamente, dichas configuraciones se centran en la modificación del fichero `wp-config.php` de `WordPress` como se puede ver en su web.

Para una información ver la documentación oficial:

[Installing Multiple WordPress Instances &#8211; WordPress.org Documentation](https://wordpress.org/documentation/article/installing-multiple-blogs/)

Al final, después de leer por internet y habiendo hecho uso en otros proyectos del servicio `MariaDB` o `MySQL`, he optado por una forma alternativa. Levantaremos una segunda aplicación de `WordPress` llamada `wp2` y se conectará al único servicio de BBDD `db` en el que crearemos una segunda BD (`wordpress2`), el usuario será el mismo para ambas bases de datos. 

Como hemos comentado más arriba, necesitamos que nuestro servicio `MariaDB`, cree una segunda base de datos para la aplicación `WordPress` `wp2`, ésto hará que la rutina de instalación de `WordPress` se ejecute correctamente. La cuestión, es que `MariaDB` solo proporciona la creación de una base de datos única al crear el servicio con las variables de entorno `environment` que hemos estado usando, pero necesitamos una base de datos separada para cada servicio de `WordPress` que agreguemos. 

Sin una base de datos subyacente, obtendremos un error del tipo "Error al establecer una conexión de base de datos" al intentar acceder a nuestros servicios de `WordPress`

Afortunadamente, `MariaDB` proporciona otra forma de inicializar el servicio de base de datos al momento de la creación del container y usaremos esta función para crear una para cada uno de nuestros servicios de `WordPress`.

##### Modificación del archivo `docker-compose.yaml`

Agregamos el segundo servicio `WordPress` `wp`:

```yaml
wp2:
    image: wordpress
    secrets:
      - mysql_database2
      - mysql_user
      - mysql_password
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME_FILE: /run/secrets/mysql_database2
      WORDPRESS_DB_USER_FILE: /run/secrets/mysql_user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - wp2:/var/www/html
```

También agregamos a la raíz del fichero el nuevo `secrets` (`./secrets/mysql_database2`) y el nuevo volúmen `wp2`

```yaml
volumes:
  db:
  wp:      
  wp2:           

secrets:
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_database:
    file: ./secrets/mysql_database
  mysql_database2:
    file: ./secrets/mysql_database2
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password
```

Modificamos el contenido del fichero `secrets` llamado `mysql_database2` con el nombre de la nueva BD `wordpress2`.

##### Modificación del servicio `db` para inicializar la segunda BD `wordpress2`

Como se señaló anteriormente, necesitamos levantar una segunda BD, la imagen Docker de `MariaDB`, como muchas otras imagenes, proporciona otra forma de inicializar el servicio cuando se crea por primera vez. `MariaDB` hace esto ejecutando cualquier archivo con las extensiones `sh`, `sql` y `sql.gz` que se encuentran en la carpeta `docker-entrypoint-initdb.d` del contenedor. Por lo tanto, lo que debemos hacer es crear un `script` de `sql` que cree una base de datos, además de asignarle los permisos correspondientes al usuario para cada servicio de `WordPress` y mapear dicho fichero con un punto de montaje `Bind` al directorio `docker-entrypoint-initdb.d` del contenedor.

Un simple `script` de `sql` para realizar dicho fin:

```sql
-- create database/s
CREATE DATABASE IF NOT EXISTS wordpress2;

-- grant access rights to wpuser
GRANT ALL PRIVILEGES ON wordpress2.* TO 'wpuser'@'%';
```

Creamos el directorio que contrendrá el `script` en `./services/db/init` dentro del directorio de proyecto y agregamos la siguiente directiva al fichero `docker` dentro del servicio `db` (`./services/db/init:/docker-entrypoint-initdb.d`):

```yaml
volumes:
      - db:/var/lib/mysql
      - ./services/db/init:/docker-entrypoint-initdb.d
      - ./services/db/backup:/home/backup
```

### Configuración completa de la aplicación

Estructura del directorio de proyecto:

```bash
vagrant@masterVM:~/wordpress$ tree
.
├── docker-compose.yaml
├── secrets
│   ├── mysql_database
│   ├── mysql_database2
│   ├── mysql_password
│   ├── mysql_root_password
│   └── mysql_user
└── services
    ├── db
    │   ├── backup
    │   └── init
    │       └── create_db.sql
    ├── nginx
    │   ├── certs
    │   │   ├── certificate.crt
    │   │   └── private.key
    │   └── nginx.conf
    ├── wp
    │   └── backup
    └── wp2
        └── backup
```

Estructura del fichero `docker-compose.yaml`:

```yaml
version: '3.7'

services:
  db:
    image: mariadb
    secrets:
      - mysql_root_password
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
      MYSQL_DATABASE_FILE: /run/secrets/mysql_database
      MYSQL_USER_FILE: /run/secrets/mysql_user
      MYSQL_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - db:/var/lib/mysql
      - ./services/db/init:/docker-entrypoint-initdb.d
      - ./services/db/backup:/home/backup

  wp:
    image: wordpress
    secrets:
      - mysql_database
      - mysql_user
      - mysql_password
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME_FILE: /run/secrets/mysql_database
      WORDPRESS_DB_USER_FILE: /run/secrets/mysql_user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - wp:/var/www/html
      - ./services/wp/backup:/home/backup

  wp2:
    image: wordpress
    secrets:
      - mysql_database2
      - mysql_user
      - mysql_password
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME_FILE: /run/secrets/mysql_database2
      WORDPRESS_DB_USER_FILE: /run/secrets/mysql_user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/mysql_password
    volumes:
      - wp2:/var/www/html
      - ./services/wp2/backup:/home/backup

  adminer:
    image: adminer

  nginx:
    image: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./services/nginx:/etc/nginx/conf.d
      - ./services/nginx/certs:/etc/nginx/certs
    depends_on:
      - wp
      - wp2
      - adminer

volumes:
  db:
  wp:      
  wp2:           

secrets:
  mysql_root_password:
    file: ./secrets/mysql_root_password
  mysql_database:
    file: ./secrets/mysql_database
  mysql_database2:
    file: ./secrets/mysql_database2
  mysql_user:
    file: ./secrets/mysql_user
  mysql_password:
    file: ./secrets/mysql_password
```

Estructura del fichero de configuración de `nginx`:

```nginx
server {
  listen 80;
  listen [::]:80;

  server_name wordpress;

  return 301 https://wordpress$request_uri;
}

server {
  listen 80;
  listen [::]:80;

  server_name wordpress2;

  return 301 https://wordpress2$request_uri;
}

server {
  listen 80;
  listen [::]:80;

  server_name adminer;

  return 301 https://adminer$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name wordpress;

  ssl_certificate /etc/nginx/certs/certificate.crt;
  ssl_certificate_key /etc/nginx/certs/private.key;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto https;

  location / {
    proxy_pass http://wp;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name wordpress2;

  ssl_certificate /etc/nginx/certs/certificate.crt;
  ssl_certificate_key /etc/nginx/certs/private.key;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto https;

  location / {
    proxy_pass http://wp2;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name adminer;

  ssl_certificate /etc/nginx/certs/certificate.crt;
  ssl_certificate_key /etc/nginx/certs/private.key;

  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto https;

  location / {
    proxy_pass http://adminer:8080;
  }
}
```

Entradas en el fichero `/etc/hosts`:

```
192.168.1.10    wordpress
192.168.1.10    wordpress2
192.168.1.10    adminer
```

Conectamos a `https://adminer` y como podemos ver estamos gestionando el servicio `db` y vemos nuestras 2 BBDD `wordpress` y `wordpress2`:

![adminer_fin.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/adminer_fin.png)

Conectamos a `https://wordpress`:

![wordpress_fin.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/wordpress_fin.png)

Conectamos a `https://wordpress2`:

![wordpress2_fin.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/wordpress2_fin.png)

### BONUS..... 😜

Fuera de tutorial y viendo las posibilidades de `Adminer` como gestor gráfico de BBDD, ya que este nos permite la conexión a `MySQL`, `SQLite`, `PostgreSQL`, incluso a `Oracle`, `MS SQL`, `MongoDB` y `Elasticsearch` aunque estas últimas en fase `beta`. Quise comprobar como se haría la conexión desde nuestro container con `Adminer` a una base de datos local en mi `Host` con `PostgreSQL`.

### Permitir que `Postgres` acepte peticiones que no procedan de localhost

Los 2 ficheros de configuración principales de `PostreSQL` son:  

- **postgresql.conf**
- **pg_hba.conf**

Buscamos la ubicación en el arbol de directorios del sistema:

```bash
vagrant@masterVM:~$ sudo find / -name postgresql.conf -print
/usr/lib/tmpfiles.d/postgresql.conf
/etc/postgresql/12/main/postgresql.conf
```

igualmenta para el segundo fichero:

```bash
vagrant@masterVM:~$ sudo find / -name pg_hba.conf -print
/etc/postgresql/12/main/pg_hba.conf
```

Editamos el primer fichero y el parámetro que nos interesa es `listen_addresses`:

```bash
#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

listen_addresses = '*'                  # what IP address(es) to listen on;
                                        # comma-separated list of addresses;
                                        # defaults to 'localhost'; use '*' for all
                                        # (change requires restart)
```

Como podemos observar, nos podemos conectar desde cualquier equipo (`*`)

Ahora, editamos el segundo fichero `pg_hba.conf` y debemos agregar una linea de configuración como la siguiente:

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             ip_address/mask         trust
```

Pero para ello deberemos saber la dirección IP y la mascara de subred que esta usando `Docker`. Si ejecutamos el siguiente comando para ver nuestras interfaces de red en el sistema:

```bash
ip a 
```

De todas ellas nos interesan 2 (`docker0` y `br-`) la primera por defecto y la segunda de tipo `bridge` con la nomenclatura `br-` seguido de lo que sea, en mi caso `br-dcce9a824d46`. La IP de esa interfaz, será la que agregaremos a dicho fichero, en este caso la `192.168.208.1/20`, quedando de la siguiente forma:

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             192.168.208.1/20         trust
```

### Creamos la base de datos `Pruebas` desde la linea de comandos de `PostgreSQL`

Nos conectamos desde el `Host`:

```bash
vagrant@masterVM:~$ psql -h localhost -U postgres -W
Password:
psql (12.13 (Ubuntu 12.13-0ubuntu0.20.04.1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

postgres=#
```

Listamos las bases de datos:

```bash
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(3 rows)
```

Creamos la base de datos `Pruebas`:

```bash
postgres=# create database Pruebas;
CREATE DATABASE
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 pruebas   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)
```

### Comprobamos la conexión desde nuestro container con el servicio `Adminer` a nuestro `Host`

Nos conectamos a nuestro servicio `Adminer`

```http
https://adminer
```

![adminer_postgre.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/adminer_postgre.png)

Como se ve en la captura, seleccionamos el `Motor de base de datos`, `Servidor` que en este caso será la IP `bridge` que configuramos en el fichero `pg_hba.conf` de `PostgreSQL` y por último `Usuario` y `Contraseña`.

##### **NOTA:**

**Para poder conectarnos desde un equipo que no sea nuestro `Host` la cuenta de usuario o Rol de `PostgreSQL` debe de tener contraseña, en caso contrario se nos mostrará un error o advertencia informandonos de ello.**



Ahora, verificamos que estamos conectados a nuestra BD `Postgre` llamada `Pruebas` en nuestro `Host`.

![adminer_postgre_check.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress_Aminer_Nginx/_images/adminer_postgre_check.png)

## Author Information

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)
[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)
https://es.linkedin.com/in/juanmanuelpayan
