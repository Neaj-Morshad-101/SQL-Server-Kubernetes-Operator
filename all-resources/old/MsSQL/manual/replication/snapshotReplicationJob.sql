-- USE msdb;   
-- --generate snapshot of publications, for example
-- EXEC dbo.sp_start_job N'PUB-Sales-SnapshotRepl-1'
-- GO

-- run one at a time 

USE msdb;
--distribute the publication to subscriber, for example
EXEC dbo.sp_start_job N'pub-Sales-SnapshotRepl-SUB-1'
GO

-- pub-Sales-SnapshotRepl-SUB-1

-- PUB-Sales-SnapshotRepl-1