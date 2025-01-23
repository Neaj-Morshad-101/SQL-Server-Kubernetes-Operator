-- General SQL Server Commands:
cat /var/opt/mssql/mssql.conf
mssql running?
ps aux | grep -v grep | grep -c sqlservr
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No
/opt/mssql-tools18/bin/sqlcmd -S ${host},${port} -U ${username} -P ${password} -d ${database}
-- with TLS:
sqlcmd -S ${host},${port} -U ${username} -P ${password} -d ${database} -N
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P JzbyIXY6i5Wa4TSi -Q SHUTDOWN -No

------------------- Check availability group status --------------------
------------------------ Dynamic Management Views ------------------------------
SELECT * FROM sys.dm_hadr_availability_replica_states
SELECT * FROM sys.dm_hadr_availability_group_states;
SELECT * FROM sys.dm_hadr_database_replica_cluster_states;
SELECT * FROM sys.dm_hadr_database_replica_states;
SELECT * FROM sys.availability_databases_cluster
SELECT * FROM sys.availability_replicas;
SELECT * FROM sys.availability_groups

Status:
SELECT replica_server_name FROM sys.availability_replicas;
select database_name from sys.availability_databases_cluster;
SELECT synchronization_health_desc from sys.dm_hadr_availability_group_states
SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
SELECT synchronization_health_desc from sys.dm_hadr_availability_replica_states WHERE is_local = 1
SELECT name FROM sys.availability_groups
SELECT required_synchronized_secondaries_to_commit FROM sys.availability_groups WHERE name = 'mssqlag';

-- Config Change:
ALTER AVAILABILITY GROUP [mssqlagcluster] OFFLINE
ALTER AVAILABILITY GROUP [mssqlagcluster] SET (ROLE = SECONDARY);
ALTER AVAILABILITY GROUP mssqlagcluster SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0);

-- AG Database:
ALTER DATABASE [agdb1] SET HADR RESUME;
ALTER DATABASE [agdb2] SET HADR RESUME;
ALTER DATABASE [agdb1] SET HADR OFF;
DROP DATABASE [agdb1];

-- AG Replica Related:
Join:
ALTER AVAILABILITY GROUP [mssqlagcluster] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [mssqlagcluster] GRANT CREATE ANY DATABASE;

-- Add/Remove:
USE [master]
ALTER AVAILABILITY GROUP [mssqlagcluster]
	ADD REPLICA ON N'mssql-ag-cluster-1'WITH (
	ENDPOINT_URL = N'tcp://mssql-ag-cluster-1.mssql-ag-cluster-pods.demo.svc:5022',
	AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC, FAILOVER_MODE = MANUAL,
	SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL));
USE [master]
ALTER AVAILABILITY GROUP [mssqlagcluster] REMOVE REPLICA ON N'mssql-ag-0';

-- AG Create/Delete:
DROP AVAILABILITY GROUP [mssqlagcluster];

-- ALTERS:
ALTER LOGIN sa WITH PASSWORD = 'Pa55w0rd'

-- Status:
SELECT physical_memory_kb / 1024 AS physical_memory_mb FROM sys.dm_os_sys_info;
SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID;
SELECT default_language_name FROM sys.server_principals WHERE name = 'sa';  -- or your specific login name

SELECT SERVERPROPERTY('IsSingleUser')
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';

-- For Testing:
SELECT name FROM sys.databases
GO
CREATE DATABASE test;
GO
CREATE TABLE Data (ID INT, NAME NVARCHAR(255), AGE INT);
INSERT INTO Data(ID, Name, Age) VALUES (1, 'John Doe', 25), (2, 'Jane Smith', 30);
GO
SELECT * from data
go
INSERT INTO Data(ID, Name, Age) VALUES (3, 'John Doe', 25);
first fail-over:
INSERT INTO Data(ID, Name, Age) VALUES (4, 'John Doe', 25);
2nd fail-over:
INSERT INTO Data(ID, Name, Age) VALUES (5, 'John Doe', 25);
INSERT INTO Data(ID, Name, Age) VALUES (6, 'John Doe', 25);

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