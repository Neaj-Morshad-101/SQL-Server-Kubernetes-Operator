-- ag manual fail over: https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-cross-platform?view=sql-server-ver16
-- docker: https://hasura.io/docs/latest/schema/ms-sql-server/mssql-guides/mssql-read-replicas-docker-setup/

-- Run the following scripts on primary node to setup availability group 



-- test available dbs
SELECT name FROM master.dbo.sysdatabases;
GO 


-- *** Step: A01
-- On the primary replica, create a database login and password.
-- On the primary replica, create a master key and certificate, then back up the certificate with a private key.
-- Create certificate for primary node, store it in a temp location in the node
USE master
GO
CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
go
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
TO FILE = '/tmp/dbm_certificate.cer'
WITH PRIVATE KEY (
      FILE = '/tmp/dbm_certificate.pvk',
      ENCRYPTION BY PASSWORD = 'Password1'
   );
GO

-- *** Step: A02
-- Now, let's copy the certificate from primary and paste them into the secondary nodes.
-- Copy the certificate from the primary node to local system
-- Copy the certificate from local system to secondary nodes
/* 
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp repl-0:/tmp/dbm_certificate.pvk dbm_certificate.pvk
tar: Removing leading `/' from member names
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp repl-0:/tmp/dbm_certificate.cer dbm_certificate.cer
tar: Removing leading `/' from member names
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.cer repl-1:/tmp/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-1:/tmp/dbm_certificate.pvk
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.cer repl-2:/tmp/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-2:/tmp/dbm_certificate.pvk
neaj@appscodespc:~/D/O/P/m/n/a/poc2


kubectl cp dbm_certificate.cer repl-3:/tmp/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-3:/tmp/dbm_certificate.pvk
neaj@appscodespc:~/D/O/P/m/n/a/poc2

kubectl cp dbm_certificate.cer repl-4:/tmp/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-4:/tmp/dbm_certificate.pvk
neaj@appscodespc:~/D/O/P/m/n/a/poc2

sudo docker cp 81d7f91fef6f:/tmp/dbm_certificate.cer dbm_certificate.cer



Set the group and ownership of the private key and the certificate to mssql:mssql.
The following script sets the group and ownership of the files.

sudo chown mssql:mssql /tmp/dbm_certificate.*
check:
ls -l 
*/

SELECT * from sys.certificates;
-- *** Step: B01
/*
Create the endpoint for Always On 
On the primary replica, create an endpoint.
*/
CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];





-- *** Step: C01
/*
Setup health monitoring for the servers
To enable the health monitoring, execute the SQL on all nodes:
*/
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO

-- *** Step: D01
/*
Create Always on Availability Group​
Execute the following SQL on primary node.
*/
CREATE AVAILABILITY GROUP [AG1]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'repl-0'
            WITH (
            ENDPOINT_URL = N'tcp://repl-0.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-1'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-2'
            WITH (
            ENDPOINT_URL = N'tcp://repl-2.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
GO
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO






CREATE AVAILABILITY GROUP [AG1]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'repl-0'
            WITH (
            ENDPOINT_URL = N'tcp://repl-0.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'repl-1'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
GO
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO




CREATE AVAILABILITY GROUP [AG1]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'node_a'
            WITH (
            ENDPOINT_URL = N'tcp://node_a:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'node_b'
            WITH (
            ENDPOINT_URL = N'tcp://node_b:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
      N'node_c'
            WITH (
            ENDPOINT_URL = N'tcp://node_c:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
GO
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO



-- *** Step: E01
-- Setting up the primary node with some values and database
CREATE DATABASE agtestdb;
GO
ALTER DATABASE agtestdb SET RECOVERY FULL;
GO
BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
GO
ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [agtestdb];
GO
USE agtestdb;
GO
CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
GO
-- Add some  data and check it is replicated or not 
INSERT INTO inventory VALUES (1, 'banana', 150); 
INSERT INTO Inventory VALUES (2, 'orange', 154);
GO
-- Add some more data and check it is replicated or not 
INSERT INTO inventory VALUES (3, 'bananannananna', 150);
INSERT INTO Inventory VALUES (4, 'before-fail-over', 154);
GO
-- Add some more data and check it is replicated or not 
USE agtestdb;
GO
INSERT INTO inventory VALUES (6, '$$$$$$$444-test-data', 150);
GO
USE agtestdb;
SELECT * FROM inventory;
GO







-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;






-- Manual Fail-over: 

-- Step: M01
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-0' 
     WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);

ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-1' -- the new primary
     WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
-- check cluster states
select * from sys.dm_hadr_database_replica_cluster_states
go 
select * from sys.availability_groups 
go
--  primary replica and at least one synchronous secondary replica, run the following query:
-- The secondary replica is synchronized when synchronization_state_desc is SYNCHRONIZED.
SELECT ag.name, 
   drs.database_id, 
   drs.group_id, 
   drs.replica_id, 
   drs.synchronization_state_desc, 
   ag.sequence_number
FROM sys.dm_hadr_database_replica_states drs, sys.availability_groups ag
WHERE drs.group_id = ag.group_id;



-- Step: M02
-- Update REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT to 1.
-- The following script sets REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT to 1 
-- on an availability group named ag1
-- This setting ensures that every active transaction is committed to the primary replica 
-- and at least one synchronous secondary replica.
ALTER AVAILABILITY GROUP [ag1] 
     SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 1);


-- Step: M03
-- Set the primary replica and the secondary replica(s) not participating in the failover offline
--  to prepare for the role change:
use master
ALTER AVAILABILITY GROUP [ag1] OFFLINE

DROP AVAILABILITY GROUP [ag1];


-- Step: M06
-- Update the role of the old primary and other secondaries to SECONDARY, 
-- run the following command on the SQL Server instance that hosts the old primary replica:

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 




-- Run this to resume: synchronization: 
-- Not sure is it mandatory here. 
use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME





-- *** Step: D03
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO

-- Step: M09
-- check data is replicating from new primary or not 
USE agtestdb;
SELECT * FROM inventory;
GO
USE agtestdb;
GO
-- try to insert from  this secondary 
INSERT INTO inventory VALUES (8, 'test8', 150);
GO





-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;

















-- Add some more data and check it is replicated or not 
USE agtestdb;
GO
INSERT INTO inventory VALUES (50, 'test50', 150);
GO 5
USE agtestdb;
SELECT * FROM inventory;
GO



-- Fail-over 

-- Run this to resume: synchronization: 
-- Not sure is it mandatory here. 
use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME




-- Step: M01
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-2' 
     WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
-- Step: M01
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-1' 
     WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-0' 
     WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);










-- Not sure is it mandatory here. 
use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME












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














SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_state_desc, 
	drs.synchronization_health_desc
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













SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_state_desc, 
	drs.synchronization_health_desc
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







SELECT * FROM fn_dblog (
              NULL, -- Start LSN nvarchar(25)
              NULL  -- End LSN nvarchar(25)
       )
