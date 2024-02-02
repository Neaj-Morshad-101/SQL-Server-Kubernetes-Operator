select name from sys.databases; 
go


USE [master]
GO

CREATE DATABASE [SQLTestDB]
GO

USE [SQLTestDB]
GO
CREATE TABLE SQLTest (
   ID INT NOT NULL PRIMARY KEY,
   c1 VARCHAR(100) NOT NULL,
   dt1 DATETIME NOT NULL DEFAULT GETDATE()
)
GO

USE [SQLTestDB]
GO

INSERT INTO SQLTest (ID, c1) VALUES (1, 'test1')
INSERT INTO SQLTest (ID, c1) VALUES (2, 'test2')
INSERT INTO SQLTest (ID, c1) VALUES (3, 'test3')
INSERT INTO SQLTest (ID, c1) VALUES (4, 'test4')
INSERT INTO SQLTest (ID, c1) VALUES (5, 'test5')
GO

SELECT * FROM SQLTest
GO





USE SQLTestDB;
GO
BACKUP DATABASE SQLTestDB
TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.bak'
   WITH FORMAT,
      MEDIANAME = 'SQLServerBackups',
      NAME = 'Full Backup of SQLTestDB';
GO


2023-11-24 12:53:43.08 Backup      Database backed up. Database: SQLTestDB, creation date(time): 2023/11/24(12:48:14), pages dumped: 435, first LSN: 39:1000:1, last LSN: 39:1024:1, number of dump devices: 1, device information: (FILE=1, TYPE=DISK, MEDIANAME='SQLServerBackups': {'/var/opt/mssql/data/backups/SQLTestDB.bak'}). This is an informational message only. No user action is required.
2023-11-24 12:53:43.09 Backup      BACKUP DATABASE successfully processed 426 pages in 0.026 seconds (127.854 MB/sec).



BACKUP DATABASE SQLTestDB  
   TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.DIF'
   WITH DIFFERENTIAL;  
GO  



BACKUP LOG SQLTestDB
   TO DISK = '/var/opt/mssql/data/backups/SQLTestDB.trn'
GO






















--- Extra info: 




-- Create a full database backup first.  
BACKUP DATABASE MyAdvWorks   
   TO MyAdvWorks_1   
   WITH INIT;  
GO  
-- Time elapses.  
-- Create a differential database backup, appending the backup  
-- to the backup device containing the full database backup.  
BACKUP DATABASE MyAdvWorks  
   TO MyAdvWorks_1  
   WITH DIFFERENTIAL;  
GO  


BACKUP LOG AdventureWorks2022
   TO MyAdvWorks_FullRM_log1;
GO




-- **When I try to restore after recover:

-- Msg 3117, Level 16, State 1, Line 2
-- The log or differential backup cannot be restored because no files are ready to rollforward.
-- Msg 3013, Level 16, State 1, Line 2
-- RESTORE LOG is terminating abnormally.



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




