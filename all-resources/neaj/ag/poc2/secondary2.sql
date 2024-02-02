-- Run the following scripts to secodary node to join with AG primary node 



-- test
SELECT name FROM master.dbo.sysdatabases;
GO 


-- *** Step: A04
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
   AUTHORIZATION dbm_user
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Password1'
);



-- *** Step: B03
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



-- *** Step: C03
/*
Setup health monitoring for the servers
*/
ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO


-- *** Step: D03
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO




-- *** Step: E03
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


-- Step: M04
-- Set the primary replica and the secondary replica(s) not participating in the failover offline
--  to prepare for the role change:
ALTER AVAILABILITY GROUP [ag1] OFFLINE
ALTER AVAILABILITY GROUP [ag1] OFFLINE


-- Step: M07 (maybe optinal)
-- Update the role of the old primary and other secondaries to SECONDARY, 
-- run the following command on the SQL Server instance that hosts the old primary replica:
use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 



-- not sure is it mandatory here... 
USE [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME



-- Step: M10
-- check data is replicating from new primary or not 
USE agtestdb;
SELECT * FROM inventory;
GO
USE agtestdb;
GO
-- try to insert from  this secondary 
INSERT INTO inventory VALUES (8, 'test8', 150);
GO



/*

Forced manual failover with data loss
If the primary replica is not available and can't immediately be recovered, then you need to force a failover to the secondary replica with data loss. However, if the original primary replica recovers after failover, it will assume the primary role. To avoid having each replica be in a different state, remove the original primary from the availability group after a forced failover with data loss. Once the original primary comes back online, remove the availability group from it entirely.

To force a manual failover with data loss from primary replica N1 to secondary replica N2, follow these steps:

On the secondary replica (N2), initiate the forced failover:

ALTER AVAILABILITY GROUP [AGRScale] FORCE_FAILOVER_ALLOW_DATA_LOSS;
On the new primary replica (N2), remove the original primary (N1):

ALTER AVAILABILITY GROUP [AGRScale]
REMOVE REPLICA ON N'N1';
Validate that all application traffic is pointed to the listener and/or the new primary replica.

If the original primary (N1) comes online, immediately take availability group AGRScale offline on the original primary (N1):

ALTER AVAILABILITY GROUP [AGRScale] OFFLINE
If there is data or unsynchronized changes, preserve this data via backups or other data replicating options that suit your business needs.

Next, remove the availability group from the original primary (N1):

DROP AVAILABILITY GROUP [AGRScale];
Drop the availability group database on original primary replica (N1):

USE [master]
GO
DROP DATABASE [AGDBRScale]
GO
(Optional) If desired, you can now add N1 back as a new secondary replica to the availability group AGRScale.

This article reviewed the steps to create a cross-platform AG to support migration or read-scale workloads. It can be used for manual disaster recovery. It also explained how to fail over the AG. A cross-platform AG uses cluster type NONE and doesn't support high availability.


*/



-- For force fail-ove
-- On the secondary replica (N2), initiate the forced failover:
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 
-- On the new primary replica repl-2, remove the original primary repl-1:
ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-1'; -- repl-1 is was primary 

-- Validate that all application traffic is pointed to the listener and/or the new primary replica.


-- If the original (prev) primary (N1) comes online, immediately take availability group ag1 offline on the original (prev) primary (N1):
-- Run this on prev primary: repl-1     ALTER AVAILABILITY GROUP [ag1] OFFLINE



-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;



ALTER AVAILABILITY GROUP [ag1] 
     SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0);



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
      ADD REPLICA ON 
      N'repl-1'
            WITH (
            ENDPOINT_URL = N'tcp://repl-1.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );










-- Add some more data and check it is replicated or not 
USE agtestdb;
GO
INSERT INTO inventory VALUES (500, '2ndForceFail-over', 150);
GO
USE agtestdb;
SELECT * FROM inventory;
GO









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





















ALTER AVAILABILITY GROUP [ag1] OFFLINE
DROP AVAILABILITY GROUP [ag1]

use [master]
DROP DATABASE [agtestdb]




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







SELECT * FROM fn_dblog (
              NULL, -- Start LSN nvarchar(25)
              NULL  -- End LSN nvarchar(25)
       )


use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 



SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
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


SELECT * from sys.dm_hadr_database_replica_states

select * from   sys.availability_replicas
select * from sys.dm_hadr_availability_group_states



ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'node_a';





ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'node_a';



ALTER AVAILABILITY GROUP [ag1]
      ADD REPLICA ON 
      N'node_a'
            WITH (
            ENDPOINT_URL = N'tcp://node_a:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );


use [master]
sp_configure 'show advanced options', 1;  
GO  
RECONFIGURE;  
GO  
sp_configure 'max server memory', 32768;   -- for 32 GB
GO  
RECONFIGURE;  
GO
