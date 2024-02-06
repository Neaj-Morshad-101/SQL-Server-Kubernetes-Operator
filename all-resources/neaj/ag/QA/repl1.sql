SELECT name FROM master.dbo.sysdatabases;
GO 


use [master]
CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
-- ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'Password1';
GO

-- /var/opt/mssql
-- Paste the certificate to secondary first 
CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/var/opt/mssql/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/var/opt/mssql/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Password1'
);



CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];


ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO


-- *** Step: D02
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO



select * from sys.dm_hadr_availability_replica_states


use [master]
SELECT sequence_number from sys.availability_groups 


select name from sys.databases;

-- Database is automatically created on secondary node. we don't have to create the db 
USE agtestdb;
SELECT * FROM inventory;
GO


-- Last LSN 

SELECT SUSER_SNAME();


DECLARE @lastCommitLSN VARCHAR(50);

SELECT TOP 1 @lastCommitLSN = [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT @lastCommitLSN AS LastCommitLSN;




DECLARE @commitLSNs TABLE (LSN VARCHAR(50));

INSERT INTO @commitLSNs (LSN)
SELECT [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT LSN
FROM @commitLSNs;

-- Active LSN's

DECLARE @commitLSNs TABLE (LSN VARCHAR(50));

INSERT INTO @commitLSNs (LSN)
SELECT [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT LSN
FROM @commitLSNs;


select * from sys.dm_hadr_availability_replica_states


select * from sys.dm_hadr_availability_group_states



use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 

ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-0';


ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-0';


select * from sys.dm_hadr_availability_replica_states
select * from sys.dm_hadr_availability_group_states




use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

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







use [agtestdb]
SELECT * FROM inventory;
GO




INSERT INTO inventory VALUES (6, 'TEST6', 150);
GO 



use [master]
select * from sys.dm_hadr_availability_replica_states






SELECT * FROM fn_dblog (
              NULL, -- Start LSN nvarchar(25)
              NULL  -- End LSN nvarchar(25)
       )




SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
    drs.end_of_log_lsn,
	drs.last_sent_lsn, 
	drs.last_received_lsn, 
	drs.last_hardened_lsn, 
	drs.last_commit_lsn
FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_databases_cluster AS adc 
	ON drs.group_id = adc.group_id AND 
	drs.group_database_id = adc.group_database_id
INNER JOIN sys.availability_groups AS ag
	ON ag.group_id = drs.group_id
INNER JOIN sys.availability_replicas AS ar 
	ON drs.group_id = ar.group_id AND 
	drs.replica_id = ar.replica_id