-- create databases
CREATE DATABASE IF NOT EXISTS wordpress2;

-- grant access rights to user
GRANT ALL PRIVILEGES ON wordpress2.* TO 'wpuser'@'%';

