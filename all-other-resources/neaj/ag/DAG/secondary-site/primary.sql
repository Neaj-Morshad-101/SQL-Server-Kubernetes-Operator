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

DROP certificate dbm_certificate;


SELECT * FROM sys.certificates;



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
sudo chown mssql:mssql /var/opt/mssql/server.*
sudo chown mssql:mssql /var/opt/mssql/root_ca.*
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




USE [master]
GO
SELECT * FROM sys.endpoints 
WHERE name = 'Hadr_endpoint'
GO
SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled;
-- SQL Server Agent status
SELECT * FROM sys.dm_server_services



use [master]
go
CREATE AVAILABILITY GROUP [AG2]
      WITH (CLUSTER_TYPE = NONE)
      FOR REPLICA ON
      N'mssql-remote-0'
            WITH (
            ENDPOINT_URL = N'tcp://mssql-remote-0.mssql-remote-hl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               ),
       N'mssql-remote-1'
            WITH (
            ENDPOINT_URL = N'tcp://mssql-remote-1.mssql-remote-hl:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
               SEEDING_MODE = AUTOMATIC,
               FAILOVER_MODE = MANUAL,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
               );
GO
ALTER AVAILABILITY GROUP [ag2] GRANT CREATE ANY DATABASE;
GO

use [master]
DROP AVAILABILITY GROUP [ag2]



use [master]

SELECT * FROM sys.dm_hadr_availability_replica_states


SELECT * FROM sys.dm_hadr_availability_group_states;


SELECT * FROM sys.availability_groups

SELECT * FROM sys.availability_replicas


use [master]
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
INSERT INTO inventory VALUES (100, 'DAG failover-test-data', 150);
GO
USE agtestdb;
SELECT * FROM inventory;
GO


USE [master]
DROP AVAILABILITY GROUP [ag1];
GO 

DROP DATABASE [agtestdb]
GO






USE agtestdb;
SELECT * FROM inventory;
GO















SELECT * FROM sys.availability_group_listener_ip_addresses;
GO


-- First, remove the existing listener (if any)
ALTER AVAILABILITY GROUP [ag2] REMOVE LISTENER 'ag2-listener';

-- Then, add the listener with the correct syntax
ALTER AVAILABILITY GROUP [ag2]
    ADD LISTENER 'ag2-listener'
    (
        WITH IP (('172.105.44.248', '255.255.0.0')),
        PORT = 1433
    );






use [master]

SELECT * FROM sys.dm_hadr_availability_replica_states






SELECT * FROM sys.availability_replicas














use [master]
ALTER AVAILABILITY GROUP distributedag FORCE_FAILOVER_ALLOW_DATA_LOSS; 








use [master]
ALTER AVAILABILITY GROUP [distributedag] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME








SELECT * FROM sys.availability_group_listener_ip_addresses;
GO