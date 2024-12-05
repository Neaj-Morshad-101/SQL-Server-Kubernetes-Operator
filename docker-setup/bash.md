`docker run -h node_b --name node_b -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1472:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

`docker run -h node_c --name node_c -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1473:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

`docker network create mynet`

`docker run -h node_a --name node_a -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -e 'MSSQL_AGENT_ENABLED=True' -p 1471:1433 -d [mcr.microsoft.com/mssql/server:2019-latest](http://mcr.microsoft.com/mssql/server:2019-latest)`

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