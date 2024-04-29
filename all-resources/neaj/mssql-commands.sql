---------------------------------- CREATE -------------------------------------

CREATE CERTIFICATE Shipping04   
   ENCRYPTION BY PASSWORD = 'pGFD4bb925DGvbd2439587y'  
   WITH SUBJECT = 'Sammamish Shipping Records',   
   EXPIRY_DATE = '20201031';  
GO 


CREATE CERTIFICATE Shipping11   
    FROM FILE = 'c:\Shipping\Certs\Shipping11.cer'   
    WITH PRIVATE KEY (FILE = 'c:\Shipping\Certs\Shipping11.pvk',   
    DECRYPTION BY PASSWORD = 'sldkflk34et6gs%53#v00');  
GO   

-------------------------------- SELECT / GET ----------------------------------- 


/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!"

select name from sys.databases



SELECT name FROM master.dbo.sysdatabases;
GO 

SELECT * FROM sys.certificates;

SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled;

SELECT name, protocol_desc, port, state_desc FROM sys.tcp_endpoints
WHERE type_desc = 'DATABASE_MIRRORING'

SELECT * FROM sys.endpoints 
WHERE name = 'Hadr_endpoint'

SELECT * FROM sys.dm_exec_connections




/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!"

SELECT name FROM sys.databases
GO

CREATE DATABASE std;
GO


USE std
GO
CREATE TABLE Data (ID INT, NAME NVARCHAR(255), AGE INT);
INSERT INTO Data(ID, Name, Age) VALUES (1, 'John Doe', 25), (2, 'Jane Smith', 30);                                                                                    
GO 

SELECT * from data;
go



USE AgDB1
GO
INSERT INTO Data(ID, Name, Age) VALUES (3, 'John Doe', 25), (4, 'Jane Smith', 30);                                                                                    
GO 



USE AgDB1
GO
INSERT INTO Data(ID, Name, Age) VALUES (5, 'John Doe', 25), (6, 'Jane Smith', 30);                                                                                    
GO 

SELECT role_desc FROM sys.dm_hadr_availability_replica_states WHERE replica_id = (SELECT replica_id FROM sys.availability_replicas WHERE replica_server_name = 'ag-custom-0')




use [master]
ALTER AVAILABILITY GROUP [agcustom] 
SET (ROLE = SECONDARY); 






------------------------ Dynamic Management Views ------------------------------

SELECT sequence_number FROM sys.availability_groups

-- last commit lsn 
SELECT * FROM sys.dm_hadr_database_replica_states;

SELECT last_commit_lsn FROM sys.dm_hadr_database_replica_states;

select database_name from sys.availability_databases_cluster

/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!"


SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_health_desc, 
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
ORDER BY 
	ag.name, 
	ar.replica_server_name, 
	adc.database_name;





SELECT * FROM sys.dm_hadr_availability_replica_states

SELECT * FROM sys.dm_hadr_availability_group_states;

SELECT * FROM sys.dm_hadr_database_replica_cluster_states;

SELECT * FROM sys.dm_hadr_database_replica_states; 

SELECT * FROM sys.availability_databases_cluster

SELECT * FROM sys.availability_replicas;

SELECT * FROM sys.availability_groups


-- LOGS
SELECT * FROM sys.dm_tran_active_transactions

-- SQL Server Agent status
SELECT * FROM sys.dm_server_services

-- AGUSE [master]
SELECT sequence_number FROM sys.availability_groups 

SELECT * FROM sys.dm_hadr_availability_replica_states

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



--seeding
sys.dm_hadr_automatic_seeding
sys.dm_hadr_physical_seeding_stats








------------------------- ALTER / MODIFY ---------------------------------- 

ALTER AVAILABILITY GROUP [<AGName>] 
    GRANT CREATE ANY DATABASE
GO

ALTER AVAILABILITY GROUP [AGName]
  MODIFY REPLICA ON 'Replica_Name'
  WITH (SEEDING_MODE = AUTOMATIC)
--To disable automatic seeding,USE a value of MANUAL.


-- Add an existing database to the availability group.  
ALTER AVAILABILITY GROUP MyAG ADD DATABASE MyDb3;  
GO  


ALTER AVAILABILITY GROUP [AGName] 
    DENY CREATE ANY DATABASE
GO



USE [master]
ALTER AVAILABILITY GROUP [ag1] FORCE_FAILOVER_ALLOW_DATA_LOSS;

USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME

-- after backup restore a db, join it by running this commad: 
-- we have to first join the ag with manual seeding 
-- This step actually creates the linkage between the AG on the secondary replica and the database it owns. without this step, the synchronization cannot be initialized.
-- It should be executed after the last log backup has restored on the secondary replica and the database has joined to the availability group on the primary replica.
-- Therefore, either execute it right after restoring the last log backup was taken or temporarily stop your LOG backup job during this time. 
-- Otherwise, you might find yourself chasing the (log) tail. 
ALTER DATABASE [agtestdb] SET HADR AVAILABILITY GROUP = [ag1]
GO



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

ALTER AVAILABILITY GROUP AG2   
   ADD REPLICA ON   
      'COMPUTER03\HADR_INSTANCE' WITH   
         (  
         ENDPOINT_URL = 'TCP://COMPUTER03:7022',  
         PRIMARY_ROLE ( ALLOW_CONNECTIONS = READ_WRITE ),  
         SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY )  
         );   
GO  








----------------------- DELETE / REMOVE ---------------------------------

-- AG 
USE [master]
DROP AVAILABILITY GROUP [ag1];