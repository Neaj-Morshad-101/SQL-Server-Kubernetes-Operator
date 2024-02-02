CREATE DATABASE agtestdb;
GO
ALTER DATABASE agtestdb SET RECOVERY FULL;
GO
BACKUP DATABASE agtestdb TO DISK = '/var/opt/mssql/data/agtestdb.bak';
GO

ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [agtestdb];
GO

USE agtestdb;
GO

CREATE TABLE inventory (id INT, name NVARCHAR(50), quantity INT);
GO
INSERT INTO inventory VALUES (1, 'banana', 150); INSERT INTO Inventory VALUES (2, 'orange', 154);
GO