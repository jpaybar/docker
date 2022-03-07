
DROP DATABASE IF EXISTS dbname;

CREATE DATABASE dbname;

USE dbname;

CREATE TABLE IF NOT EXISTS directores (
    id int(11) NOT NULL AUTO_INCREMENT,
    nombre varchar(50),
    apellido varchar(50),
    PRIMARY KEY (id)
);

INSERT INTO directores ( id, nombre, apellido ) VALUES ( NULL, 'Federico', 'Fellini' );
INSERT INTO directores ( id, nombre, apellido ) VALUES ( NULL, 'Akira', 'Kurosawa' );
INSERT INTO directores ( id, nombre, apellido ) VALUES ( NULL, 'Quentin', 'Tarantino' );
INSERT INTO directores ( id, nombre, apellido ) VALUES ( NULL, 'Peter', 'Jackson' );


CREATE USER test IDENTIFIED BY "test";

GRANT SELECT, INSERT, UPDATE, DELETE, FILE ON *.* TO `test`@`localhost`;

GRANT ALL PRIVILEGES ON `dbname`.* TO `test`@`localhost`;