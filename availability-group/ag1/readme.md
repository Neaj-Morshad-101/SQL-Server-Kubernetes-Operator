## Create and Configure Microsoft SQL Server Availability Group cluster on Kubernetes




### Enable the Availability Groups Feature and SQL Server Agent

We can enable features using the mssql-conf utility:
```
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
```
But we need to restart the `mssql-server.service` to apply these settings.

Alternatively, We can enable these features using environment variables, as shown in the provided [StatefulSet](sts.yaml):
```
          - name: MSSQL_AGENT_ENABLED
            value: "True"
          - name: MSSQL_ENABLE_HADR
            value: "1"
```


### Create [StatefulSet and a Headless Service](sts.yaml) for communication between availability group replicas

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
ALTER AVAILABILITY GROUP [ag1]  SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME
```

If old primary was unavailable / offline during the force fail-over:

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







### Add or remove replica in AG
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