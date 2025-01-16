https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recover-to-a-log-sequence-number-sql-server?view=sql-server-ver16



-- Transact-SQL Syntax for restoring to an LSN
-- By using a RESTORE statement, you can stop at or immediately before the LSN, as follows:

-- Use the WITH STOPATMARK ='lsn:<lsn_number>' clause, where lsn:<lsnNumber> is a string that specifies that the log record that contains the specified LSN is the recovery point.

-- STOPATMARK roll forwards to the LSN and includes that log record in the roll forward.

-- Use the WITH STOPBEFOREMARK ='lsn:<lsn_number>' clause, where lsn:<lsnNumber> is a string that specifies that the log record immediately before the log record that contains the specified LSN number is the recovery point.

-- STOPBEFOREMARK rolls forward to the LSN and excludes that log record from the roll forward.

-- Typically, a specific transaction is selected to be included or excluded. Although not required, in practice, the specified log record is a transaction-commit record.




https://learn.microsoft.com/en-us/answers/questions/1132665/how-reading-the-transaction-log-in-sql-server


https://blog.coeo.com/inside-the-transaction-log-file#:~:text=The%20fn_dblog()%20function%20must,looking%20for%20a%20specific%20transaction.



https://www.sqlskills.com/blogs/paul/using-fn_dblog-fn_dump_dblog-and-restoring-with-stopbeforemark-to-an-lsn/





User
last_hardened_lsn: Represents the log sequence number (LSN) up to which log records have been synchronized.

Can I use this values to check which replica is ahead? 

ChatGPT
Yes, you can use the last_hardened_lsn value to determine the log sequence number (LSN) up to which log records have been synchronized on each replica. The LSN is a unique identifier for a log record, and a higher LSN generally indicates that more transactions have been applied.

Here's how you can interpret the last_hardened_lsn value:

If repl-1 has a higher last_hardened_lsn than repl-2, it indicates that repl-1 is more synchronized and has applied more transactions.

If repl-2 has a higher last_hardened_lsn than repl-1, it indicates that repl-2 is more synchronized and has applied more transactions.

However, keep in mind that the absolute LSN values may not be directly comparable between replicas because LSNs are unique to each database and are not global across the entire SQL Server instance. Therefore, you should compare the last_hardened_lsn values for the same database on different replicas.

For example, you can modify the queries to filter by a specific database ID:

sql
Copy code
-- Check synchronization status for a specific database on repl-1
SELECT
    replica_server_name,
    database_id,
    synchronization_state_desc,
    synchronization_health_desc,
    is_local,
    last_hardened_lsn
FROM
    sys.dm_hadr_database_replica_states
WHERE
    replica_server_name = 'repl-1'
    AND database_id = DB_ID('YourDatabaseName');

-- Check synchronization status for the same database on repl-2
SELECT
    replica_server_name,
    database_id,
    synchronization_state_desc,
    synchronization_health_desc,
    is_local,
    last_hardened_lsn
FROM
    sys.dm_hadr_database_replica_states
WHERE
    replica_server_name = 'repl-2'
    AND database_id = DB_ID('YourDatabaseName');
Replace 'YourDatabaseName' with the actual name of the database you are interested in comparing.

Remember that synchronization health, state, and other factors also contribute to the overall health of the replica, so it's advisable to consider multiple metrics when determining which replica is more synchronized.





https://dba.stackexchange.com/questions/255305/checking-the-data-latency-on-an-always-on-availability-group-in-async-mode

We have a number of SQL Servers with Always on Availability Groups in asynchronous mode between a primary and secondary server with Manual fail over.

I created a latency report utilizing the below query that collects the data every min on each server.

On one of our servers the secondary routinely shows that it has an earlier last_commit_time then the primary.

I verified the server times are the same on both servers.

Why might this be?

Graph showing AVG Daily Latency per database

-- ;WITH 
--         AG_Stats AS 
--                 (
--                 SELECT  AR.replica_server_name,
--                         AG.name as AGName,
--                         HARS.role_desc, 
--                         Db_name(DRS.database_id) [DBName], 
--                         DRS.last_commit_time
--                 FROM   sys.dm_hadr_database_replica_states DRS 
--                 INNER JOIN sys.availability_replicas AR ON DRS.replica_id = AR.replica_id 
--                 INNER JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id 
--                     AND AR.replica_id = HARS.replica_id 
--                 INNER JOIN [sys].[availability_groups] AG on AG.group_id = AR.group_id
--                 ),
--         Pri_CommitTime AS 
--                 (
--                 SELECT  replica_server_name
--                         , AGNAME
--                         , DBName
--                         , last_commit_time
--                 FROM    AG_Stats
--                 WHERE   role_desc = 'PRIMARY'
--                 ),
--         Sec_CommitTime AS 
--                 (
--                 SELECT  replica_server_name
--                         , AGNAME
--                         , DBName
--                         , last_commit_time
--                 FROM    AG_Stats
--                 WHERE   role_desc = 'SECONDARY'
--                 )
--     SELECT p.replica_server_name [primary_replica]
--         , p.AGNAME
--         , p.[DBName] AS [DatabaseName]
--         , s.replica_server_name [secondary_replica]
--         , DATEDIFF(ss,s.last_commit_time,p.last_commit_time) AS [Sync_Latency_Secs]
--     FROM Pri_CommitTime p
--     LEFT JOIN Sec_CommitTime s ON [s].[DBName] = [p].[DBName] and  s.AGNAME = p.AGNAME







    -- ;WITH 
    --     AG_Stats AS 
    --             (
    --             SELECT  AR.replica_server_name,
    --                     AG.name as AGName,
    --                     HARS.role_desc, 
    --                     Db_name(DRS.database_id) [DBName], 
    --                     DRS.last_commit_time
    --             FROM   sys.dm_hadr_database_replica_states DRS 
    --             INNER JOIN sys.availability_replicas AR ON DRS.replica_id = AR.replica_id 
    --             INNER JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id 
    --                 AND AR.replica_id = HARS.replica_id 
    --             INNER JOIN [sys].[availability_groups] AG on AG.group_id = AR.group_id

    --             ),
    --     Pri_CommitTime AS 
    --             (
    --             SELECT  replica_server_name
    --                     , AGNAME
    --                     , DBName
    --                     , last_commit_time
    --             FROM    AG_Stats
    --             WHERE   role_desc = 'PRIMARY'
    --             ),
    --     Sec_CommitTime AS 
    --             (
    --             SELECT  replica_server_name
    --                     , AGNAME
    --                     , DBName
    --                     , last_commit_time
    --             FROM    AG_Stats
    --             WHERE   role_desc = 'SECONDARY'
    --             )
    -- SELECT p.replica_server_name [primary_replica]
    --     , p.AGNAME
    --     , p.[DBName] AS [DatabaseName]
    --     , s.replica_server_name [secondary_replica]
    --     , CASE 
    --             WHEN s.last_commit_time >= p.last_commit_time THEN DATEDIFF(ss,s.last_commit_time,p.last_commit_time) 
    --             ELSE DATEDIFF(ss,p.last_commit_time,GETDATE()) 
    --       END AS [Sync_Latency_Secs]
    -- FROM Pri_CommitTime p
    -- LEFT JOIN Sec_CommitTime s ON [s].[DBName] = [p].[DBName] and  s.AGNAME = p.AGNAME 




 availability databases full info
 availability status full info check 





https://sqlperformance.com/2015/08/monitoring/availability-group-replica-sync

*** 
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

-- By querying the DMVs directly on the primary replica, it is easy to get up to date information without waiting for the refresh period of the dashboard in Management Studio. 

https://learn.microsoft.com/en-us/previous-versions/sql/sql-server-2012/ff878356(v=sql.110)?redirectedfrom=MSDN


***SQLServer:Database Replica performance object
https://learn.microsoft.com/en-us/previous-versions/sql/sql-server-2012/ff878356(v=sql.110)?redirectedfrom=MSDN



https://learn.microsoft.com/en-us/previous-versions/sql/sql-server-2012/ff878472(v=sql.110)
https://learn.microsoft.com/en-us/previous-versions/sql/sql-server-2012/ms189883(v=sql.110)


Log Send Queue	Amount of log records in the log files of the primary database, in kilobytes, that has not yet been sent to the secondary replica. This value is sent to the secondary replica from the primary replica. Queue size does not include FILESTREAM files that are sent to a secondary.





-- sequence_number in availability_groups: How Pacemaker promote a replica
-- https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-ha?view=sql-server-ver16




Understand SQL Server resource agent for Pacemaker
SQL Server 2017 (14.x) introduced sequence_number to sys.availability_groups to show if a replica marked as SYNCHRONOUS_COMMIT was up to date. sequence_number is a monotonically increasing BIGINT that represents how up-to-date the local availability group replica is with respect to the rest of the replicas in the availability group. Performing failovers, adding or removing replicas, and other availability group operations update this number. The number is updated on the primary, then pushed to secondary replicas. Thus a secondary replica that is up-to-date has the same sequence_number as the primary.

When Pacemaker decides to promote a replica to primary, it first sends a notification to all replicas to extract the sequence number and store it (this notification is called the pre-promote notification). Next, when Pacemaker tries to promote a replica to primary, the replica only promotes itself if its sequence number is the highest of all the sequence numbers from all replicas, otherwise it rejects the promote operation. In this way only the replica with the highest sequence number can be promoted to primary, ensuring no data loss.

Promotion is only guaranteed to work as long as at least one replica available for promotion has the same sequence number as the previous primary. The default behavior is for the Pacemaker resource agent to automatically set REQUIRED_COPIES_TO_COMMIT such that at least one synchronous commit secondary replica is up to date and available, to be the target of an automatic failover. With each monitoring action, the value of REQUIRED_COPIES_TO_COMMIT is computed (and updated if necessary) as ('number of synchronous commit replicas' / 2). Then, at failover time, the resource agent requires (total number of replicas - required_copies_to_commit replicas) to respond to the pre-promote notification to be able to promote one of them to primary. The replica with the highest sequence_number is promoted to primary.

For example, let's consider the case of an availability group with three synchronous replicas - one primary replica and two synchronous commit secondary replicas.

REQUIRED_COPIES_TO_COMMIT is 3 / 2 = 1

The required number of replicas to respond to pre-promote action is 3 - 1 = 2. So two replicas have to be up for the failover to be triggered. When a primary outage occurs, if one of the secondary replicas is unresponsive and only one of the secondaries responds to the pre-promote action, the resource agent can't guarantee that the secondary that responded has the highest sequence_number, and a failover isn't triggered.

A user can choose to override the default behavior, and configure the availability group resource to not set REQUIRED_COPIES_TO_COMMIT automatically as shown previously.

 Important

When REQUIRED_COPIES_TO_COMMIT is 0 there's risk of data loss. In the case of an outage of the primary, the resource agent will not automatically trigger a failover. The user has to decide if they want to wait for primary to recover or manually fail over.

To set REQUIRED_COPIES_TO_COMMIT to 0, run:

sudo pcs resource update <ag_cluster> required_copies_to_commit=0
The equivalent command using crm (on SLES) is:

sudo crm resource param <ag_cluster> set required_synchronized_secondaries_to_commit 0
To revert to default computed value, run:

sudo pcs resource update <ag_cluster> required_copies_to_commit=


-- Updating resource properties causes all replicas to stop and restart. This means primary will temporarily be demoted to secondary, then promoted again which will cause temporary write unavailability. The new value for REQUIRED_COPIES_TO_COMMIT will only be set once replicas are restarted, so it won't be instantaneous with running the pcs command.

	


    
-- sys.dm_db_log_info (Transact-SQL)
-- https://github.com/MicrosoftDocs/sql-docs/blob/live/docs/relational-databases/system-dynamic-management-views/sys-dm-db-log-info-transact-sql.md