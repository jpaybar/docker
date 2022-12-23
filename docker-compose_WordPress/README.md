# How to deploy WordPress with docker-compose

###### By Juan Manuel Payán / jpaybar

st4rt.fr0m.scr4tch@gmail.com



The following docker-compose.yml file builds two containers (WordPress and MySQL) and deploys WordPress in a basic way, configuring the volumes, the network and the secrets where the passwords for connecting to the MySQL container database will be.
There are more complex configurations when deploying the service, for more information read the official documentation:

[Docker WordPress](https://hub.docker.com/_/wordpress)

[Docker MySQL](https://hub.docker.com/_/mysql)

## Quickstart

### 1. Obtain the project folder

```bash
git clone https://github.com/jpaybar/Docker.git
cd Docker/docker-compose_WordPress
```

### 2. Project folder:

```bash
linuxuser@localhost:$ tree -a
.
├── docker-compose.yml
├── README.md
├── db-password.txt
└── _images
    ├── install_wordpress.PNG

```

### 3. docker-compose.yml

```yml
version: "3.8"

services:
  wordpress:
    image: wordpress:latest
    secrets:
      - db-password
    restart: always
    depends_on:
      - mysql
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: user
      WORDPRESS_DB_PASSWORD_FILE: /run/secrets/db-password
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress:/var/www/html
    networks:
      - WP_MySQL_network
    
  mysql:
    image: mysql:latest
    secrets:
      - db-password
    restart: always
    ports:
      - 3306
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: user
      MYSQL_PASSWORD_FILE: /run/secrets/db-password
      MYSQL_RANDOM_ROOT_PASSWORD: "1"
    volumes:
      - mysql:/var/lib/mysql
    networks:
      - WP_MySQL_network
      
secrets:
  db-password:
    file: ./db-password.txt
      
networks:
  WP_MySQL_network:
    driver: bridge

volumes:
  wordpress:
  mysql:
```

### 4. Run the docker-compose.yml

```bash
docker-compose up -d
```

To see all variables in a container:

```bash
docker-compose exec -it <service> bash
```

once inside the container run the env command.....

```bash
root@5ca9a4151799:/# env
```



### 5. To start WordPress

Open web browser to look at a simple php example at [http://localhost](http://localhost/)

![install_wordpress.PNG](https://github.com/jpaybar/Docker/blob/main/docker-compose_WordPress/_images/install_wordpress.PNG)



### 6. To tear down all containers created by the current Compose file:

```bash
docker-compose down --volumes
```



## Author Information

Juan Manuel Payán Barea    (IT Technician) [st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

[jpaybar (Juan M. Payán Barea) · GitHub](https://github.com/jpaybar)
https://es.linkedin.com/in/juanmanuelpayan
