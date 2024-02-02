select name from sys.databases;
go

CREATE MASTER KEY ENCRYPTION BY PASSWORD = '12345aA@';
go 

CREATE CERTIFICATE Pod0_Cert
WITH SUBJECT = 'Pod0_Cert AG Certificate';
go

BACKUP CERTIFICATE Pod0_Cert
TO FILE = '/var/opt/mssql/data/Pod0_Cert.cer';
GO

CREATE ENDPOINT AGEP
STATE = STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL)
FOR DATABASE_MIRRORING (
    AUTHENTICATION = CERTIFICATE Pod0_Cert,
    ROLE = ALL);
GO


//run from terminal: 
kubectl cp ag/mssql-0:/var/opt/mssql/data/Pod0_Cert.cer /home/neaj/Dropbox/OfficeLife/Projects/mssql/Pod0_Cert.cer
kubectl cp /home/neaj/Dropbox/OfficeLife/Projects/mssql/Pod0_Cert.cer ag/mssql-1:/var/opt/mssql/data/Pod0_Cert.cer


sudo chown mssql:mssql Pod1_Cert.cer


CREATE LOGIN Pod1_Login WITH PASSWORD = '12345sS$';
CREATE USER Pod1_User FOR LOGIN Pod1_Login;
GO



CREATE CERTIFICATE Pod1_Cert
AUTHORIZATION Pod1_User
FROM FILE = '/var/opt/mssql/data/Pod1_Cert.cer';
GO

GRANT CONNECT ON ENDPOINT::AGEP TO Pod1_Login;
GO


USE [master]
GO
CREATE DATABASE SQLTestAG
GO
USE [SQLTestAG]
GO
CREATE TABLE Customers([CustomerID] int NOT NULL, [CustomerName] varchar(30) NOT NULL)
GO

INSERT INTO Customers (CustomerID, CustomerName) 
VALUES (30,'Petstore CO'),
       (90,'adatum corp'),
       (130,'adventureworks');
GO 

-- Change DB recovery model to Full and take full backup
ALTER DATABASE [SQLTestAG] SET RECOVERY FULL ;
GO
BACKUP DATABASE [SQLTestAG] TO  DISK = N'/var/opt/mssql/backup/SQLTestAG.bak' WITH NOFORMAT, NOINIT,  NAME = N'SQLTestAG-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
USE [master]
GO





CREATE AVAILABILITY GROUP [SqlServerAG]
WITH (
   CLUSTER_TYPE = EXTERNAL
)
FOR DATABASE SQLTestAG
REPLICA ON N'mssql-0'
WITH (
   ENDPOINT_URL = N'msqql-0.ag:5022',
   FAILOVER_MODE = EXTERNAL,
   AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
   PRIMARY_ROLE (ALLOW_CONNECTIONS = READ_WRITE),
   SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
),
N'mssql-1' WITH (
   ENDPOINT_URL = N'mssql-1.ag:5022',
   FAILOVER_MODE = EXTERNAL,
   SEEDING_MODE = AUTOMATIC,
   AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
   PRIMARY_ROLE (ALLOW_CONNECTIONS = READ_WRITE),
   SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
);
GO








SELECT type_desc, port FROM sys.TCP_endpoints  



-- This DMV returns a row for every availability replica of the AlwaysOn availability group.

select * from sys.dm_hadr_availability_replica_cluster_nodes



-- This query confirms the synchronization health of a database on the primary across the secondaries and produces the following output indicating that the primary is replicated to 2 replicas as configured.
SELECT cs.[database_name], 'database_replica', rs.synchronization_health
FROM sys.dm_hadr_database_replica_states rs
join sys.dm_hadr_database_replica_cluster_states cs ON rs.replica_id = cs.replica_id and rs.group_database_id = cs.group_database_id
WHERE rs.is_local = 1



-- This query produces the below output indicating that the AG named K8sAG is replicated to 2 replicas as configured.
SELECT ag.[name], 'availability_group', gs.synchronization_health
FROM sys.dm_hadr_availability_group_states gs
join sys.availability_groups_cluster ag ON gs.group_id = ag.group_id
WHERE gs.primary_replica = 'mssql-primary'

-- We can also query the sys.availability_replicas table for information about the replicas configured

Select replica_server_name, endpoint_url, availability_mode_desc from sys.availability_replicas
replica_server_name	  endpoint_url	              availability_mode_desc
----------------------------------------------------------------------------------------------------------------------
mssql-primary	        tcp://mssql-primary:5022	  SYNCHRONOUS_COMMIT
mssql-secondary1	    tcp://mssql-secondary1:5022	SYNCHRONOUS_COMMIT
mssql-secondary2	    tcp://mssql-secondary2:5022	ASYNCHRONOUS_COMMIT


