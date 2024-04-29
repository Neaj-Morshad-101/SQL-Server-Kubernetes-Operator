-- Run the following scripts to secodary node to join with AG primary node 

-- test
SELECT name FROM master.dbo.sysdatabases;
GO 


-- *** Step: A03
/* 
On the secondary replica, create a database login and password and create a master key.
On the secondary replica, restore the certificate you copied to /tmp/.
Connect to all the secondary nodes and execute the following SQL:
*/
CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
-- ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'Password1';
GO
-- Paste the certificate to secondary first 
CREATE CERTIFICATE dbm_certificate
--    AUTHORIZATION dbm_user
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Password1'
);


-- *** Step: B02
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




-- *** Step: C02
/*
Setup health monitoring for the servers
*/
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO


use master
go

-- *** Step: D02
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO





-- *** Step: E02
SELECT name FROM master.dbo.sysdatabases;
GO

USE agtestdb;
SELECT * FROM inventory;
GO
-- try to insert from secondary
USE agtestdb;
GO
INSERT INTO inventory VALUES (5, 'test5', 150);
GO






-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;

-- Step: M05
-- Promote the target secondary replica to primary.

use master
go
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 




-- Step: M07 
-- Resume data movement, run the following command for every database in the availability group 
-- on the SQL Server instance that hosts the primary replica:
use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME


use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 


/* Optional : Re-create any listener you created for read-scale purposes and that isn't managed by a cluster manager. If the original listener points to the old primary, drop it and re-create it to point to the new primary.
*/


-- Step: M08 
-- check data is replicating from new primary or not 
USE agtestdb;
SELECT * FROM inventory;
GO
USE agtestdb;
GO
INSERT INTO inventory VALUES (3, 'test=7', 777);
GO

use [agtestdb]
INSERT INTO inventory VALUES (700, 'test=7', 777);
GO 5
USE agtestdb;
GO
INSERT INTO inventory VALUES (8, 'test8', 150);
GO















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











SELECT * FROM fn_dblog (
              NULL, -- Start LSN nvarchar(25)
              NULL  -- End LSN nvarchar(25)
       )






use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 
















-- For force failover: make this offline  
-- Run this on prev primary: repl-1
ALTER AVAILABILITY GROUP [ag1] OFFLINE
DROP AVAILABILITY GROUP [ag1];
USE [master]
GO
DROP DATABASE [agtestdb]
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
GO
USE agtestdb;
SELECT * FROM inventory;
GO


















-- Step: M05
-- Promote the target secondary replica to primary.
use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 


use [master]USE agtestdb;
SELECT * FROM inventory;
GO
ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-2';



-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;
-- check cluster states
select * from sys.dm_hadr_database_replica_cluster_states
go 
-- check cluster states
select * from sys.dm_hadr_availability_replica_cluster_nodes
go 
select * from sys.dm_hadr_availability_replica_states
select * from sys.availability_groups_cluster
select * from sys.availability_groups 
select * from sys.dm_hadr_availability_group_states
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




ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-2';


ALTER AVAILABILITY GROUP [ag1]
      ADD REPLICA ON 
      N'repl-2'
            WITH (
            ENDPOINT_URL = N'tcp://repl-2.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );



