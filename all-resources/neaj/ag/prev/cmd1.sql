select name from sys.databases;
go 

CREATE MASTER KEY ENCRYPTION BY PASSWORD = '12345sS$';
go 

CREATE CERTIFICATE Pod1_Cert
WITH SUBJECT = 'Pod1 AG Certificate';
go

BACKUP CERTIFICATE Pod1_Cert
TO FILE = '/var/opt/mssql/data/Pod1_Cert.cer';
GO

CREATE ENDPOINT AGEP
STATE = STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL)
FOR DATABASE_MIRRORING (
    AUTHENTICATION = CERTIFICATE Pod1_Cert,
    ROLE = ALL);
GO


//run from terminal: 
➤ 
kubectl cp ag/mssql-1:/var/opt/mssql/data/Pod1_Cert.cer /home/neaj/Dropbox/OfficeLife/Projects/mssql/Pod1_Cert.cer
➤ 
kubectl cp /home/neaj/Dropbox/OfficeLife/Projects/mssql/Pod1_Cert.cer ag/mssql-0:/var/opt/mssql/data/Pod1_Cert.cer


sudo chown mssql:mssql Pod0_Cert.cer

CREATE LOGIN Pod0_Login WITH PASSWORD = '12345sS$';
CREATE USER Pod0_User FOR LOGIN Pod0_Login;
GO


CREATE CERTIFICATE Pod0_Cert
AUTHORIZATION Pod0_User
FROM FILE = '/var/opt/mssql/data/Pod0_Cert.cer';
GO



GRANT CONNECT ON ENDPOINT::AGEP TO Pod0_Login;

GO



ALTER AVAILABILITY GROUP [SqlServerAG] JOIN WITH (CLUSTER_TYPE = EXTERNAL);

GO

ALTER AVAILABILITY GROUP [SqlServerAG] GRANT CREATE ANY DATABASE;

GO

