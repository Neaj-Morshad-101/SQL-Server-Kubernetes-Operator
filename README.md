# Microsoft SQL Server Kubernetes Operator POC

## Create and Configure Microsoft SQL Server Availability Group cluster on Kubernetes




### Enable the Availability Groups Feature and SQL Server Agent

We can enable features using the mssql-conf utility:
```
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
```
But we need to restart the `mssql-server.service` to apply these settings.

Alternatively, We can enable these features using environment variables, as shown in the provided StatefulSet:
```
          - name: MSSQL_AGENT_ENABLED
            value: "True"
          - name: MSSQL_ENABLE_HADR
            value: "1"
```


### Create StatefulSet and a Headless Service for communication between availability group replicas

```
kubectl apply -f availability-group/ag1/sts.yaml
```

Check StatefulSet, pod, service, and PVC status:

```
kubectl get sts,pods,secret,svc,pvc -n dag 

NAME                   READY   AGE
statefulset.apps/ag1   3/3     10m

NAME        READY   STATUS    RESTARTS   AGE
pod/ag1-0   1/1     Running   0          10m
pod/ag1-1   1/1     Running   0          10m
pod/ag1-2   1/1     Running   0          10m

NAME          TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)             AGE
service/ag1   ClusterIP   None         <none>        1433/TCP,5022/TCP   10m

NAME                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mssql-ag1-0   Bound    pvc-480cf940-b3ec-43e8-be1d-22b370f648be   2Gi        RWO            longhorn       <unset>                 10m
persistentvolumeclaim/mssql-ag1-1   Bound    pvc-be7ad850-12e8-46a0-9c86-f0905dacc7ea   2Gi        RWO            longhorn       <unset>                 10m
persistentvolumeclaim/mssql-ag1-2   Bound    pvc-8d0a0500-3665-424c-aa1a-18d1db4be53a   2Gi        RWO            longhorn       <unset>                 10m
```

### Update Hostnames (if you face any issue for hostname)
Ensure each SQL Server hostname is unique and less than 15 characters.
```
kubectl get pods -n dag -owide
NAME    READY   STATUS    RESTARTS   AGE   IP            NODE   NOMINATED NODE   READINESS GATES
ag1-0   1/1     Running   0          13m   10.42.0.128   neaj   <none>           <none>
ag1-1   1/1     Running   0          12m   10.42.0.129   neaj   <none>           <none>
ag1-2   1/1     Running   0          12m   10.42.0.130   neaj   <none>           <none>
```

Manually update the /etc/hosts file on each pod:
```
kubectl exec -it -n dag ag1-0 -- sh
# nano /etc/hosts
```

Example /etc/hosts configuration:
```
10.42.0.128     ag1-0.ag1.dag.svc.cluster.local ag1-0
10.42.0.129     ag1-1
10.42.0.130     ag1-2
```

### Check Pod Connectivity
Install ping tools and test connectivity between pods
```
kubectl exec -it ag1-0 -n dag -- bash
root@ag1-0:/# apt-get update -y
root@ag1-0:/# apt-get install -y iputils-ping
root@ag1-0:/# ping ag1-1.ag1
PING ag1-1.ag1.dag.svc.cluster.local (10.42.0.129) 56(84) bytes of data.
64 bytes from ag1-1.ag1.dag.svc.cluster.local (10.42.0.129): icmp_seq=1 ttl=64 time=0.036 ms
64 bytes from ag1-1.ag1.dag.svc.cluster.local (10.42.0.129): icmp_seq=2 ttl=64 time=0.091 ms
^C
--- ag1-1.ag1.dag.svc.cluster.local ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1013ms
rtt min/avg/max/mdev = 0.036/0.063/0.091/0.027 ms
root@ag1-0:/# ping ag1-2.ag1
PING ag1-2.ag1.dag.svc.cluster.local (10.42.0.130) 56(84) bytes of data.
64 bytes from ag1-2.ag1.dag.svc.cluster.local (10.42.0.130): icmp_seq=1 ttl=64 time=0.224 ms
64 bytes from ag1-2.ag1.dag.svc.cluster.local (10.42.0.130): icmp_seq=2 ttl=64 time=0.069 ms
^C
--- ag1-2.ag1.dag.svc.cluster.local ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1044ms
rtt min/avg/max/mdev = 0.069/0.146/0.224/0.077 ms
root@ag1-0:/# 
```



### Install MSSQL Extension for Visual Studio Code for easy query execution.
Follow the official guide: https://learn.microsoft.com/en-us/sql/tools/visual-studio-code/mssql-extensions?view=sql-server-ver16

Port forward to the pod where we want to run query:
```
kubectl port-forward ag1-0 -n dag 1400:1433
```
---

#### Create a Connection Profile in Visual Studio Code
Follow the steps in the guide to create a connection profile:  
[Create a Connection Profile](https://learn.microsoft.com/en-us/sql/tools/visual-studio-code/mssql-extensions?view=sql-server-ver16#connect-and-query)

##### Connection Details
- **Server name:** `127.0.0.1,1400`
- **Database name:** *(Press Enter to skip)*
- **Authentication type:** `SQL Login`
- **Username:** `sa`
- **Password:** `Pa55w0rd!` *(Use the MSSQL_SA_PASSWORD from the StatefulSet)*
- **Profile name:** `ag1-0`

> **Note:** Ensure the password meets the security requirements:
> - Minimum 8 characters
> - Includes digits and special characters

---

##### Create and Execute Queries in Visual Studio Code
1. Create a file named `test.sql` in Visual Studio Code.
2. Write the SQL commands you want to execute in the file.
3. Select the commands you want to run, right-click, and choose **Execute Query**.
4. Select the appropriate profile (e.g., `ag1-0`) when prompted.

---

##### Execute Queries Directly in the Pod
You can also execute SQL queries by logging into the pod and using the `sqlcmd` tool:

```bash
kubectl exec -it ag1-0 -n dag -- bash
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P Pa55w0rd! -No
```

### Example Query
```sql
1> SELECT name FROM sys.databases;
2> GO
```

We can pass a sql file to cli to execute like this:
```
/opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P "Pa55w0rd!" -No -i create_AG.sql
```


See logs of pods using the following command.
```
kubectl logs -f -n dag ag1-0
```



### Create Availability Group Endpoints and Certificates
An availability group uses TCP endpoints for communication. Under Linux, endpoints for an AG are only supported if certificates are used for authentication. You must restore the certificate from one instance on all other instances that will participate as replicas in the same AG. The certificate process is required even for a configuration-only replica.

***You can use non-SQL Server-generated certificates as well. You also need a process to manage and replace any certificates that expire.***
https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-create-availability-group?view=sql-server-ver16&tabs=ru#:~:text=An%20availability%20group%20uses,any%20certificates%20that%20expire.
Example:
```bash
openssl genrsa -out dbm_private_key.pem 3072
openssl req -new -key dbm_private_key.pem -out dbm_csr.pem -subj "/CN=dbm1"
openssl x509 -req -in dbm_csr.pem -signkey dbm_private_key.pem -out dbm_certificate.pem -days 3650

openssl pkcs12 -export -out CERTIFICATE.pfx -inkey dbm_private_key.pem -in dbm_certificate.pem
# this will ask for password. provide a password

kubectl cp CERTIFICATE.pfx ag1-0:/var/opt/mssql/certs/CERTIFICATE.pfx 
kubectl cp CERTIFICATE.pfx ag1-1:/var/opt/mssql/certs/CERTIFICATE.pfx 
kubectl cp CERTIFICATE.pfx ag1-2:/var/opt/mssql/certs/CERTIFICATE.pfx 
```
```sql
create certificate dbm from file = '/var/opt/mssql/certs/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'provide_the_pfx_encryption_password');
go

--- 1. backup password if you want 
BACKUP CERTIFICATE dbm
TO FILE = '/tmp/CERTIFICATE3.pfx'
With format = 'PFX', PRivate key (
    Encryption by password = 'ENCRYPTION_PASSWORD',
    ALGORITHM = 'AES_256'
)
go

--- 2. you can create certificate again from that backup certificate
drop certificate dbm;
create certificate dbm from file = '/tmp/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'ENCRYPTION_PASSWORD');
go
```


*On the primary replica: ag1-0*
```
$ kubectl exec -it -n dag ag1-0 -- bash
-- Create the instance-level login
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "CREATE LOGIN dbm_login WITH PASSWORD = 'Pa55w0rd\!';"
root@ag1-0:/# 
-- Verify that the login was created:
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT name FROM sys.sql_logins WHERE name = 'dbm_login';"
root@ag1-0:/# 
-- create a master key for private key encryption
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa55w0rd\!';"
root@ag1-0:/# 
-- create the certificate
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';"
root@ag1-0:/# 


root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
BACKUP CERTIFICATE dbm_certificate 
TO FILE = '/tmp/dbm_certificate.cer' 
WITH PRIVATE KEY (
    FILE = '/tmp/dbm_certificate.pvk', 
    ENCRYPTION BY PASSWORD = 'Pa55w0rd\!'
);
"
root@ag1-0:/# 
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
-- Create endpoint
CREATE ENDPOINT [Hadr_endpoint] 
   AS TCP (
      LISTENER_IP = (0.0.0.0), 
      LISTENER_PORT = 5022
   ) 
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
   );

-- Start the endpoint
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
"

root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
-- Grant login permission to connect to the endpoint
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
"
-- Enable AlwaysOn_health Event Session:
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
"
```



### Copy the certificate and the private key from primary replica to other replicas
```
# Copy the private key and certificate from the primary replica (ag1-0) to the local system
kubectl cp dag/ag1-0:/tmp/dbm_certificate.pvk ./dbm_certificate.pvk
kubectl cp dag/ag1-0:/tmp/dbm_certificate.cer ./dbm_certificate.cer


-- Copy the certificate and private key from the local system to the secondary replicas:
# Copy the certificate and private key to the secondary replica ag1-1
kubectl cp ./dbm_certificate.cer dag/ag1-1:/tmp/dbm_certificate.cer
kubectl cp ./dbm_certificate.pvk dag/ag1-1:/tmp/dbm_certificate.pvk

# Copy the certificate and private key to the secondary replica ag1-2
kubectl cp ./dbm_certificate.cer dag/ag1-2:/tmp/dbm_certificate.cer
kubectl cp ./dbm_certificate.pvk dag/ag1-2:/tmp/dbm_certificate.pvk
```


```
-- Set the group and ownership of the private key and the certificate to mssql:mssql.
kubectl exec -it -n dag ag1-1 -- bash
root@ag1-1:/# cd tmp 
root@ag1-1:/tmp# ls
dbm_certificate.cer  dbm_certificate.pvk
root@ag1-1:/tmp# sudo chown mssql:mssql /tmp/dbm_certificate.*

kubectl exec -it -n dag ag1-2 -- bash
root@ag1-2:/# sudo chown mssql:mssql /tmp/dbm_certificate.*
-- verify ownership 
root@ag1-2:/tmp# ls -la
drwxrwxrwt 1 root  root  4096 Jan 22 13:43 .
drwxr-xr-x 1 root  root  4096 Jan 22 12:29 ..
-rw-rw-r-- 1 mssql mssql  923 Jan 22 13:43 dbm_certificate.cer
-rw-rw-r-- 1 mssql mssql 1788 Jan 22 13:43 dbm_certificate.pvk
```




## Configure Secondary Replicas with Certificates and Endpoint

Create the certificate and endpoint On each secondary replica (ag1-1, ag1-2), follow these steps:
```
$ kubectl exec -it -n dag ag1-1 -- bash
-- Create the dbm_login
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "CREATE LOGIN dbm_login WITH PASSWORD = 'Pa55w0rd\!';"

-- Create the Master Key:
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa55w0rd\!';"
-- Create the Certificate: Assuming you’ve already copied the certificate and private key files to /tmp/ on the pods:

root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Pa55w0rd\!');
"
--- Create the Endpoint:

root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
"
-- Grant Login Permissions to Connect to the Endpoint:
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
"

-- Enable AlwaysOn_health Event Session:
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
"
```

Repeat Steps for Other Replica. Replace ag1-1 with ag1-2 and execute the same commands for the other secondary replica.


### Create Always On Availability Group on Primary Replica


Create an Availability Group (AG) named `ag1` with `CLUSTER_TYPE = NONE` and set the replicas with `FAILOVER_MODE = MANUAL`.
> This configuration supports analytics or reporting workloads by allowing connections to secondary replicas. Optionally, a read-only routing list can be created.



The following Transact-SQL script creates an AG named ag1. 
> The script configures the AG replicas with SEEDING_MODE = AUTOMATIC. This setting causes SQL Server to automatically create the database on each secondary server after it's added to the AG.

```
kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
CREATE AVAILABILITY GROUP [AG1]
WITH (CLUSTER_TYPE = NONE)
FOR REPLICA ON
    N'ag1-0'
        WITH (
            ENDPOINT_URL = N'tcp://ag1-0.ag1:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        ),
    N'ag1-1'
        WITH (
            ENDPOINT_URL = N'tcp://ag1-1.ag1:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        ),
    N'ag1-2'
        WITH (
            ENDPOINT_URL = N'tcp://ag1-2.ag1:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        );
"


-- Grant the ability to create databases in the Availability Group:
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
"
```


### Join Secondary Replicas to the Availability Group
```
kubectl exec -it -n dag ag1-1 -- bash 

root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE);
"
-- Grant the ability to create databases:
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
"
```

```
kubectl exec -it -n dag ag1-2 -- bash 

root@ag1-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [AG1] JOIN WITH (CLUSTER_TYPE = NONE);
"
-- Grant the ability to create databases:
root@ag1-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [AG1] GRANT CREATE ANY DATABASE;
"
```


See AG Status

```
➤ kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
-- See AG replicas 
1> SELECT replica_server_name FROM sys.availability_replicas;
2> go
replica_server_name                                                                                                                                                                                                                                             
-------------------
ag1-0                                                                                                                                                                                                                                                           
ag1-1                                                                                                                                                                                                                                                           
ag1-2                                                                                                                                                                                                                                                           

(3 rows affected)
1> select database_name from sys.availability_databases_cluster;
2> go
database_name                                                                                                                   
---------------

(0 rows affected)
1> SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
2> go
is_local role_desc                                                    synchronization_health_desc                                 
-------- ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      NOT_HEALTHY                                                 
       0 SECONDARY                                                    NOT_HEALTHY                                                 
       0 SECONDARY                                                    NOT_HEALTHY                                                 

(3 rows affected)
1> 
```


### Create the Availability Group Database on Primary

Ensure that the database you add to the availability group is in the full recovery model and has a valid backup

```
➤ kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No

1> CREATE DATABASE agtestdb;
2> go
1> ALTER DATABASE agtestdb SET RECOVERY FULL;
2> go
1> BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
2> go
Processed 344 pages for database 'agtestdb', file 'agtestdb' on file 1.
Processed 1 pages for database 'agtestdb', file 'agtestdb_log' on file 1.
BACKUP DATABASE successfully processed 345 pages in 0.430 seconds (6.253 MB/sec).
1> ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [agtestdb];
2> go
-- insert some test data  and check it is replicated or not 
1> USE agtestdb;
2> go
Changed database context to 'agtestdb'.
1> CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
2> go
1> INSERT INTO inventory VALUES (1, 'banana', 150); 
2> INSERT INTO Inventory VALUES (2, 'orange', 154);
3> go

(1 rows affected)

(1 rows affected)
1> SELECT * FROM inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
```

```
--- Check the data is replicated in the secondary: connect to the secondary and run
kubectl exec -it -n dag ag1-1 -- bash
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
1> USE agtestdb;
2> go
Changed database context to 'agtestdb'.
1> SELECT * FROM inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)

--- 

kubectl exec -it -n dag ag1-2 -- bash
root@ag1-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
1>  USE agtestdb;
2> go
Changed database context to 'agtestdb'.
1> SELECT * FROM inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
```

So inserted data is replicated to secondaries. 


See AG Status Now. 

```
➤ kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
1> select database_name from sys.availability_databases_cluster;
2> go
database_name                                                                                                                   
------------------------
agtestdb                                                                                                                        

(1 rows affected)
1> SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
2> go
is_local role_desc                                                    synchronization_health_desc                                 
-------- ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     

(3 rows affected)
1> 
```




## Fail-over the availability group
```
-- Promote the target secondary replica to primary.
use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 

```





```
--  After failover, all secondary databases are suspended, we need to change the role and resume synchronization from the old primary replica. It need to be done for the secondary replicas also.
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME
```

If old primary was unavailable / offline during the force-failver:

```
-- we need to make the AG offline when the old primary joins back. to change it's role from primary to secondary. (if it wasn't online during fail-over, then  after joining it's role will be primary also, Old primary's role will not be changed by running    
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY);

-- We need to make the AG offline from the old primary then it's role will be "RESOLVING".      
USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE

-- Now we can change it's role by running the following command

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME

```







### Add or remove replca in AG
```
USE [master]
ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-1';
```

```
USE [master]
ALTER AVAILABILITY GROUP [ag1]
      ADD REPLICA ON 
      N'repl-3'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.repl:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
```


We have to Join Availability Group from newly added replica: repl-3
```
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
```

```
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO
```




### Check availability group status
```
------------------------ Dynamic Management Views ------------------------------
SELECT * FROM sys.dm_hadr_availability_replica_states
SELECT * FROM sys.dm_hadr_availability_group_states;
SELECT * FROM sys.dm_hadr_database_replica_cluster_states;
SELECT * FROM sys.dm_hadr_database_replica_states; 
SELECT * FROM sys.availability_databases_cluster
SELECT * FROM sys.availability_replicas;
SELECT * FROM sys.availability_groups

Status:
SELECT replica_server_name FROM sys.availability_replicas;
select database_name from sys.availability_databases_cluster;
SELECT synchronization_health_desc from sys.dm_hadr_availability_group_states
SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
SELECT synchronization_health_desc from sys.dm_hadr_availability_replica_states WHERE is_local = 1 
SELECT name FROM sys.availability_groups
SELECT required_synchronized_secondaries_to_commit FROM sys.availability_groups WHERE name = 'mssqlag';

Config Change: 
ALTER AVAILABILITY GROUP [mssqlagcluster] OFFLINE
ALTER AVAILABILITY GROUP [mssqlagcluster] SET (ROLE = SECONDARY);
ALTER AVAILABILITY GROUP mssqlagcluster SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0);

AG Database:
ALTER DATABASE [agdb1] SET HADR RESUME;
ALTER DATABASE [agdb2] SET HADR RESUME;
ALTER DATABASE [agdb1] SET HADR OFF;
DROP DATABASE [agdb1];

AG Replica Related:
Join:
ALTER AVAILABILITY GROUP [mssqlagcluster] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [mssqlagcluster] GRANT CREATE ANY DATABASE;

Add/Remove:	
USE [master]
ALTER AVAILABILITY GROUP [mssqlagcluster]
	ADD REPLICA ON N'mssql-ag-cluster-1'WITH (
	ENDPOINT_URL = N'tcp://mssql-ag-cluster-1.mssql-ag-cluster-pods.demo.svc:5022',
	AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC, FAILOVER_MODE = MANUAL,
	SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL));
USE [master]
ALTER AVAILABILITY GROUP [mssqlagcluster] REMOVE REPLICA ON N'mssql-ag-0';

AG Create/Delete:
DROP AVAILABILITY GROUP [mssqlagcluster];

ALTERS:
ALTER LOGIN sa WITH PASSWORD = 'Pa55w0rd'

Status:
SELECT physical_memory_kb / 1024 AS physical_memory_mb FROM sys.dm_os_sys_info;
SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID;
SELECT default_language_name FROM sys.server_principals WHERE name = 'sa';  -- or your specific login name

General SQL Server Commands:
cat /var/opt/mssql/mssql.conf
mssql running?
ps aux | grep -v grep | grep -c sqlservr
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
/opt/mssql-tools18/bin/sqlcmd -S ${host},${port} -U ${username} -P ${password} -d ${database}
with TLS:
sqlcmd -S ${host},${port} -U ${username} -P ${password} -d ${database} -N
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P JzbyIXY6i5Wa4TSi -Q SHUTDOWN -No
SELECT SERVERPROPERTY('IsSingleUser')
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';

For Testing:
SELECT name FROM sys.databases
GO
CREATE DATABASE test; 
GO
CREATE TABLE Data (ID INT, NAME NVARCHAR(255), AGE INT);
INSERT INTO Data(ID, Name, Age) VALUES (1, 'John Doe', 25), (2, 'Jane Smith', 30);                     
GO
SELECT * from data
go
INSERT INTO Data(ID, Name, Age) VALUES (3, 'John Doe', 25);
first fail-over: 
INSERT INTO Data(ID, Name, Age) VALUES (4, 'John Doe', 25);
2nd fail-over: 
INSERT INTO Data(ID, Name, Age) VALUES (5, 'John Doe', 25);
INSERT INTO Data(ID, Name, Age) VALUES (6, 'John Doe', 25);
Status: 

```



```
-- Other helpful commands
-- LOGS
SELECT * FROM sys.dm_tran_active_transactions

SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled;

-- SQL Server Agent status
SELECT * FROM sys.dm_server_services
-- 
USE [master]
SELECT sequence_number FROM sys.availability_groups 


SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_state_desc, 
	drs.is_commit_participant, 
	drs.synchronization_health_desc, 
	drs.recovery_lsn,
   drs.end_of_log_lsn,
	drs.truncation_lsn, 
	drs.last_sent_lsn, 
	drs.last_sent_time, 
	drs.last_received_lsn, 
	drs.last_received_time, 
	drs.last_hardened_lsn, 
	drs.last_hardened_time, 
	drs.last_redone_lsn, 
	drs.last_redone_time, 
	drs.log_send_queue_size, 
	drs.log_send_rate, 
	drs.redo_queue_size, 
	drs.redo_rate, 
	drs.filestream_send_rate, 
	drs.end_of_log_lsn, 
	drs.last_commit_lsn, 
	drs.last_commit_time
FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_databases_cluster AS adc 
	ON drs.group_id = adc.group_id AND 
	drs.group_database_id = adc.group_database_id
INNER JOIN sys.availability_groups AS ag
	ON ag.group_id = drs.group_id
INNER JOIN sys.availability_replicas AS ar 
	ON drs.group_id = ar.group_id AND 
	drs.replica_id = ar.replica_id
ORDER BY 
	ag.name, 
	ar.replica_server_name, 
	adc.database_name;
```





## Backup Restore 
```
USE [master]
GO

CREATE DATABASE [SQLTestDB]
GO

USE [SQLTestDB]
GO
CREATE TABLE SQLTest (
   ID INT NOT NULL PRIMARY KEY,
   c1 VARCHAR(100) NOT NULL,
   dt1 DATETIME NOT NULL DEFAULT GETDATE()
)
GO

INSERT INTO SQLTest (ID, c1) VALUES (1, 'test1')
INSERT INTO SQLTest (ID, c1) VALUES (2, 'test2')
INSERT INTO SQLTest (ID, c1) VALUES (3, 'test3')
INSERT INTO SQLTest (ID, c1) VALUES (4, 'test4')
INSERT INTO SQLTest (ID, c1) VALUES (5, 'test5')
GO

SELECT * FROM SQLTest
GO

USE SQLTestDB;
GO
-- Full backup
BACKUP DATABASE SQLTestDB
TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.bak'
   WITH FORMAT,
      MEDIANAME = 'SQLServerBackups',
      NAME = 'Full Backup of SQLTestDB';
GO
-- Differential backup
BACKUP DATABASE SQLTestDB  
   TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.DIF'
   WITH DIFFERENTIAL;  
GO  
-- Log backup
BACKUP LOG SQLTestDB
   TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.trn'
GO


-- Restore

USE [master]
GO

DROP DATABASE SQLTestDB;
GO 

RESTORE DATABASE SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.bak'
    WITH FILE = 1,
    NORECOVERY;

use [SQLTestDB]
SELECT * FROM SQLTest
GO
-- Database 'SQLTestDB' cannot be opened. It is in the middle of a restore.


-- restoring diff backup 
use [master]
RESTORE DATABASE SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.DIF'
    WITH FILE = 1,
    NORECOVERY;

use [master]
RESTORE LOG SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.trn'
    WITH FILE = 1, 
    NORECOVERY;


-- If try to restore after recover:
-- Msg 3117, Level 16, State 1, Line 2
-- The log or differential backup cannot be restored because no files are ready to rollforward.
-- Msg 3013, Level 16, State 1, Line 2
-- RESTORE LOG is terminating abnormally.


--- We have to recover the database later.
-- first we have to perform restoration of the full backup then -> diff backup -> log backup 

RESTORE DATABASE SQLTestDB WITH RECOVERY;

```



# Distributed Availability Group
**Use Cases**
1. **Disaster recovery** (multi-site/data center).  
2. **Migrations** (replaces legacy methods like backup/restore or log shipping).  

The process of configuring DAG is almost same as AG configuration. 
Create two cluster and create two AG. We have to create Load balancer service for inter cluster communication. Add label to primary replica of each AG, for load balancer service.

[distributed-ag](/distributed-ag) folder contains all the resource to configure DAG. 





Check resources related to these stuff [important-links](important-links.md)





## Publisher Subcriber model

```
USE [master]

select name from sys.databases 
go


CREATE DATABASE Sales
GO
USE [SALES]
GO 
CREATE TABLE CUSTOMER([CustomerID] [int] NOT NULL, [SalesAmount] [decimal] NOT NULL)
GO 
INSERT INTO CUSTOMER (CustomerID, SalesAmount) VALUES (1,100),(2,200),(3,300)


USE [SALES]
INSERT INTO CUSTOMER (CustomerID, SalesAmount) VALUES (4,100),(5,200),(6,300)

select * from Customer;



-- Optional: create another table that will be replicated also

CREATE TABLE employee([employeeID] [int] NOT NULL, [SalaryAmount] [decimal] NOT NULL)
GO 
INSERT INTO employee (employeeID, SalaryAmount) VALUES (1,100),(2,200),(3,300)



select * from employee;



-- Optional: create another table that will be replicated also

CREATE TABLE employ([employeeID] [int] NOT NULL, [SalaryAmount] [decimal] NOT NULL)
GO 
INSERT INTO employ (employeeID, SalaryAmount) VALUES (1,100),(2,200),(3,300)



select * from Customer;
select * from employee;
select * from employ;


--

-- Step 03: Create the snapshot folder for SQL Server Agents to read/write to on the distributor, 
-- create the snapshot folder and grant access to 'mssql' user
sudo mkdir /var/opt/mssql/data/ReplData/
sudo chown mssql /var/opt/mssql/data/ReplData/
sudo chgrp mssql /var/opt/mssql/data/ReplData/


--- MOST IMPORTANT ------
-- edit /etc/hosts    in both hosts like this
10.244.0.34     mssql-0.mssql.default.svc.cluster.local mssql-0
10.244.0.35     mssql-1


-- ping to check connectivity
apt-get update && apt-get install -y iputils-ping




-- Step 04: Configure distributor. In this example, the publisher will also be the distributor. Run the following commands on the publisher to configure the instance for distribution as well.
DECLARE @distributor AS sysname
DECLARE @distributorlogin AS sysname
DECLARE @distributorpassword AS sysname
-- Specify the distributor name. Use 'hostname' command on in terminal to find the hostname
SET @distributor = N'mssql-0'--in this example, it will be the name of the publisher
SET @distributorlogin = N'sa'
SET @distributorpassword = N'Pa55w0rd!'
-- Specify the distribution database. 

use master
exec sp_adddistributor @distributor = @distributor -- this should be the hostname

-- Log into distributor and create Distribution Database. In this example, our publisher and distributor is on the same host
exec sp_adddistributiondb @database = N'distribution', @log_file_size = 2, @deletebatchsize_xact = 5000, @deletebatchsize_cmd = 2000, @security_mode = 0, @login = @distributorlogin, @password = @distributorpassword
GO

DECLARE @snapshotdirectory AS nvarchar(500)
SET @snapshotdirectory = N'/var/opt/mssql/data/ReplData/'

-- Log into distributor and create Distribution Database. In this example, our publisher and distributor is on the same host
use [distribution] 
if (not exists (select * from sysobjects where name = 'UIProperties' and type = 'U ')) 
       create table UIProperties(id int) 
if (exists (select * from ::fn_listextendedproperty('SnapshotFolder', 'user', 'dbo', 'table', 'UIProperties', null, null))) 
       EXEC sp_updateextendedproperty N'SnapshotFolder', @snapshotdirectory, 'user', dbo, 'table', 'UIProperties' 
else 
      EXEC sp_addextendedproperty N'SnapshotFolder', @snapshotdirectory, 'user', dbo, 'table', 'UIProperties'
GO





-- Step 05: Configure publisher. Run the following T-SQL commands on the publisher.
DECLARE @publisher AS sysname
DECLARE @distributorlogin AS sysname
DECLARE @distributorpassword AS sysname
-- Specify the distributor name. Use 'hostname' command on in terminal to find the hostname
SET @publisher = N'mssql-0' 
SET @distributorlogin = N'sa'
SET @distributorpassword = N'Pa55w0rd!'
-- Specify the distribution database. 

-- Adding the distribution publishers
exec sp_adddistpublisher @publisher = @publisher, 
@distribution_db = N'distribution', 
@security_mode = 0, 
@login = @distributorlogin, 
@password = @distributorpassword, 
@working_directory = N'/var/opt/mssql/data/ReplData', 
@trusted = N'false', 
@thirdparty_flag = 0, 
@publisher_type = N'MSSQLSERVER'
GO




-- Step 06: Configure publication job. Run the following T-SQL commands on the publisher.
DECLARE @replicationdb AS sysname
DECLARE @publisherlogin AS sysname
DECLARE @publisherpassword AS sysname
SET @replicationdb = N'Sales'
SET @publisherlogin = N'sa'
SET @publisherpassword = N'Pa55w0rd!'

use [Sales]
exec sp_replicationdboption @dbname = N'Sales', @optname = N'publish', @value = N'true'

-- Add the snapshot publication
exec sp_addpublication 
@publication = N'SnapshotRepl', 
@description = N'Snapshot publication of database ''Sales'' from Publisher ''mssql-0''.',
@retention = 0, 
@allow_push = N'true',
@repl_freq = N'snapshot',  --    @repl_freq = N'continuous', *** check it: for always be up to date and replicate changes as they occur, 
@status = N'active', 
@independent_agent = N'true'

exec sp_addpublication_snapshot @publication = N'SnapshotRepl', 
@frequency_type = 1, 
@frequency_interval = 1, 
@frequency_relative_interval = 1, 
@frequency_recurrence_factor = 0, 
@frequency_subday = 8, 
@frequency_subday_interval = 1, 
@active_start_time_of_day = 0,
@active_end_time_of_day = 235959, 
@active_start_date = 0, 
@active_end_date = 0, 
@publisher_security_mode = 0, 
@publisher_login = @publisherlogin, 
@publisher_password = @publisherpassword





-- Step 07: Create articles from the sales table Run the following T-SQL commands on the publisher.
use [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', 
@article = N'customer', 
@source_owner = N'dbo', 
@source_object = N'customer',    -- So only customer t
@type = N'logbased', 
@description = null, 
@creation_script = null, 
@pre_creation_cmd = N'drop', 
@schema_option = 0x000000000803509D,
@identityrangemanagementoption = N'manual', 
@destination_table = N'customer', 
@destination_owner = N'dbo', 
@vertical_partition = N'false'

-- Optional: Adding anothe article for another table.
USE [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', -- Use the existing publication name
@article = N'employee',        -- Set the name of the new article ("employee" in this case)
@source_owner = N'dbo',        -- Source schema (if the "employee" table is in the "dbo" schema)
@source_object = N'employee',  -- Source table name ("employee" in this case)
@type = N'logbased',           -- Type of article (logbased for Transactional Replication)
@description = null,           -- Optional description
@creation_script = null,       -- Optional creation script
@pre_creation_cmd = N'drop',   -- What to do if the article already exists (e.g., drop or keep)
@schema_option = 0x000000000803509D,  -- Schema options
@identityrangemanagementoption = N'manual', -- Identity range management
@destination_table = N'employee',  -- Destination table name at the subscriber
@destination_owner = N'dbo',      -- Destination schema at the subscriber
@vertical_partition = N'false'     -- Replicate the entire table

-- Optional: Adding anothe article for another table.
USE [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', -- Use the existing publication name
@article = N'employ',        -- Set the name of the new article ("employee" in this case)
@source_owner = N'dbo',        -- Source schema (if the "employee" table is in the "dbo" schema)
@source_object = N'employ',  -- Source table name ("employee" in this case)
@type = N'logbased',           -- Type of article (logbased for Transactional Replication)
@description = null,           -- Optional description
@creation_script = null,       -- Optional creation script
@pre_creation_cmd = N'drop',   -- What to do if the article already exists (e.g., drop or keep)
@schema_option = 0x000000000803509D,  -- Schema options
@identityrangemanagementoption = N'manual', -- Identity range management
@destination_table = N'employ',  -- Destination table name at the subscriber
@destination_owner = N'dbo',      -- Destination schema at the subscriber
@vertical_partition = N'false'     -- Replicate the entire table







-- Step 08: Configure Subscription. Run the following T-SQL commands on the publisher.
DECLARE @subscriber AS sysname
DECLARE @subscriber_db AS sysname
DECLARE @subscriberLogin AS sysname
DECLARE @subscriberPassword AS sysname
SET @subscriber = N'mssql-1' -- for example, MSSQLSERVER
SET @subscriber_db = N'Sales'
SET @subscriberLogin = N'sa'
SET @subscriberPassword = N'Pa55w0rd!'

use [Sales]
exec sp_addsubscription 
@publication = N'SnapshotRepl', 
@subscriber = @subscriber,
@destination_db = @subscriber_db, 
@subscription_type = N'Push', 
@sync_type = N'automatic', 
@article = N'all', 
@update_mode = N'read only', 
@subscriber_type = 0

exec sp_addpushsubscription_agent 
@publication = N'SnapshotRepl', 
@subscriber = @subscriber,
@subscriber_db = @subscriber_db, 
@subscriber_security_mode = 0, 
@subscriber_login = @subscriberLogin,
@subscriber_password = @subscriberPassword,
@frequency_type = 1,
@frequency_interval = 0, 
@frequency_relative_interval = 0, 
@frequency_recurrence_factor = 0, 
@frequency_subday = 0, 
@frequency_subday_interval = 0, 
@active_start_time_of_day = 0, 
@active_end_time_of_day = 0, 
@active_start_date = 0, 
@active_end_date = 19950101
GO




Run replication agent jobs. Run the following query to get a list of jobs:

SELECT name, date_modified FROM msdb.dbo.sysjobs order by date_modified desc


USE msdb;   
--generate snapshot of publications, for example
EXEC dbo.sp_start_job N'MSSQL-0-Sales-SnapshotRepl-1'
GO

USE msdb;
--distribute the publication to subscriber, for example
EXEC dbo.sp_start_job N'mssql-0-Sales-SnapshotRepl-MSSQL-1-1'
GO



Connect subscriber and query replicated data: 

SELECT * from [SALES].[dbo].[CUSTOMER]

SELECT * FROM [Sales].[dbo].[employee]

SELECT * FROM [Sales].[dbo].[employ]

```



