select name from sys.databases; 
go


USE [master]
GO


DROP DATABASE SQLTestDB;
GO 



RESTORE DATABASE SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.bak'
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

RESTORE DATABASE SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.DIF'
    WITH FILE = 1,
    NORECOVERY;



-- 2023-11-24 13:33:07.03 spid77      Starting up database 'SQLTestDB'.
-- 2023-11-24 13:33:07.03 spid77      RemoveStaleDbEntries: Cleanup of stale DB entries called for database ID: [5]
-- 2023-11-24 13:33:07.03 spid77      RemoveStaleDbEntries: Cleanup of stale DB entries skipped because master db is not memory optimized. DbId: 5.
-- 2023-11-24 13:33:07.05 spid77      The database 'SQLTestDB' is marked RESTORING and is in a state that does not allow recovery to be run.
-- 2023-11-24 13:33:07.09 Backup      Database changes were restored. Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), first LSN: 39:1512:1, last LSN: 39:1536:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK: {'/var/opt/mssql/data/backups/SQLTestDB.DIF'}). This is an informational message. No user action is required.
-- 2023-11-24 13:33:07.10 Backup      RESTORE DATABASE successfully processed 282 pages in 0.013 seconds (169.170 MB/sec).



RESTORE DATABASE SQLTestDB WITH RECOVERY;



use [SQLTestDB]
SELECT * FROM SQLTest
GO




use [master]
RESTORE LOG SQLTestDB
    FROM DISK = '/var/opt/mssql/data/backups/SQLTestDB.trn'
    WITH FILE = 1, 
    NORECOVERY;


-- 2023-11-24 14:04:18.33 Backup      RESTORE DATABASE successfully processed 282 pages in 0.011 seconds (199.928 MB/sec).
-- Restore is not incomplete.
-- Restore is not incomplete.
-- 2023-11-24 14:05:20.44 Backup      Log was restored. Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), first LSN: 39:1000:1, last LSN: 39:1552:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK: {'/var/opt/mssql/data/backups/SQLTestDB.trn'}). This is an informational message. No user action is required.





-- **When I try to restore after recover:

-- Msg 3117, Level 16, State 1, Line 2
-- The log or differential backup cannot be restored because no files are ready to rollforward.
-- Msg 3013, Level 16, State 1, Line 2
-- RESTORE LOG is terminating abnormally.

-- *** We have to perform the restore one by one. without recover. 
-- Final stage is the recover stage.








--- We have to recover the database later.
-- first we have to perform restoration of the full backup then -> diff backup -> log backup 

RESTORE DATABASE SQLTestDB WITH RECOVERY;






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






