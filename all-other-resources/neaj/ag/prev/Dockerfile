FROM ubuntu:20.04
 
RUN apt-get update
 
RUN apt install sudo wget curl gnupg gnupg1 gnupg2 -y
RUN apt install software-properties-common systemd -y
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
 
RUN add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/18.04/mssql-server-2019.list)"
RUN apt-get update
RUN apt-get install -y mssql-server
 
RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true
 
EXPOSE 5022
EXPOSE 1433
 
ENTRYPOINT /opt/mssql/bin/sqlservr
