SELECT name from sys.databases
GO

USE AgDB1
GO
CREATE TABLE Data (ID INT, NAME NVARCHAR(255), AGE INT);
INSERT INTO Data(ID, Name, Age) VALUES (1, 'John Doe', 25), (2, 'Jane Smith', 30);                                                                                    
GO 

SELECT * from data;
go



use [master]
ALTER AVAILABILITY GROUP [ag] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [AgDB1]
     SET HADR RESUME

-- AgDB1
-- AgDB2




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


SELECT role_desc FROM sys.dm_hadr_availability_replica_states WHERE replica_id = (SELECT replica_id FROM sys.availability_replicas WHERE replica_server_name = 'ag-custom-0')


SELECT role_desc FROM sys.dm_hadr_availability_replica_states



ALTER AVAILABILITY GROUP ag FORCE_FAILOVER_ALLOW_DATA_LOSS; 






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








SELECT role_desc FROM sys.dm_hadr_availability_replica_states WHERE replica_id = (SELECT replica_id FROM sys.availability_replicas WHERE replica_server_name = 'ag-custom-0')


select database_name from sys.availability_databases_cluster