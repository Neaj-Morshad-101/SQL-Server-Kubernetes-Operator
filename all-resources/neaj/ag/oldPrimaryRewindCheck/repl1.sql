SELECT name FROM master.dbo.sysdatabases;
GO 


use [master]
CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
-- ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'Password1';
GO

-- /var/opt/mssql
-- Paste the certificate to secondary first 
CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/var/opt/mssql/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/var/opt/mssql/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Password1'
);



CREATE ENDPOINT [Hadr_endpoint]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_certificate,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];


ALTER EVENT SESSION  AlwaysOn_health ON SERVER WITH (STARTUP_STATE=ON);
GO


-- *** Step: D02
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
GO





USE agtestdb;
SELECT * FROM inventory;
GO




-- AG 
USE [master]
DROP AVAILABILITY GROUP [ag1];

use [master]
DROP DATABASE agtestdb;