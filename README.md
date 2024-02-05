# MS SQL Server POC resources


## Create and configure sql server availability group on kubernetes: 


### Enable the availability groups feature 
### Enable SQL Server Agent on SQL Server instances: 
We can use the mssql-conf utility like this.
```
sudo /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
```
But we need to restart mssql-server.service to apply these settings. 

We can enable this using environment variables also, We have enabled in the provided statefulset.
```
          - name: MSSQL_AGENT_ENABLED
            value: "True"
          - name: MSSQL_ENABLE_HADR
            value: "1"
```


### Create statefulset and a headless service for communication between availability group replicas

```
kubectl apply -f sts.yaml
```

```
NAME         READY   STATUS    RESTARTS   AGE
pod/repl-0   1/1     Running   0          7m46s
pod/repl-1   1/1     Running   0          6m38s
pod/repl-2   1/1     Running   0          6m31s
```

```
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)             AGE
service/repl         ClusterIP   None         <none>        1433/TCP,5022/TCP   15m
```

### Update the hostname for each host.
(If you face any problem with this)
Each SQL Server hostname must be:
15 characters or less.
Unique within the network.

```
➤ kubectl get pods -owide
NAME     READY   STATUS    RESTARTS   AGE   IP            NODE                 NOMINATED NODE   READINESS GATES
repl-0   1/1     Running   0          20m   10.244.0.30   kind-control-plane   <none>           <none>
repl-1   1/1     Running   0          19m   10.244.0.32   kind-control-plane   <none>           <none>
repl-2   1/1     Running   0          18m   10.244.0.34   kind-control-plane   <none>           <none>
```

update hostname following this: 
```
➤ kubectl exec -it repl-0 -- sh
# nano /etc/hosts

10.244.0.30     repl-0.repl.default.svc.cluster.local   repl-0
10.244.0.32     repl-1
10.244.0.34     repl-2
```

### Install ping and check connectivity between pods
```
kubectl exec -it repl-0 -- sh
# apt-get update -y
# apt-get install -y iputils-ping

# ping repl-1.repl
# ping repl-2.repl 

PING repl-1.repl.default.svc.cluster.local (10.244.0.32) 56(84) bytes of data.
64 bytes from repl-1.repl.default.svc.cluster.local (10.244.0.32): icmp_seq=1 ttl=63 time=0.044 ms
64 bytes from repl-1.repl.default.svc.cluster.local (10.244.0.32): icmp_seq=2 ttl=63 time=0.051 ms
64 bytes from repl-1.repl.default.svc.cluster.local (10.244.0.32): icmp_seq=3 ttl=63 time=0.050 ms
^C
--- repl-1.repl.default.svc.cluster.local ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2045ms


```



### Need to Install mssql extension for Visual Studio Code for easy query execution.
https://learn.microsoft.com/en-us/sql/tools/visual-studio-code/mssql-extensions?view=sql-server-ver16

Port forward to the pod where we want to run query:
```
kubectl port-forward repl-0 1400:1433
```

Create connection profile for pod using following information: 
Server name: 127.0.0.1,1400   
Database name: (Press enter)  
Select: SQL Login  
username: sa   
Password: Pa55w0rd!   
Give profile name: repl-0  

Create a test.sql file and select the part of commands you want to run,    
Right Click -> Execute query -> select profile.


Or We execute query by exec into the pod: 
```
kubectl exec -it repl-0 -- sh
```
then 
```
# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P Pa55w0rd! -No
1> select name from sys.databases
2> go
name                                                                                                                            
--------------
master                                                                                                                          
tempdb                                                                                                                          
model                                                                                                                           
msdb                              

(4 rows affected)

```

We can pass a sql file to cli to execute like this: 

```
/opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P "SA_PASSWORD" -No -i create_AG.sql

```

Remember: Use strong password, at least 8 character and include digit, special chars


### Create the availability group endpoints and certificates on the primary replica
An availability group uses TCP endpoints for communication. Under Linux, endpoints for an AG are only supported if certificates are used for authentication. You must restore the certificate from one instance on all other instances that will participate as replicas in the same AG. The certificate process is required even for a configuration-only replica.

***You can use non-SQL Server-generated certificates as well. You also need a process to manage and replace any certificates that expire.***

https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-create-availability-group?view=sql-server-ver16&tabs=ru#:~:text=An%20availability%20group%20uses,any%20certificates%20that%20expire.


```
-- Create the instance-level login
CREATE LOGIN dbm_login WITH PASSWORD = 'LoginPassword';
GO
-- create a master key for private key encryption
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Master_Key_Password';
GO
-- create certificate
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';

-- backup the certificate with private key
BACKUP CERTIFICATE dbm_certificate
TO FILE = '/tmp/dbm_certificate.cer'
WITH PRIVATE KEY (
      FILE = '/tmp/dbm_certificate.pvk',
      ENCRYPTION BY PASSWORD = 'Private_Key_Password'
   );
GO
```


```
-- create endpoint
CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;

-- Grant login, the permission to connect to the endpoint
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
```



### Copy the certificate and the private key from primary replica to other replicas
```
-- Copy the certificate from the primary node to local system
kubectl cp repl-0:/tmp/dbm_certificate.pvk dbm_certificate.pvk
kubectl cp repl-0:/tmp/dbm_certificate.cer dbm_certificate.cer

-- Copy the certificate from local system to secondary nodes
kubectl cp dbm_certificate.cer repl-1:/tmp/dbm_certificate.cer
kubectl cp dbm_certificate.pvk repl-1:/tmp/dbm_certificate.pvk
kubectl cp dbm_certificate.cer repl-2:/tmp/dbm_certificate.cer
kubectl cp dbm_certificate.pvk repl-2:/tmp/dbm_certificate.pvk
```


```
-- Set the group and ownership of the private key and the certificate to mssql:mssql.
sudo chown mssql:mssql /tmp/dbm_certificate.*
```




## Create the availability group endpoints and certificates on secondary replicas

```
-- Create the instance-level login
CREATE LOGIN dbm_login WITH PASSWORD = 'LoginPassword';
GO
-- create a master key for private key encryption
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Master_Key_Password';
GO

CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Private_Key_Password'
);

-- `Private_Key_Password` must be the same one used in -- ENCRYPTION BY PASSWORD
```

```
-- create endpoint
CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;

-- Grant the login permission to connect to the endpoint
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
```



### Enable an AlwaysOn_health event session to all replicas
```
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
```




### Create Always on Availability Group​ on primary replica

Create the AG. Set CLUSTER_TYPE = NONE. In addition, set each replica with FAILOVER_MODE = MANUAL. Client applications running analytics or reporting workloads can directly connect to the secondary databases. You also can create a read-only routing list. Connections to the primary replica forward read connection requests to each of the secondary replicas from the routing list in a round-robin fashion.

The following Transact-SQL script creates an AG named ag1. The script configures the AG replicas with SEEDING_MODE = AUTOMATIC. This setting causes SQL Server to automatically create the database on each secondary server after it's added to the AG.


```
CREATE AVAILABILITY GROUP [AG1]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'repl-0'
            WITH (
            ENDPOINT_URL = N'tcp://repl-0.repl:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-1'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.repl:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-2'
            WITH (
            ENDPOINT_URL = N'tcp://repl-2.repl:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
GO
```

```
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO
```






### Join Availability Group​ from secondary replicas
```
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
```

```
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO
```





### Create the availability group database on primary
Ensure that the database you add to the availability group is in the full recovery model and has a valid backup

```
CREATE DATABASE agtestdb;
GO
ALTER DATABASE agtestdb SET RECOVERY FULL;
GO
BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
GO
```


```
-- Add the database to the availability group
ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [agtestdb];
GO

```

```
-- insert some test data
USE agtestdb;
GO
CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
GO

-- Add some  data and check it is replicated or not 
INSERT INTO inventory VALUES (1, 'banana', 150); 
INSERT INTO Inventory VALUES (2, 'orange', 154);
GO

USE agtestdb;
SELECT * FROM inventory;
GO
```
```

--- Check the data is replicated in the secondary: connect to the secondary and run

USE agtestdb;
SELECT * FROM inventory;
GO
```



## Fail-over the availability group
```
-- Promote the target secondary replica to primary.
use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 

```





```
--  After failover, secondary databases are suspended, we need change the role and resume synchronization from the new primary. It may need to be done in the secondary replica also.
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME
```

```
-- we need to make the AG offline when the old primary joins back. to change it's role from primary to secondary. (if it wasn't online during fail-over, then  after joining it's role will be primary also)
USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE

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



# Distributed Availability Group: For Remote Replica solution

The process of configuring DAG is almost same as AG configuration. 
Create two cluster in linode and create two AG (check DAG folder)

We have to create Load balancer service for inter cluster communication. 
Add label to primary replica of each AG, for load balancer service.

Look into this doc. 
## configure: 
https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/configure-distributed-availability-groups?view=sql-server-ver16&tabs=automatic

## Resources: 
DAG folder contains all the resource to configure DAG. 


theory:
https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/distributed-availability-groups?view=sql-server-ver16




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