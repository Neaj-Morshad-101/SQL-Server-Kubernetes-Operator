#!/bin/bash

# Create a new Docker network
docker network create mssql-net

# Create the first container
docker run -h mssql0 -d --name mssql0 --net mssql-net -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -p 1734:1433 -p 1722:22 -d mcr.microsoft.com/mssql/server:2019-latest

# Create the second container
docker run -h mssql1 -d --name mssql1 --net mssql-net -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -p 1735:1433 -p 1723:22 -d mcr.microsoft.com/mssql/server:2019-latest

# Create the third container
docker run -h mssql2 -d --name mssql2 --net mssql-net -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Pa55w0rd!' -p 1736:1433 -p 1724:22 -d mcr.microsoft.com/mssql/server:2019-latest

# Configure the first container as the primary
docker exec -it mssql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Pa55w0rd!' -Q 'ALTER DATABASE [master] SET HADR AVAILABILITY GROUP = mssqlag'

# Join the second container to the availability group
docker exec -it mssql2 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Pa55w0rd!' -Q 'ALTER DATABASE [master] SET HADR AVAILABILITY GROUP = mssqlag'

# Join the third container to the availability group
docker exec -it mssql3 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Pa55w0rd!' -Q 'ALTER DATABASE [master] SET HADR AVAILABILITY GROUP = mssqlag'

