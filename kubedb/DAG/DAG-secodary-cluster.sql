
-- Secondary Cluster
ALTER AVAILABILITY GROUP [mydag]
   JOIN   
   AVAILABILITY GROUP ON  
      'ag1' WITH    
      (   
         LISTENER_URL = 'tcp://ag1.demo.svc.cluster.local:5022',
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      ),   
      'ag2' WITH    
      (   
         LISTENER_URL = 'tcp://ag2.demo.svc.cluster.local:5022',
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      );  
GO

-- add pod label for primary replica in [ag2]
-- kubectl label pod mssql-remote-1 mssql-ag-remote-primary=true --overwrite


 -- verifies the commit state of the distributed availability group
 select ag.name, ag.is_distributed, ar.replica_server_name, ar.availability_mode_desc, ars.connected_state_desc, ars.role_desc,
 ars.operational_state_desc, ars.synchronization_health_desc from sys.availability_groups ag
 join sys.availability_replicas ar on ag.group_id=ar.group_id
 left join sys.dm_hadr_availability_replica_states ars
 on ars.replica_id=ar.replica_id
 where ag.is_distributed=1
 GO



/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No -Q "
DROP AVAILABILITY GROUP [mydag];
GO"


/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No -Q " select ag.name, ag.is_distributed, ar.replica_server_name, ar.availability_mode_desc, ars.connected_state_desc, ars.role_desc,
 ars.operational_state_desc, ars.synchronization_health_desc from sys.availability_groups ag
 join sys.availability_replicas ar on ag.group_id=ar.group_id
 left join sys.dm_hadr_availability_replica_states ars
 on ars.replica_id=ar.replica_id
 where ag.is_distributed=1
 GO"




-- shows underlying performance of distributed AG
SELECT
   ag.[name] AS [Distributed AG Name],
   ar.replica_server_name AS [Underlying AG],
   dbs.[name] AS [Database],
   ars.role_desc AS [Role],
   drs.synchronization_health_desc AS [Sync Status],
   drs.log_send_queue_size,
   drs.log_send_rate,
   drs.redo_queue_size,
   drs.redo_rate
FROM sys.databases AS dbs
INNER JOIN sys.dm_hadr_database_replica_states AS drs
   ON dbs.database_id = drs.database_id
INNER JOIN sys.availability_groups AS ag
   ON drs.group_id = ag.group_id
INNER JOIN sys.dm_hadr_availability_replica_states AS ars
   ON ars.replica_id = drs.replica_id
INNER JOIN sys.availability_replicas AS ar
   ON ar.replica_id = ars.replica_id
WHERE ag.is_distributed = 1;
GO







-- shows endpoint url and sync state for ag, and dag
SELECT
   ag.name AS group_name,
   ag.is_distributed,
   ar.replica_server_name AS replica_name,
   ar.endpoint_url,
   ar.availability_mode_desc,
   ar.failover_mode_desc,
   ar.primary_role_allow_connections_desc AS allow_connections_primary,
   ar.secondary_role_allow_connections_desc AS allow_connections_secondary,
   ar.seeding_mode_desc AS seeding_mode
FROM sys.availability_replicas AS ar
JOIN sys.availability_groups AS ag
   ON ar.group_id = ag.group_id;
GO






-- displays sync status, send rate, and redo rate of availability groups,
-- including distributed AG
SELECT ag.name AS [AG Name],
    ag.is_distributed,
    ar.replica_server_name AS [AG],
    dbs.name AS [Database],
    ars.role_desc,
    drs.synchronization_health_desc,
    drs.log_send_queue_size,
    drs.log_send_rate,
    drs.redo_queue_size,
    drs.redo_rate,
    drs.suspend_reason_desc,
    drs.last_sent_time,
    drs.last_received_time,
    drs.last_hardened_time,
    drs.last_redone_time,
    drs.last_commit_time,
    drs.secondary_lag_seconds
FROM sys.databases dbs
INNER JOIN sys.dm_hadr_database_replica_states drs
    ON dbs.database_id = drs.database_id
INNER JOIN sys.availability_groups ag
    ON drs.group_id = ag.group_id
INNER JOIN sys.dm_hadr_availability_replica_states ars
    ON ars.replica_id = drs.replica_id
INNER JOIN sys.availability_replicas ar
    ON ar.replica_id = ars.replica_id
--WHERE ag.is_distributed = 1
GO
