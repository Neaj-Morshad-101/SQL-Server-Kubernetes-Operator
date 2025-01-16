
CREATE LOGIN node0_Login WITH PASSWORD = 'hello++00A';
CREATE USER node0_User FOR LOGIN node0_Login;
GO

CREATE CERTIFICATE dbm_certificate0
AUTHORIZATION node0_User
FROM FILE = '/var/opt/mssql/data/dbm_certificate0.cer';
GO


GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO node0_Login;


ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);

