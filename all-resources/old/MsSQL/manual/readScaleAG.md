This article explains how to create a SQL Server Always On Availability Group (AG) on Linux without a cluster manager. This architecture provides read-scale only. It doesn't provide high availability.

On Linux, you must create an availability group before you add it as a cluster resource to be managed by the cluster. This document provides an example that creates the availability group. For distribution-specific instructions to create the cluster and add the availability group as a cluster resource, see the links under : **to be added**

## step1 : 
setup the ip addresses. here we are ignoring it as in k8s cluster we can ping to <pod>.<svc> as DNS.

## step2 :
install mssql-server

## step3 : 
run the following command to enable aoag 

```bash 
#run in each server
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
sudo systemctl restart mssql-server
```

## step4 : 
enable health check (optional)

```bash
#run in each server
ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
```

## step5 : 
create certificate on primary 

```bash 
#run on the primary only
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i createCertPrimary.sql
```

## step6 : 
copy the certificate and private key from the primary to the secondaries 

```bash 
scp dbm_certificate.* root@**<node2>**:/var/opt/mssql/data/ #or do it with `kubectl cp` command 
```

## step7 : 
give permission to the certificates 

```bash
#run in each server
chown mssql:mssql /var/opt/mssql/data/dbm_certificate.*
```

## step8 : 
create certificate on secondaries 

```bash
#run on the secondaries only
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i createCertSecondary.sql
```

## step9 : 
create mirroring endpoints 

```bash
#run in each server
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i createEndpoint.sql
```

read the article part : https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-configure-rs?view=sql-server-ver16#create-the-database-mirroring-endpoints-on-all-replicas

read details :https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/the-database-mirroring-endpoint-sql-server?view=sql-server-ver16

## step10 : 
create read ag 

```bash 
#run on the primary only
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i createReadAG.sql
```

## step11 : 
join the ag 

```bash
#run on the secondaries only
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i joinAG.sql
```

## step12 : 
create db 

```bash
#run on the primary 
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i createDB.sql
```

## step13 : 
add db to the ag

```bash
#run on the primary 
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i addDB.sql
```

## step14 : 
check secondary 

```bash
#run on the secondary 
/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P'Pa55w0rd!' -i checkSecondary.sql
```