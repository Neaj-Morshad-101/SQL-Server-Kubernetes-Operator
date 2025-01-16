SELECT * FROM sys.databases; 

create DATABASE TestDB;


use [TestDB]

-- redo_start_lsn
Select redo_start_lsn from sys.master_files where database_id=DB_ID('TestDB') and type_desc = 'LOG'




SELECT
    [Current LSN],
    [Operation],
    [Context],
    [Transaction ID],
    [Description]
FROM
    fn_dblog (NULL, NULL),
    (SELECT
        [Transaction ID] AS [tid]
    FROM
        fn_dblog (NULL, NULL)
    WHERE
        [Transaction Name] LIKE '%DROP%') [fd]
WHERE
    [Transaction ID] = [fd].[tid];
GO






SELECT SUSER_SNAME();





DECLARE @lastCommitLSN VARCHAR(50);

SELECT TOP 1 @lastCommitLSN = [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT @lastCommitLSN AS LastCommitLSN;





DECLARE @commitLSNs TABLE (LSN VARCHAR(50));

INSERT INTO @commitLSNs (LSN)
SELECT [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT LSN
FROM @commitLSNs;











-- Backup Restore:


USE TestDB;
GO
CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
GO
-- Add some  data and check it is replicated or not 
INSERT INTO inventory VALUES (1, 'banana', 150); 
INSERT INTO Inventory VALUES (2, 'orange', 154);
GO
-- Add some more data and check it is replicated or not 
INSERT INTO inventory VALUES (3, 'bananannananna', 150);
INSERT INTO Inventory VALUES (4, 'orangernagfe', 154);
GO

INSERT INTO inventory VALUES (5, 'test5', 150);
INSERT INTO inventory VALUES (6, 'lastColumnOfTestdbBackedUp', 150);
GO
USE TestDB;
SELECT * FROM inventory;
GO




alter database TestDB 
    SET RECOVERY FULL;


use [master]
BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/data/TestDB.bak';


create DATABASE testdb2;

SELECT name from sys.databases;

use [testdb2]
SELECT * FROM inventory;
GO




-- Assuming you have already created the 'testdb2' database
-- If not, you can create it using: CREATE DATABASE testdb2;

USE master;
RESTORE DATABASE testdb2 FROM DISK = '/var/opt/mssql/data/TestDB.bak'
WITH MOVE 'TestDB' TO '/var/opt/mssql/data/testdb2.mdf',
MOVE 'TestDB_log' TO '/var/opt/mssql/data/testdb2_log.ldf',
REPLACE;



USE master;
SELECT * FROM sys.dm_exec_sessions WHERE database_id = DB_ID('testdb2');

-- db still in use problem: made it to single user mode
USE master;
ALTER DATABASE testdb2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;


--perform the backup 
USE master;
RESTORE DATABASE testdb2 FROM DISK = '/var/opt/mssql/data/TestDB.bak'
WITH MOVE 'TestDB' TO '/var/opt/mssql/data/testdb2.mdf',
MOVE 'TestDB_log' TO '/var/opt/mssql/data/testdb2_log.ldf',
REPLACE;


USE master;
ALTER DATABASE testdb2 SET MULTI_USER;


use [testdb2]
SELECT * FROM inventory;
GO



use [TestDB]
INSERT INTO inventory VALUES (8, 'diffbackuptest2', 150);




USE master;
BACKUP DATABASE TestDB TO DISK = '/var/opt/mssql/data/TestDB_Differential.bak' WITH DIFFERENTIAL





USE master;
RESTORE DATABASE testdb2 FROM DISK = '/var/opt/mssql/data/TestDB_Differential.bak'
WITH MOVE 'TestDB' TO '/var/opt/mssql/data/testdb2.mdf',
MOVE 'TestDB_log' TO '/var/opt/mssql/data/testdb2_log.ldf',
REPLACE;



USE master;
ALTER DATABASE testdb2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;


--working... 


USE master;
ALTER DATABASE testdb2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

USE master;
RESTORE DATABASE testdb2 FROM DISK = '/var/opt/mssql/data/TestDB_Differential.bak'
WITH MOVE 'TestDB' TO '/var/opt/mssql/data/testdb2.mdf',
MOVE 'TestDB_log' TO '/var/opt/mssql/data/testdb2_log.ldf',
REPLACE;

USE master;
ALTER DATABASE testdb2 SET MULTI_USER;

SELECT * FROM fn_dblog(NULL,NULL)

USE master;
SELECT * FROM sys.databases WHERE name = 'testdb2';


-- differential backup restore is not working don't know why. 
-- Need to try again.


-- https://www.sqlskills.com/blogs/paul/using-fn_dblog-fn_dump_dblog-and-restoring-with-stopbeforemark-to-an-lsn/





-- sys.fn_dblog which reads from the active portion of the transaction log.
-- sys.fn_dump_dblog which reads from the transaction log backups.




-- 1> SELECT name FROM sys.databases; 
-- 2> go
-- name                                                                                                                            
-- --------------------------------------------------------------------------------------------------------------------------------
-- master                                                                                                                          
-- tempdb                                                                                                                          
-- model                                                                                                                           
-- msdb                                                                                                                            

-- (4 rows affected)
-- 1> create DATABASE TestDB;
-- 2> go
-- 1> 
-- 2> USE TestDB;
-- 3> go
-- Changed database context to 'TestDB'.
-- 1> CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
-- 2> go
-- 1> INSERT INTO inventory VALUES (1, 'banana', 150); 
-- 2> INSERT INTO Inventory VALUES (2, 'orange', 154);
-- 3> go

-- (1 rows affected)

-- (1 rows affected)
-- 1> DECLARE @lastCommitLSN VARCHAR(50);
-- 2> SELECT TOP 1 @lastCommitLSN = [Current LSN]
-- 3> FROM fn_dblog(NULL, NULL)
-- 4> WHERE Operation = 'LOP_COMMIT_XACT'
-- 5> ORDER BY [Current LSN] DESC;
-- 6> SELECT @lastCommitLSN AS LastCommitLSN;
-- 7> go
-- LastCommitLSN                                     
-- --------------------------------------------------
-- 00000027:00000093:0003                            

-- (1 rows affected)
-- 1> select * from inventory
-- 2> go
-- id          name                                               quantity   
-- ----------- -------------------------------------------------- -----------
--           1 banana                                                     150
--           2 orange                                                     154

-- (2 rows affected)
-- 1> INSERT INTO inventory VALUES (3, 'bananannananna', 150);
-- 2> INSERT INTO Inventory VALUES (4, 'orangernagfe', 154);
-- 3> go

-- (1 rows affected)

-- (1 rows affected)
-- 1> select * from inventory
-- 2> gop
-- 3> go
-- id          name                                               quantity   
-- ----------- -------------------------------------------------- -----------
--           1 banana                                                     150
--           2 orange                                                     154
--           3 bananannananna                                             150
--           4 orangernagfe                                               154

-- (4 rows affected)
-- 1> DECLARE @commitLSNs TABLE (LSN VARCHAR(50));
-- 2> INSERT INTO @commitLSNs (LSN)
-- 3> SELECT [Current LSN]
-- 4> FROM fn_dblog(NULL, NULL)
-- 5> WHERE Operation = 'LOP_COMMIT_XACT'
-- 6> ORDER BY [Current LSN] DESC;
-- 7> SELECT LSN
-- 8> FROM @commitLSNs;
-- 9> go

-- (21 rows affected)
-- LSN                                               
-- --------------------------------------------------
-- 00000027:0000001A:0004                            
-- 00000027:0000001A:004C                            
-- 00000027:0000007E:0001                            
-- 00000027:0000007F:0026                            
-- 00000027:00000088:0011                            
-- 00000027:00000088:001B                            
-- 00000027:00000088:001D                            
-- 00000027:0000008D:0001                            
-- 00000027:0000008E:0010                            
-- 00000027:0000008E:001A                            
-- 00000027:0000008E:001D                            
-- 00000027:00000093:0003                            
-- 00000027:00000094:000F                            
-- 00000027:00000094:0016                            
-- 00000027:00000094:0020                            
-- 00000027:00000094:0030                            
-- 00000027:00000094:003A                            
-- 00000027:00000094:003C                            
-- 00000027:0000009E:0001                            
-- 00000027:0000009F:0003                            
-- 00000027:000000A0:0003                            

-- (21 rows affected)
