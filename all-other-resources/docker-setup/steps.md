`docker run -h node_b --name node_b -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1472:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

`docker run -h node_c --name node_c -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1473:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

`docker network create mynet`

`docker run -h node_a --name node_a -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1471:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

`docker network connect mynet node_c
docker network connect mynet node_b
docker network connect mynet node_a`

get the node ips and relevant information with this command : `docker network inspect mynet`

exec into all the containers with command : `docker exec -it -u 0 node_a bash`

run the commands in all the containers to test ping : `apt-get update -y`  and then `apt-get install -y iputils-ping`

install nano on all containers : `apt-get install nano`

update host list on all nodes : `nano /etc/hosts`

`127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
172.17.0.3      node_b
172.21.0.2      node_a
172.21.0.3      node_b
172.21.0.4      node_c`

- create the ag
run this command on each container : sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
                                                             sudo systemctl restart mssql-server

run this sql on the master node 

CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$tronGest++00';
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
   TO FILE = '/var/opt/mssql/data/dbm_certificate.cer'
   WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           ENCRYPTION BY PASSWORD = 'W33Kest++00'
        );
-- run on only the primary



office@tasdid-pc:~$ sudo docker cp de4025850566:/var/opt/mssql/data/dbm_certificate.pvk ./dock
office@tasdid-pc:~$ sudo docker cp de4025850566:/var/opt/mssql/data/dbm_certificate.cer ./dock
office@tasdid-pc:~$ sudo docker cp ./dock/dbm_certificate.cer 35e0e8c36259:/var/opt/mssql/data/
office@tasdid-pc:~$ sudo docker cp ./dock/dbm_certificate.pvk 35e0e8c36259:/var/opt/mssql/data/
office@tasdid-pc:~$ sudo docker cp ./dock/dbm_certificate.pvk c387658bfc0b:/var/opt/mssql/data/
office@tasdid-pc:~$ sudo docker cp ./dock/dbm_certificate.cer c387658bfc0b:/var/opt/mssql/data/


run this command on each server : chown mssql:mssql dbm_certificate.*


CREATE MASTER KEY ENCRYPTION BY PASSWORD = '**<Master_Key_Password>**';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           DECRYPTION BY PASSWORD = '**<Private_Key_Password>**'
        );

CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = **<5022>**)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;





configure pacemaker ( or any cluster resource manager )
- add the ag as a resource 

https://github.com/ClusterLabs/resource-agents/blob/main/doc/dev-guides/ra-dev-guide.asc#installing-and-packaging-resource-agents



