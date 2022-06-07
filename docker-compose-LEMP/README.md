# Setting Up a LEMP Stack with Docker Compose

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

Docker Compose is a tool that allows one to declare which Docker containers should run, and which relationships should exist between them. It follows the <u>infrastructure as code</u> approach, just like most automation software.

This `docker-compose.yml` file configures four services to use the LEMP stack. The `php` service customizes a Docker Hub image (php:7.4-fpm) using a `php.Dockerfile` and the `nginx` service starts Nginx webserver at latest version. The next service is `mysql`, a container with the MySQL image, the version can be modified in the variables file `.env`(It is necessary to rename the test.env file to .env once the project folder is downloaded so that the "docker-compose.yml" file reads the environment variables, github or the .gitignore file excludes the upload of .env files by security reasons). And finally we start `phpMyAdmin` service to have a graphical environment and be able to manage our database.

## Project folder:

```bash
linuxuser@localhost:~/DOCKER/LEMP$ tree -a
.
├── docker-compose.yml
├── .env
├── README.md
└── services
    ├── mysql
    │   └── dbname.sql
    ├── nginx
    │   ├── app
    │   │   └── index.php
    │   └── config
    │       └── nginx.conf
    └── php
        └── php.Dockerfile
```

## 

## The docker-compose.yml File

```yaml
# https://docs.docker.com/compose/compose-file/compose-file-v3/
version: "3.7"
services:
  nginx:
    image: nginx:latest
    container_name: "${APP_NAME:?err}-nginx"
    ports:
      - 80:80
      - 443:443
    restart: on-failure
    links:
      - php
    volumes:
      - ./services/nginx/app:/var/www/html
      - ./services/nginx/config:/etc/nginx/conf.d

  php:
    # PHP image: 'php:7.4-fpm'
    build:
      context: ./services/php
      dockerfile: php.Dockerfile
    container_name: "${APP_NAME:?err}-php"
    volumes:
      - ./services/nginx/app:/var/www/html
    depends_on:
      - mysql

  mysql:
    image: "mysql:${MYSQL_VERSION}"
    container_name: "${APP_NAME:?err}-mysql"
    ports: 
      - 3306:3306
    #command: --default-authentication-plugin=mysql_native_password
    restart: on-failure
    #env_file:
      #- ./mysql.env
    environment:
      MYSQL_DATABASE: "${MYSQL_DATABASE}"
      MYSQL_USER: "${MYSQL_USER}"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}" 
    volumes:
      - ./services/mysql/dbname.sql:/docker-entrypoint-initdb.d/dbname.sql
      #- ./services/mysql/config/my_personalizada.cnf:/etc/mysql/conf.d/my_personalizada.cnf
      - mysql-data:/var/lib/mysql

  phpmyadmin:
    image: "phpmyadmin/phpmyadmin:${PHPMYADMIN_VERSION}"
    container_name: "${APP_NAME:?err}-phpmyadmin"
    links: 
      - mysql
    ports:
      - 8000:80
    environment:
      PMA_HOST: mysql

volumes:
  mysql-data:
```

In the first line we declare that we are using version "3.7" of the Docker compose language.

Then we have the list of services, namely the `nginx`, `php`, `mysql` and the `phpmyadmin` services.

Let's see the properties of the services:

- `port` maps the 80 container port to the 80 host system port for `nginx` service, 3306 container port to the 3306 host system port for `mysql` service and 80 container port to the 8000 host system port for `phpmyadmin` service. 
- `build` can be specified either as a string containing a path to the build context or, as an object with the path specified under `context` and optionally `Dockerfile`.
- `links` declares that `nginx` container must be able to connect `php`. 
- `depends_on` declares that `mysql` needs to start before `php`. This is because we cannot do anything with our application until MySQL is ready to accept connections.
- `container_name` specify a custom container name, rather than a generated default name.
- `restart: on-failure` declares that the containers must restart if they crash.
- `volumes` creates volumes for the container if it is set in a service definition, or a volume that can be used by any container if it is set globally, at the same level as `services`. Volumes are directories in the host system that can be accessed by any number of containers. This allows destroying a container without losing data.
- `environment` sets environment variables inside the container. This is important because in setting these variables we set the MySQL `test` user and `root` credentials for the container and others like "APP_NAME" or "PHPMYADMIN_VERSION".
- `env_file` Add environment variables from a file. Can be a single value or a list. `env_file` will replace `environment` tag. The `.env` file for every service will be located at the root of the project directory.

## Volumes

It is good practice to create volumes for:

- The data directory, so we don't lose data when a container is created or replaced, perhaps to upgrade MySQL.
- The directory where we put all the logs, if it is not the data directory.
- The directory containing all configuration files (in this example we don't configure MySQL, `/etc/mysql/conf.d` ), so we can edit those files with the editor installed in the host system. Normally no editor is installed in containers. In production we don't need to do this, because we can copy files from a repository located in the host system to the containers.

Note that Docker Compose variables are just placeholders for values. Compose does not support assignment, conditionals or loops.

## Docker Backup: Saving and Restoring Volumes

#### Saving Volumes

The key here is to get a copy of a volume as a compressed file in one of our regular directories, like `/home/$USER/backups` or `$(PWD)` in our case.

First, we activate a temporary container and mount the backup folder and the target Docker volume in this container. When an ordinary directory like `$(PWD)/backup` is mounted inside a Docker container, we call it a "bind" mount. "Bind" mounts, unlike Docker "volumes", are not exclusively managed by Docker daemons, and therefore we can use them as our backup folder.

In our example, the main container is `myapp-mysql` which uses Docker volume `mysql-data`, mounted at `/var/lib/mysql`, to store all of its data. 

We first stop the container

```bash
docker stop myapp-mysql
```

Next, we spin up a temporary container with the volume and the backup folder mounted into it. We are going to create a folder called "backup" into the project directory where we will dump the ".tar" file.

```bash
mkdir backup
```

```bash
docker run --rm --volumes-from myapp-mysql -v $(pwd)/backup:/backup ubuntu bash -c "cd /var/lib/mysql && tar cvf /backup/myapp-mysql.tar ."
```

Let's comment out the "docker run" command:

- `--rm` flag tells Docker to remove the container once it stops.

- `--volumes-from myapp-mysql` : Mounts all the volumes from container `myapp-mysql` also to this temporary container. The mount points are the same as the original container.

- `-v $(pwd)/backup:/backup`: Bind mount of the `$(pwd)/backup` directory from your host to the `/backup` directory inside the temporary container.

- `ubuntu`: Specifies that the container should run an Ubuntu image.

- `bash -c “...” :` Backs up the contents as a tarball into `/backup` inside the container. This is the same `$(pwd)/backup` directory on your host system where a new `myapp-mysql.tar` file would appear.

#### Restoring Volumes

```bash
docker rm -f myapp-mysql

docker volume ls
DRIVER    VOLUME NAME
local     docker-compose-lemp_mysql-data

docker volume rm docker-compose-lemp_mysql-datadata

docker volume create my-backup-volume

sudo ls -l /var/lib/docker/volumes/my-backup-volume/_data
total 0

docker run --rm -v my-backup-volume:/recover -v $(pwd)/backup:/backup ubuntu bash -c "cd /recover && tar xvf /backup/myapp-mysql.tar"

sudo ls -l /var/lib/docker/volumes/my-backup-volume/_data
total 176192
-rw-r----- 1 systemd-coredump systemd-coredump       56 may  5 09:35 auto.cnf
-rw------- 1 systemd-coredump systemd-coredump     1676 may  5 09:35 ca-key.pem
-rw-r--r-- 1 systemd-coredump systemd-coredump     1112 may  5 09:35 ca.pem
-rw-r--r-- 1 systemd-coredump systemd-coredump     1112 may  5 09:35 client-cert.pem
-rw------- 1 systemd-coredump systemd-coredump     1676 may  5 09:35 client-key.pem
drwxr-x--- 2 systemd-coredump systemd-coredump     4096 may  5 09:35 dbname
-rw-r----- 1 systemd-coredump systemd-coredump     1172 may  5 10:41 ib_buffer_pool
-rw-r----- 1 systemd-coredump systemd-coredump 79691776 may  5 10:41 ibdata1
-rw-r----- 1 systemd-coredump systemd-coredump 50331648 may  5 10:41 ib_logfile0
-rw-r----- 1 systemd-coredump systemd-coredump 50331648 may  5 09:35 ib_logfile1
drwxr-x--- 2 systemd-coredump systemd-coredump     4096 may  5 09:35 mysql
drwxr-x--- 2 systemd-coredump systemd-coredump     4096 may  5 09:35 performance_schema
-rw------- 1 systemd-coredump systemd-coredump     1680 may  5 09:35 private_key.pem
-rw-r--r-- 1 systemd-coredump systemd-coredump      452 may  5 09:35 public_key.pem
-rw-r--r-- 1 systemd-coredump systemd-coredump     1112 may  5 09:35 server-cert.pem
-rw------- 1 systemd-coredump systemd-coredump     1676 may  5 09:35 server-key.pem
drwxr-x--- 2 systemd-coredump systemd-coredump    12288 may  5 09:35 sys

docker run --name myapp-mysql -d -v my-backup-volume:/var/lib/mysql -p 3306:3306 mysql:5.7.36
```

## Variables

In the above `docker-compose.yml` file you can see several variables, like `${MYSQL_VERSION}`. Before executing the file, Docker Compose will replace this syntax with the `MYSQL_VERSION` variable.

Variables allow making Docker Compose files more re-usable: in this case, we can use any MySQL image version without modifying the Docker Compose file.

The most common way to pass variables is to write them into a `.env` file located at the root of the project directory. This has the benefit of allowing us to version the variable file along with the Docker Compose file. It uses the same syntax you would use in BASH:

```bash
MYSQL_VERSION=5.7.36
MYSQL_DATABASE=dbname
```

For more complex setups, it could make sense to use different environment files for different services. Keep in mind, that `env_file` will replace `environment` tag. To do so, we need to specify the file to use in the Compose file:

```yml
services:
  www:
    env_file:
      - ./mysql.env
```

## Docker Compose Commands

Docker Compose is operated using `docker-compose`. Here we'll see the most common commands. For more commands and for more information about the commands mentioned here, see the documentation.

Docker Compose assumes that the Composer file is located in the current directory and it's called `docker-compose.yml`. To use a different file, the `-f <filename>` parameter must be specified.

You can use docker-compose as an orchestrator. To run these containers:

```
docker-compose up -d
```

Normally `docker-compose up` starts the containers. To create them without starting them, add the `--no-start` option. To restart containers without recreating them:

```bash
docker-compose restart
```

To kill a container by sending it a `SIGKILL`:

```bash
docker-compose kill <service>
```

To instantly remove a running container:

```bash
docker-compose rm -f <serice>
```

To see all variables in a container:

```bash
docker exec -it <service> bash
```

once inside the container run the env command.....

```bash
root@5ca9a4151799:/# env
```

The output should be something similiar to this.....

```bash
root@5ca9a4151799:/# env
MYSQL_MAJOR=5.7
HOSTNAME=5ca9a4151799
PWD=/
MYSQL_ROOT_PASSWORD=root
MYSQL_PASSWORD=test
MYSQL_USER=test
HOME=/root
MYSQL_VERSION=5.7.36-1debian10
GOSU_VERSION=1.12
TERM=xterm
SHLVL=1
MYSQL_DATABASE=dbname
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/env
```

To see all volumes:

```bash
docker volume ls
```

To instantly remove a volume:

```bash
docker volume rm <volume>
```

To tear down all containers created by the current Compose file:

```bash
docker-compose down
```

Open phpmyadmin at [http://localhost:8000](http://localhost:8000)

Open web browser to look at a simple php example at [http://localhost:80](http://localhost:80)

Run MySQL client as `root`:

- `docker exec -it myapp-mysql mysql -p` 

Run MySQL client as `test` user :

- `docker exec -it myapp-mysql mysql -u test -p`

Modifica y adapta el código como mejor te parezca, como en tu casa....... 😄

Infrastructure as code!!!
