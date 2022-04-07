FROM ubuntu:20.04
LABEL version="1.0" 
LABEL description="Se añade variable http_proxy y se instala python3 y apache2" 
LABEL other="Ubuntu 20.04 LTS (Focal Fossa)"
ENV http_proxy="http://10.40.56.3:8080"
ENV https_proxy="http://10.40.56.3:8080"
EXPOSE 80/tcp
ARG DEBIAN_FRONTEND=noninteractive	#Evita el frontend de configuración de paquetes(ej:apache2)
RUN apt-get update && apt-get install -y \ 
  python3 \
  apache2 \
  && rm -rf /var/lib/apt/lists/*
CMD ["apachectl", "-D", "FOREGROUND"]
