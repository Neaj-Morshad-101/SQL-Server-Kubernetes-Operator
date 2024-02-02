# MS SQL Server POC related resources


## Create and configure an availability group for SQL Server: 


### Enable the availability groups feature and enable SQL Server Agent on SQL Server instances
```
/opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
/opt/mssql/bin/mssql-conf set sqlagent.enabled true
```



### Create the availability group endpoints and certificates on the primary replica

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

-- Grant the login permission to connect to the endpoint
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



### Enable an AlwaysOn_health event session to all replcas
```
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO
```




### Create Always on Availability Group​ on primary replica
```
CREATE AVAILABILITY GROUP [AG1]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'repl-0'
            WITH (
            ENDPOINT_URL = N'tcp://repl-0.demo-service:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-1'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.demo-service:5022',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-2'
            WITH (
            ENDPOINT_URL = N'tcp://repl-2.demo-service:5022',
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






## Fail-over the availability group
```
-- Promote the target secondary replica to primary.
use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 

```





```
--  After failover, secondary databases is suspended, we need change the role and resume synchronization from the new primary
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME
```

```
-- we need to keep the AG offline when the old primary joins back to change it's role from primary to secondary
USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE
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
            ENDPOINT_URL = N'tcp://repl-1.demo-service:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
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




## Publisher Subcriber model

```



-- https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-replication-tutorial-tsql?view=sql-server-ver16


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





SELECT name, date_modified FROM msdb.dbo.sysjobs order by date_modified desc


USE msdb;   
--generate snapshot of publications, for example
EXEC dbo.sp_start_job N'MSSQL-0-Sales-SnapshotRepl-1'
GO

USE msdb;
--distribute the publication to subscriber, for example
EXEC dbo.sp_start_job N'mssql-0-Sales-SnapshotRepl-MSSQL-1-1'
GO





SELECT * from [SALES].[dbo].[CUSTOMER]


SELECT * FROM [Sales].[dbo].[employee]



SELECT * FROM [Sales].[dbo].[employ]

```