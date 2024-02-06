select name from sys.databases 

use myAgDB

CREATE TABLE Data (ID INT, NAME NVARCHAR(255), AGE INT);
GO
use myAgDB
go
INSERT INTO Data(ID, Name, Age) VALUES                                                                                           
(300, 'Bob Johnson', 22);
GO 300


use myAgDB
GO
select * from data;
go







use [master]
select last_commit_lsn, last_hardened_lsn from sys.dm_hadr_database_replica_states;


use [master]
select * from sys.dm_hadr_availability_replica_states
select * from sys.dm_hadr_database_replica_states


select redo_queue_size from sys.dm_hadr_database_replica_states



USE [master]
ALTER AVAILABILITY GROUP [myag] FORCE_FAILOVER_ALLOW_DATA_LOSS;

USE [master]
ALTER AVAILABILITY GROUP [myag] OFFLINE

use [master]
ALTER AVAILABILITY GROUP [myag] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [myagdb]
     SET HADR RESUME