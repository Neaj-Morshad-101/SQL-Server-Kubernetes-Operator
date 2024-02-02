-- https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-replication-tutorial-tsql?view=sql-server-ver16


USE [master]

select name from sys.databases 
go


CREATE DATABASE Sales
GO
USE [SALES]
GO 
CREATE TABLE CUSTOMER([CustomerID] [int] NOT NULL, [SalesAmount] [decimal] NOT NULL)
GO 
INSERT INTO CUSTOMER (CustomerID, SalesAmount) VALUES (1,100),(2,200),(3,300)


USE [SALES]
INSERT INTO CUSTOMER (CustomerID, SalesAmount) VALUES (4,100),(5,200),(6,300)

select * from Customer;



-- Optional: create another table that will be replicated also

CREATE TABLE employee([employeeID] [int] NOT NULL, [SalaryAmount] [decimal] NOT NULL)
GO 
INSERT INTO employee (employeeID, SalaryAmount) VALUES (1,100),(2,200),(3,300)



select * from employee;



-- Optional: create another table that will be replicated also

CREATE TABLE employ([employeeID] [int] NOT NULL, [SalaryAmount] [decimal] NOT NULL)
GO 
INSERT INTO employ (employeeID, SalaryAmount) VALUES (1,100),(2,200),(3,300)



select * from Customer;
select * from employee;
select * from employ;




--

-- Step 03: Create the snapshot folder for SQL Server Agents to read/write to on the distributor, 
-- create the snapshot folder and grant access to 'mssql' user
sudo mkdir /var/opt/mssql/data/ReplData/
sudo chown mssql /var/opt/mssql/data/ReplData/
sudo chgrp mssql /var/opt/mssql/data/ReplData/


--- MOST IMPORTANT ------
-- edit /etc/hosts    in both hosts like this
10.244.0.34     mssql-0.mssql.default.svc.cluster.local mssql-0
10.244.0.35     mssql-1


-- ping to check connectivity
apt-get update && apt-get install -y iputils-ping




-- Step 04: Configure distributor. In this example, the publisher will also be the distributor. Run the following commands on the publisher to configure the instance for distribution as well.
DECLARE @distributor AS sysname
DECLARE @distributorlogin AS sysname
DECLARE @distributorpassword AS sysname
-- Specify the distributor name. Use 'hostname' command on in terminal to find the hostname
SET @distributor = N'mssql-0'--in this example, it will be the name of the publisher
SET @distributorlogin = N'sa'
SET @distributorpassword = N'Pa55w0rd!'
-- Specify the distribution database. 

use master
exec sp_adddistributor @distributor = @distributor -- this should be the hostname

-- Log into distributor and create Distribution Database. In this example, our publisher and distributor is on the same host
exec sp_adddistributiondb @database = N'distribution', @log_file_size = 2, @deletebatchsize_xact = 5000, @deletebatchsize_cmd = 2000, @security_mode = 0, @login = @distributorlogin, @password = @distributorpassword
GO

DECLARE @snapshotdirectory AS nvarchar(500)
SET @snapshotdirectory = N'/var/opt/mssql/data/ReplData/'

-- Log into distributor and create Distribution Database. In this example, our publisher and distributor is on the same host
use [distribution] 
if (not exists (select * from sysobjects where name = 'UIProperties' and type = 'U ')) 
       create table UIProperties(id int) 
if (exists (select * from ::fn_listextendedproperty('SnapshotFolder', 'user', 'dbo', 'table', 'UIProperties', null, null))) 
       EXEC sp_updateextendedproperty N'SnapshotFolder', @snapshotdirectory, 'user', dbo, 'table', 'UIProperties' 
else 
      EXEC sp_addextendedproperty N'SnapshotFolder', @snapshotdirectory, 'user', dbo, 'table', 'UIProperties'
GO





-- Step 05: Configure publisher. Run the following T-SQL commands on the publisher.
DECLARE @publisher AS sysname
DECLARE @distributorlogin AS sysname
DECLARE @distributorpassword AS sysname
-- Specify the distributor name. Use 'hostname' command on in terminal to find the hostname
SET @publisher = N'mssql-0' 
SET @distributorlogin = N'sa'
SET @distributorpassword = N'Pa55w0rd!'
-- Specify the distribution database. 

-- Adding the distribution publishers
exec sp_adddistpublisher @publisher = @publisher, 
@distribution_db = N'distribution', 
@security_mode = 0, 
@login = @distributorlogin, 
@password = @distributorpassword, 
@working_directory = N'/var/opt/mssql/data/ReplData', 
@trusted = N'false', 
@thirdparty_flag = 0, 
@publisher_type = N'MSSQLSERVER'
GO






-- Step 06: Configure publication job. Run the following T-SQL commands on the publisher.
DECLARE @replicationdb AS sysname
DECLARE @publisherlogin AS sysname
DECLARE @publisherpassword AS sysname
SET @replicationdb = N'Sales'
SET @publisherlogin = N'sa'
SET @publisherpassword = N'Pa55w0rd!'

use [Sales]
exec sp_replicationdboption @dbname = N'Sales', @optname = N'publish', @value = N'true'

-- Add the snapshot publication
exec sp_addpublication 
@publication = N'SnapshotRepl', 
@description = N'Snapshot publication of database ''Sales'' from Publisher ''mssql-0''.',
@retention = 0, 
@allow_push = N'true',
@repl_freq = N'snapshot',  --    @repl_freq = N'continuous', *** check it: for always be up to date and replicate changes as they occur, 
@status = N'active', 
@independent_agent = N'true'

exec sp_addpublication_snapshot @publication = N'SnapshotRepl', 
@frequency_type = 1, 
@frequency_interval = 1, 
@frequency_relative_interval = 1, 
@frequency_recurrence_factor = 0, 
@frequency_subday = 8, 
@frequency_subday_interval = 1, 
@active_start_time_of_day = 0,
@active_end_time_of_day = 235959, 
@active_start_date = 0, 
@active_end_date = 0, 
@publisher_security_mode = 0, 
@publisher_login = @publisherlogin, 
@publisher_password = @publisherpassword









-- Step 07: Create articles from the sales table Run the following T-SQL commands on the publisher.
use [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', 
@article = N'customer', 
@source_owner = N'dbo', 
@source_object = N'customer',    -- So only customer t
@type = N'logbased', 
@description = null, 
@creation_script = null, 
@pre_creation_cmd = N'drop', 
@schema_option = 0x000000000803509D,
@identityrangemanagementoption = N'manual', 
@destination_table = N'customer', 
@destination_owner = N'dbo', 
@vertical_partition = N'false'

-- Optional: Adding anothe article for another table.
USE [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', -- Use the existing publication name
@article = N'employee',        -- Set the name of the new article ("employee" in this case)
@source_owner = N'dbo',        -- Source schema (if the "employee" table is in the "dbo" schema)
@source_object = N'employee',  -- Source table name ("employee" in this case)
@type = N'logbased',           -- Type of article (logbased for Transactional Replication)
@description = null,           -- Optional description
@creation_script = null,       -- Optional creation script
@pre_creation_cmd = N'drop',   -- What to do if the article already exists (e.g., drop or keep)
@schema_option = 0x000000000803509D,  -- Schema options
@identityrangemanagementoption = N'manual', -- Identity range management
@destination_table = N'employee',  -- Destination table name at the subscriber
@destination_owner = N'dbo',      -- Destination schema at the subscriber
@vertical_partition = N'false'     -- Replicate the entire table

-- Optional: Adding anothe article for another table.
USE [Sales]
exec sp_addarticle 
@publication = N'SnapshotRepl', -- Use the existing publication name
@article = N'employ',        -- Set the name of the new article ("employee" in this case)
@source_owner = N'dbo',        -- Source schema (if the "employee" table is in the "dbo" schema)
@source_object = N'employ',  -- Source table name ("employee" in this case)
@type = N'logbased',           -- Type of article (logbased for Transactional Replication)
@description = null,           -- Optional description
@creation_script = null,       -- Optional creation script
@pre_creation_cmd = N'drop',   -- What to do if the article already exists (e.g., drop or keep)
@schema_option = 0x000000000803509D,  -- Schema options
@identityrangemanagementoption = N'manual', -- Identity range management
@destination_table = N'employ',  -- Destination table name at the subscriber
@destination_owner = N'dbo',      -- Destination schema at the subscriber
@vertical_partition = N'false'     -- Replicate the entire table










-- Step 08: Configure Subscription. Run the following T-SQL commands on the publisher.
DECLARE @subscriber AS sysname
DECLARE @subscriber_db AS sysname
DECLARE @subscriberLogin AS sysname
DECLARE @subscriberPassword AS sysname
SET @subscriber = N'mssql-1' -- for example, MSSQLSERVER
SET @subscriber_db = N'Sales'
SET @subscriberLogin = N'sa'
SET @subscriberPassword = N'Pa55w0rd!'

use [Sales]
exec sp_addsubscription 
@publication = N'SnapshotRepl', 
@subscriber = @subscriber,
@destination_db = @subscriber_db, 
@subscription_type = N'Push', 
@sync_type = N'automatic', 
@article = N'all', 
@update_mode = N'read only', 
@subscriber_type = 0

exec sp_addpushsubscription_agent 
@publication = N'SnapshotRepl', 
@subscriber = @subscriber,
@subscriber_db = @subscriber_db, 
@subscriber_security_mode = 0, 
@subscriber_login = @subscriberLogin,
@subscriber_password = @subscriberPassword,
@frequency_type = 1,
@frequency_interval = 0, 
@frequency_relative_interval = 0, 
@frequency_recurrence_factor = 0, 
@frequency_subday = 0, 
@frequency_subday_interval = 0, 
@active_start_time_of_day = 0, 
@active_end_time_of_day = 0, 
@active_start_date = 0, 
@active_end_date = 19950101
GO











SELECT name, date_modified FROM msdb.dbo.sysjobs order by date_modified desc


USE msdb;   
--generate snapshot of publications, for example
EXEC dbo.sp_start_job N'MSSQL-0-Sales-SnapshotRepl-1'
GO

USE msdb;
--distribute the publication to subscriber, for example
EXEC dbo.sp_start_job N'mssql-0-Sales-SnapshotRepl-MSSQL-1-1'
GO








SELECT * from [SALES].[dbo].[CUSTOMER]


SELECT * FROM [Sales].[dbo].[employee]



SELECT * FROM [Sales].[dbo].[employ]


