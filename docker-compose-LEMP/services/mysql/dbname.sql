
DROP DATABASE IF EXISTS dbname;

CREATE DATABASE dbname;

USE dbname;

CREATE TABLE IF NOT EXISTS films (
    id int(11) NOT NULL AUTO_INCREMENT,
    titulo varchar(50),
    director varchar(50),
    PRIMARY KEY (id)
);

INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'Los 7 Samurais', 'Akira Kurosawa' );
INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'Onibaba', 'Kaneto Shindo' );
INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'Kwaidan', 'Masaki Kobayashi' );
INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'El Infierno del Odio', 'Akira Kurosawa' );
INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'El Hombre del Carrito', 'Hiroshi Inagaki' );
INSERT INTO films ( id, titulo, director ) VALUES ( NULL, 'Sword of Doom', 'Kihachi Okamoto' );


CREATE USER test IDENTIFIED BY "test";

GRANT SELECT, INSERT, UPDATE, DELETE, FILE ON *.* TO `test`@`localhost`;

GRANT ALL PRIVILEGES ON `dbname`.* TO `test`@`localhost`;