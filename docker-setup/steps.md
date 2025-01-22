# Setting Up SQL Server Always On Availability Groups with Docker

## Overview
This guide provides step-by-step instructions for setting up SQL Server Always On Availability Groups (AG) using Docker containers. It covers container setup, network configuration, host updates, AG creation, and Pacemaker integration.

---

## Step 1: Start SQL Server Containers

### Commands:
```bash
# Start Node A
sudo docker run -h node_a --name node_a \
  -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' \
  -e 'MSSQL_AGENT_ENABLED=True' -p 1471:1433 -d mcr.microsoft.com/mssql/server:2019-latest
  
# Start Node B
sudo docker run -h node_b --name node_b \
  -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' \
  -e 'MSSQL_AGENT_ENABLED=True' -p 1472:1433 -d mcr.microsoft.com/mssql/server:2019-latest

# Start Node C
sudo docker run -h node_c --name node_c \
  -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=Pa55w0rd!' \
  -e 'MSSQL_AGENT_ENABLED=True' -p 1473:1433 -d mcr.microsoft.com/mssql/server:2019-latest

# Create Docker network
sudo docker network create mynet

# Connect containers to the network
sudo docker network connect mynet node_a
sudo docker network connect mynet node_b
sudo docker network connect mynet node_c
```

---

## Step 2: Inspect Network and Update Hosts File

### Commands:
```bash
# Inspect network to get container IPs
sudo docker network inspect mynet

# Access each container
sudo docker exec -it -u 0 node_a bash
sudo docker exec -it -u 0 node_b bash
sudo docker exec -it -u 0 node_c bash

# Install ping and nano tools
apt-get update -y
apt-get install -y iputils-ping nano

# Update `/etc/hosts` file on all nodes
nano /etc/hosts
```

### Add the following entries to `/etc/hosts`:
```
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
<node_a_ip>     node_a
<node_b_ip>     node_b
<node_c_ip>     node_c
```

---

## Step 3: Enable Always On Feature

### Commands:
```bash
# Enable HADR on each node
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
sudo systemctl restart mssql-server
```

---

## Step 4: Create and Distribute Certificates

### On the Primary Node:
```sql
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$tronGest++00';
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
   TO FILE = '/var/opt/mssql/data/dbm_certificate.cer'
   WITH PRIVATE KEY (
       FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
       ENCRYPTION BY PASSWORD = 'W33Kest++00'
   );
```

### Copy Certificates to Other Nodes:
```bash
# Export certificates from the primary node
sudo docker cp <primary_node_container_id>:/var/opt/mssql/data/dbm_certificate.cer ./dock
sudo docker cp <primary_node_container_id>:/var/opt/mssql/data/dbm_certificate.pvk ./dock

# Copy certificates to secondary nodes
sudo docker cp ./dock/dbm_certificate.cer <secondary_node_container_id>:/var/opt/mssql/data/
sudo docker cp ./dock/dbm_certificate.pvk <secondary_node_container_id>:/var/opt/mssql/data/

# Set ownership for mssql user
sudo docker exec -it <node_container_id> bash -c 'chown mssql:mssql /var/opt/mssql/data/dbm_certificate.*'
```

### On Each Node:
```sql
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<Master_Key_Password>';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
        DECRYPTION BY PASSWORD = '<Private_Key_Password>'
    );

CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
```

---

## Step 5: Configure Pacemaker

### Install and Configure Pacemaker:
Follow the Pacemaker guide for setting up SQL Server AG as a resource.

[Resource Agents Documentation](https://github.com/ClusterLabs/resource-agents/blob/main/doc/dev-guides/ra-dev-guide.asc#installing-and-packaging-resource-agents)

---