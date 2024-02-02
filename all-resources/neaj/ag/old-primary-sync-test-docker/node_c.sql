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



use [master]
DROP DATABASE agtestdb;
go



USE agtestdb;
SELECT * FROM inventory;
GO




use [master]
SELECT sequence_number from sys.availability_groups 



select * from sys.availability_groups;
go



select * from sys.dm_hadr_availability_replica_states



SELECT * FROM sys.dm_tran_active_transactions




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





use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME




SELECT state_desc FROM sys.databases WHERE name = 'agtestdb';
SELECT * FROM sys.dm_hadr_availability_replica_cluster_states;









use [master]
DROP AVAILABILITY GROUP [ag1];



use [master]

ALTER AVAILABILITY GROUP [ag1] OFFLINE


use [master]
DROP AVAILABILITY GROUP [ag1];





use [master]
drop database agtestdb
go





















RESTORE DATABASE agtestdb
    FROM DISK = '/var/opt/mssql/data/backups/agtestdb.bak'
    WITH FILE = 1,
    NORECOVERY;

-- 2023-11-24 13:04:00.43 spid77      The database 'SQLTestDB' is marked RESTORING and is in a state that does not allow recovery to be run.
-- 2023-11-24 13:04:00.47 Backup      Database was restored: Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), first LSN: 39:1000:1, last LSN: 39:1024:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK, MEDIANAME='SQLServerBackups': {'/var/opt/mssql/data/backups/SQLTestDB.bak'}). Informational message. No user action required.
-- 2023-11-24 13:04:00.49 Backup      RESTORE DATABASE successfully processed 426 pages in 0.014 seconds (237.444 MB/sec).


use [SQLTestDB]
SELECT * FROM SQLTest
GO
-- Database 'SQLTestDB' cannot be opened. It is in the middle of a restore.


RESTORE DATABASE SQLTestDB WITH RECOVERY;


use [SQLTestDB]
SELECT * FROM SQLTest
GO







SELECT * FROM fn_dblog (
              NULL, -- Start LSN nvarchar(25)
              NULL  -- End LSN nvarchar(25)
       )






-- restoring diff backup 


use [master]

RESTORE DATABASE agtestdb
    FROM DISK = '/var/opt/mssql/data/backups/agtestdb.DIF'
    WITH FILE = 1,
    NORECOVERY;



-- 2023-11-24 13:33:07.03 spid77      Starting up database 'SQLTestDB'.
-- 2023-11-24 13:33:07.03 spid77      RemoveStaleDbEntries: Cleanup of stale DB entries called for database ID: [5]
-- 2023-11-24 13:33:07.03 spid77      RemoveStaleDbEntries: Cleanup of stale DB entries skipped because master db is not memory optimized. DbId: 5.
-- 2023-11-24 13:33:07.05 spid77      The database 'SQLTestDB' is marked RESTORING and is in a state that does not allow recovery to be run.
-- 2023-11-24 13:33:07.09 Backup      Database changes were restored. Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), first LSN: 39:1512:1, last LSN: 39:1536:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK: {'/var/opt/mssql/data/backups/SQLTestDB.DIF'}). This is an informational message. No user action is required.
-- 2023-11-24 13:33:07.10 Backup      RESTORE DATABASE successfully processed 282 pages in 0.013 seconds (169.170 MB/sec).


use [master]
RESTORE DATABASE agtestdb WITH RECOVERY;



use [agtestdb]
SELECT * FROM inventory;
GO




use [master]
RESTORE LOG agtestdb
    FROM DISK = '/var/opt/mssql/data/backups/agtestdb.trn'
    WITH FILE = 1, 
    NORECOVERY;


-- 2023-11-24 14:04:18.33 Backup      RESTORE DATABASE successfully processed 282 pages in 0.011 seconds (199.928 MB/sec).
-- Restore is not incomplete.
-- Restore is not incomplete.
-- 2023-11-24 14:05:20.44 Backup      Log was restored. Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), first LSN: 39:1000:1, last LSN: 39:1552:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK: {'/var/opt/mssql/data/backups/SQLTestDB.trn'}). This is an informational message. No user action is required.





use [master]
RESTORE LOG agtestdb
    FROM DISK = '/var/opt/mssql/data/backups/agtestdb.trn'
    WITH FILE = 2, 
    NORECOVERY;



-- (We have all the data now,  with 1000:New data)









-- **When I try to restore after recover:

-- Msg 3117, Level 16, State 1, Line 2
-- The log or differential backup cannot be restored because no files are ready to rollforward.
-- Msg 3013, Level 16, State 1, Line 2
-- RESTORE LOG is terminating abnormally.

-- *** We have to perform the restore one by one. without recover. 
-- Final stage is the recover stage.








--- We have to recover the database later.
-- first we have to perform restoration of the full backup then -> diff backup -> log backup 

RESTORE DATABASE agtestdb WITH RECOVERY;






-- *****Conclusion: we can take backup anytime; 
-- but when we try to restore from backup; 
-- we have to restore a full backup -> diff backup -> log backup: 
-- We can't just restore a log backup: 

-- LSN value of backup and restore seems keep same on the backup and restore replica: 








-- Extra information: Not used in the process.


RESTORE DATABASE AdventureWorks2022
    FROM AdventureWorksBackups
    WITH FILE = 3, NORECOVERY;

RESTORE LOG AdventureWorks2022
    FROM AdventureWorksBackups
    WITH FILE = 4, NORECOVERY, STOPAT = 'Apr 15, 2020 12:00 AM';

RESTORE LOG AdventureWorks2022
    FROM AdventureWorksBackups
    WITH FILE = 5, NORECOVERY, STOPAT = 'Apr 15, 2020 12:00 AM';
RESTORE DATABASE AdventureWorks2022 WITH RECOVERY;




use [master]
ALTER DATABASE agtestdb SET RECOVERY FULL;





use [master]
go
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
use [master]
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO








use [master]
ALTER DATABASE agtestdb SET HADR AVAILABILITY GROUP = ag1;  
GO
      