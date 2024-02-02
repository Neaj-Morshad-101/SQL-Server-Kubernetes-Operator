# With sqlcmd tools installed, sql22 sudo nano 
# use this image as : neajmorshad/sql22:tools-0.1
FROM ubuntu:20.04       
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install apt-utils -y

RUN apt-get install sudo nano wget curl gnupg gnupg1 gnupg2 -y
RUN apt-get install software-properties-common systemd vim -y
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -


RUN add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
RUN apt-get update
RUN apt-get install -y mssql-server

# Enable hadr
# RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
# Enable sqlagent 
# RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true

# Accept the EULA for msodbcsql18 during installation
RUN echo "msodbcsql18 msodbcsql/ACCEPT_EULA boolean true" | debconf-set-selections

RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg && \
    mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/ && \
    wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1433 5022

ENTRYPOINT /opt/mssql/bin/sqlservr