
-- query to check available ags
use [master]
SELECT Groups.[Name] AS AGname
FROM sys.dm_hadr_availability_group_states States
INNER JOIN master.sys.availability_groups Groups ON States.group_id = Groups.group_id
WHERE primary_replica = @@Servername;
-- check cluster states
select * from sys.dm_hadr_database_replica_cluster_states
go 


SELECT database_id, synchronization_state_desc, last_hardened_lsn
FROM sys.dm_hadr_database_replica_states;

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






Check Synchronization State:
-- Use the following query to check the synchronization state of the replicas:
SELECT replica_server_name, role_desc, synchronization_state_desc
FROM sys.dm_hadr_database_replica_states;

-- The synchronization_state_desc column will indicate the synchronization state, which can be one of the following:
-- SYNCHRONIZED: The replica is up-to-date.
-- SYNCHRONIZING: The replica is currently synchronizing.




-- Check Synchronization Lag:
-- Use the following query to check the synchronization lag in seconds:
SELECT replica_server_name, synchronization_health_desc, synchronization_lag
FROM sys.dm_hadr_database_replica_states;
-- The synchronization_lag column provides the time difference in seconds between the secondary replica and the primary replica.


-- Check Last Commit Time:
-- You can also check the last commit time to see when the last transaction was committed on each replica:
SELECT replica_server_name, last_commit_time
FROM sys.dm_hadr_database_replica_states;



-- Check Log Send and Redo Queue Size:
-- Another approach is to check the log send and redo queue sizes:
SELECT replica_server_name, log_send_queue_size, redo_queue_size
FROM sys.dm_hadr_database_replica_states;
-- The log_send_queue_size and redo_queue_size columns indicate the number of log records waiting to be sent to the replica and the number of log records waiting to be redone, respectively.


In SQL Server, you can use the sys.dm_hadr_database_replica_states dynamic management view to get information about the commit sequence number (CSN) 
and the commit difference between replicas in an Always On Availability Group.
Here is a query that provides the commit sequence number (log sequence number) information for each replica:
SELECT
    replica_server_name,
    synchronization_health_desc,
    last_commit_time,
    last_commit_lsn
FROM
    sys.dm_hadr_database_replica_states;

-- replica_server_name: The name of the replica.
-- synchronization_health_desc: The health of the synchronization.
-- last_commit_time: The time of the last transaction commit on the replica.
-- last_commit_lsn: The log sequence number (LSN) of the last committed transaction.




-- You can use this information to compare the last_commit_lsn values between replicas. The difference in LSNs represents the commit difference between the replicas. Note that LSNs are unique identifiers for log records, and the gap between LSNs indicates the number of log records or transactions committed on the primary replica but not yet received and committed on the secondary replica.

-- Keep in mind that LSNs are not directly in a human-readable format, so the exact interpretation of the commit difference may require some additional processing. Additionally, understanding the commit difference involves considering the log send and redo process in the Always On Availability Group.

-- If you need more detailed information about the log records and commit differences, you might need to use additional tools or query the transaction log directly, depending on your specific requirements.








-- Remove Database from Availability Group:
-- Another approach is to remove the database from the availability group on the old primary (repl-0):

ALTER DATABASE [YourDatabaseName] SET HADR OFF;


-- Reinitialize the Replica:
-- You can also consider reinitializing the replica (repl-0). This involves reseeding the data from the new primary (repl-1), effectively starting with a fresh copy of the database on the old primary.
ALTER DATABASE [YourDatabaseName] SET HADR OFF;
ALTER DATABASE [YourDatabaseName] SET HADR TO PRIMARY;
-- After reseeding, you would need to add the database back to the availability group.
