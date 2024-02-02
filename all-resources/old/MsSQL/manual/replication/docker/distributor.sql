-- make sure your on the right server
SELECT @@version AS Version
SELECT @@SERVERNAME AS Server_Name

-- step 1, tell this server it is a distributor
EXEC sp_adddistributor @distributor = 'distributor', @password = 'Pa55w0rd!'

-- step 2, create the distribution db
EXEC sp_adddistributiondb @database = 'distribution';

-- step 3, tell the distributor who the publisher is 
-- NOTE! (make the directory '/var/opt/mssql/ReplData', 
-- it doesn't exist and this command will try and verify that it does)
-- docker exec -it distributor bin/bash
-- mkdir /var/opt/mssql/ReplData
-- CTRL+Z get back out
EXEC sp_adddistpublisher @publisher = 'publisher', @distribution_db = 'distribution'

-- let's check the DB
USE distribution;
GO

-- see the repl commands table
SELECT * 
FROM [dbo].[MSrepl_commands]

-- and let's see the jobs we made
SELECT name, date_modified 
FROM msdb.dbo.sysjobs 
ORDER by date_modified desc