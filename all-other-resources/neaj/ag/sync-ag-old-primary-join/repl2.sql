
use [master]
select name from sys.databases;
go
----- New setup: 

SELECT * FROM sys.dm_server_services

SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled;



USE master
GO
CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
go
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
TO FILE = '/var/opt/mssql/dbm_certificate.cer'
WITH PRIVATE KEY (
      FILE = '/var/opt/mssql/dbm_certificate.pvk',
      ENCRYPTION BY PASSWORD = 'Password1'
   );
GO

-- path change: /var/opt/mssql


-- copy these to all secondary replicas
-- change permission

-- *** Step: A02
-- Now, let's copy the certificate from primary and paste them into the secondary nodes.
-- Copy the certificate from the primary node to local system
-- Copy the certificate from local system to secondary nodes


/* 
neaj@appscodespc:~/D/O/P/m/n/a/poc2

kubectl cp repl-2:/var/opt/mssql/dbm_certificate.pvk dbm_certificate.pvk
kubectl cp repl-2:/var/opt/mssql/dbm_certificate.cer dbm_certificate.cer


tar: Removing leading `/' from member names
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.cer repl-1:/var/opt/mssql/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-1:/var/opt/mssql/dbm_certificate.pvk
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.cer repl-0:/var/opt/mssql/dbm_certificate.cer
neaj@appscodespc:~/D/O/P/m/n/a/poc2
kubectl cp dbm_certificate.pvk repl-0:/var/opt/mssql/dbm_certificate.pvk
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

sudo chown mssql:mssql /var/opt/mssql/dbm_certificate.*
check:
ls -l 
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



ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO













use [master]
go
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




-- *** Step: E01
-- Setting up the primary node with some values and database
CREATE DATABASE agtestdb;
GO
ALTER DATABASE agtestdb SET RECOVERY FULL;
GO
BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
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
INSERT INTO inventory VALUES (3, 'initial phase', 150);
USE agtestdb
INSERT INTO Inventory VALUES (4, 'first changes before fail-over', 154);
GO
-- Add some more data and check it is replicated or not 
USE agtestdb;
GO
INSERT INTO inventory VALUES (16, 'sync test', 150);
GO



USE agtestdb;
SELECT * from inventory;


use [master]
ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [agtestdb];
GO

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 1);


SELECT * FROM sys.dm_hadr_availability_replica_states

SELECT * FROM sys.dm_hadr_availability_group_states;

SELECT * FROM sys.dm_hadr_database_replica_cluster_states;

SELECT * FROM sys.dm_hadr_database_replica_states; 

SELECT * FROM sys.availability_databases_cluster

SELECT * FROM sys.availability_replicas;

SELECT * FROM sys.availability_groups


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



USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE


use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME






USE agtestdb;
SELECT * FROM inventory;
GO





use [master]
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO


USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE
DROP AVAILABILITY GROUP [ag1];



USE [master]
GO
DROP DATABASE [agtestdb]
GO



-- after backup restore a db, join it by running this commad:
-- 
USE [master]
ALTER DATABASE [agtestdb] SET HADR AVAILABILITY GROUP = [ag1]
GO




use [master]
ALTER AVAILABILITY GROUP [ag1] FORCE_FAILOVER_ALLOW_DATA_LOSS;

