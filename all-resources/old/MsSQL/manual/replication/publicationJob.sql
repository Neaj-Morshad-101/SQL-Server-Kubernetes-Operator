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
@description = N'Snapshot publication of database ''Sales'' from Publisher ''pub''.',
@retention = 0, 
@allow_push = N'true', 
@repl_freq = N'snapshot', 
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