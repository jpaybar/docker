# Setting Up a LAMP Stack with Docker Compose

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com

Docker Compose is a tool that allows one to declare which Docker containers should run, and which relationships should exist between them. It follows the <u>infrastructure as code</u> approach, just like most automation software.

This `docker-compose.yml` file configures three services to use the LAMP stack. The `www` service customizes a Docker Hub image using a `Dockerfile` and then starts Apache with PHP at version 8.0.0. The next service is `db`, a container with the MySQL image, the version can be modified in the variables file `.env` (It is necessary to rename the test.env file to .env once the project folder is downloaded so that the "docker-compose.yml" file reads the environment variables, github or the .gitignore file excludes the upload of .env files by security reasons). And finally we start `phpMyAdmin` to have a graphical environment and be able to manage our database.

## Project folder:

```bash
linuxuser@localhost:~/DOCKER/LAMP$ tree -a
.
├── .env
├── README.md
├── docker-compose.yml
└── servicios
    ├── db
    │   └── dbname.sql
    └── www
        ├── Dockerfile
        └── index.php
```

## 

## The docker-compose.yml File

```yaml
# https://docs.docker.com/compose/compose-file/compose-file-v3/
version: "3.7"
services:
  www:
    build: #.
      context: ./servicios/www
      #dockerfile: phpApache.Dockerfile
    depends_on:
      - db
    ports: 
      - 80:80
    volumes:
      - ./servicios/www:/var/www/html
    links:
      - db 
    #networks:
      #- red_lamp
  db:
    image: "mysql:${MYSQL_VERSION}"
    container_name: mysqlHost
    ports: 
      - 3306:3306
    #command: --default-authentication-plugin=mysql_native_password
    restart: always
    #env_file:
      #- ./db.env
    environment:
      MYSQL_DATABASE: "${MYSQL_DATABASE}"
      MYSQL_USER: "${MYSQL_USER}"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD}"
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}" 
    volumes:
      - ./servicios/db/dbname.sql:/docker-entrypoint-initdb.d/dbname.sql
      #- ./config/my_personalizada.cnf:/etc/mysql/conf.d/my_personalizada.cnf
      - mysql-data:/var/lib/mysql
    #networks:
      #- red_lamp
  phpmyadmin:
    image: "phpmyadmin/phpmyadmin:${PHPMYADMIN_VERSION}"
    links: 
      - db:db
    ports:
      - 8000:80
volumes:
  mysql-data:
#networks:
  #red_lamp:
```

In the first line we declare that we are using version "3.7" of the Docker compose language.

Then we have the list of services, namely the `www`, `db` and the `phpmyadmin` services.

Let's see the properties of the services:

- `port` maps the 80 container port to the 80 host system port for `www` service, 3306 container port to the 3306 host system port for `db` service and 80 container port to the 8000 host system port for `phpmyadmin` service. 
- `build` can be specified either as a string containing a path to the build context or, as an object with the path specified under `context` and optionally `Dockerfile`.
- `links` declares that `www` container must be able to connect `db`. The hostname is the container name.
- `depends_on` declares that `db` needs to start before `www`. This is because we cannot do anything with our application until MySQL is ready to accept connections.
- `container_name` specify a custom container name, rather than a generated default name.
- `restart: always` declares that the containers must restart if they crash.
- `volumes` creates volumes for the container if it is set in a service definition, or a volume that can be used by any container if it is set globally, at the same level as `services`. Volumes are directories in the host system that can be accessed by any number of containers. This allows destroying a container without losing data.
- `environment` sets environment variables inside the container. This is important because in setting these variables we set the MySQL `test` user and `root` credentials for the container.
- `env_file` Add environment variables from a file. Can be a single value or a list. `env_file` will replace `environment` tag. The `.env` file for every service will be located at the root of the project directory.

## Volumes

It is good practice to create volumes for:

- The data directory, so we don't lose data when a container is created or replaced, perhaps to upgrade MySQL.
- The directory where we put all the logs, if it is not the data directory.
- The directory containing all configuration files (in this example we don't configure MySQL, `/etc/mysql/conf.d` ), so we can edit those files with the editor installed in the host system. Normally no editor is installed in containers. In production we don't need to do this, because we can copy files from a repository located in the host system to the containers.

Note that Docker Compose variables are just placeholders for values. Compose does not support assignment, conditionals or loops.

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
      - ./www.env
```

## 

# Quickstart:

## Docker Compose Commands

Docker Compose is operated using `docker-compose`. Here we'll see the most common commands. For more commands and for more information about the commands mentioned here, see the documentation.

Docker Compose assumes that the Composer file is located in the current directory and it's called `docker-compose.yml`. To use a different file, the `-f <filename>` parameter must be specified.

You can use docker-compose as an orchestrator. To run these containers:

```bash
docker-compose up -d
```

Now, you may run these commands to see running services:

```bash
docker-compose ls
```

```bash
docker-compose ps
```

![status_containers.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_LAMP/images/status_containers.png)

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
docker-compose exec -it <service> bash
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

![phpmyadmin.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_LAMP/images/phpmyadmin.png)

Open web browser to look at a simple php example at [http://localhost:80](http://localhost:80)

![app_web.png](https://github.com/jpaybar/Docker/blob/main/docker-compose_LAMP/images/app_web.png)

## Port Forwarding:

`If we are running Docker in a VM (VirtualBox, Minikube, etc...)` we will have to do port forwarding on the NAT card. For example, in our `docker-compose.yaml` the `www` service maps port `80:80 (host:container)`, `so we will map the host's port 80 to the same port in the VirtualBox NAT adapter`. In the `phpmyadmin` service, the port mapping in the `docker-compose.yaml` file is `8000:80 (host:container)`, therefore `we will map port 8000 to 8000 in the VirtualBox NAT adapter`. We can see an example in the following screenshot .

![virtualbox_portforwarding.PNG](C:\Users\adm_payanjuanm\Downloads\Docker-main\docker-compose_LAMP\images\virtualbox_portforwarding.PNG)



## **NOTE:**

It may happen that when accessing the web application you see an error like this:

`Server unable to read htaccess file, denying access to be safe`
You just need to connect to the Apache container by running the following command and correcting the root directory permissions:

```bash
docker-compose exec -it www bash
```

```bash
root@0bc5535012f8:/var/www/html# chmod 755 .
```

That's all.

## Running MySQL client on `db` container

Run MySQL client as `root` (password "root"):

- `docker exec -it mysqlHost mysql -p` 

Run MySQL client as `test` user (password "test"):

- `docker exec -it mysqlHost mysql -u test -p`

Modifica y adapta el código como mejor te parezca, como en tu casa....... 😄

Infrastructure as code!!!

## Author Information

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)

https://es.linkedin.com/in/juanmanuelpayan
