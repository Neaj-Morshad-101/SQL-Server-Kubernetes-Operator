SELECT name from sys.databases;

use [master]
DROP DATABASE agtestdb;


-- Assuming you have already created the 'testdb2' database
-- If not, you can create it using: CREATE DATABASE testdb2;

USE master;
RESTORE DATABASE agtestdb FROM DISK = '/var/opt/mssql/data/agtestdb.bak'
WITH MOVE 'agtestdb' TO '/var/opt/mssql/data/agtestdb.mdf',
MOVE 'agtestdb_log' TO '/var/opt/mssql/data/agtestdb_log.ldf',
REPLACE;



USE master;
SELECT * FROM sys.dm_exec_sessions WHERE database_id = DB_ID('agtestdb');

-- db still in use problem: made it to single user mode
USE master;
ALTER DATABASE agtestdb SET SINGLE_USER WITH ROLLBACK IMMEDIATE;


--perform the backup 
USE master;
RESTORE DATABASE agtestdb FROM DISK = '/var/opt/mssql/data/agtestdb.bak'
WITH MOVE 'agtestdb' TO '/var/opt/mssql/data/agtestdb.mdf',
MOVE 'agtestdb_log' TO '/var/opt/mssql/data/agtestdb_log.ldf',
REPLACE;



USE master;
ALTER DATABASE agtestdb SET MULTI_USER;


use [agtestdb]
SELECT * FROM inventory;
GO

SELECT name, state_desc FROM sys.databases WHERE name = 'agtestdb';

USE agtestdb;
SELECT * FROM information_schema.tables WHERE table_name = 'inventory';








CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
-- ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'Password1';
GO
-- Paste the certificate to secondary first 
CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
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


use [master]
SELECT sequence_number from sys.availability_groups 



select * from sys.dm_hadr_availability_replica_states


use agtestdb
select * from inventory;



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






ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

ALTER DATABASE [agtestdb]
     SET HADR RESUME





select * from sys.dm_hadr_availability_replica_states
select * from sys.dm_hadr_availability_group_states


use [agtestdb]
SELECT * FROM inventory;
GO




use [master]
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 



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
INSERT INTO inventory VALUES (7, 'after failover to repl-2', 150);
GO 


use [master]

ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-2' 
     WITH (AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT);

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-1' 
     WITH (AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT);



use [master]
ALTER AVAILABILITY GROUP [ag1] 
     MODIFY REPLICA ON N'repl-0' 
     WITH (AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT);







use [master]
ALTER AVAILABILITY GROUP [ag1]
REMOVE REPLICA ON N'repl-0';


use [master]
ALTER AVAILABILITY GROUP [ag1]
      ADD REPLICA ON 
      N'repl-0'
            WITH (
            ENDPOINT_URL = N'tcp://repl-0.repl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );










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
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO


select name from sys.databases;

use [master]
SELECT sequence_number from sys.availability_groups 


-- *** Step: E01
-- Setting up the primary node with some values and database
CREATE DATABASE agtestdb;
GO
ALTER DATABASE agtestdb SET RECOVERY FULL;
GO
BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
GO
use  [master]
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
GO 
INSERT INTO Inventory VALUES (4, 'orangernagfe', 154);
GO
-- Add some more data and check it is replicated or not 
USE agtestdb;
GO
INSERT INTO inventory VALUES (5, 'beforeFail-over to repl-2', 150);
GO 


INSERT INTO inventory VALUES (6, 'testdata2', 160);
GO 

USE [agtestdb];
SELECT * FROM inventory;
GO









