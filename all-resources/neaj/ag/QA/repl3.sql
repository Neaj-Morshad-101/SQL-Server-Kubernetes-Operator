CREATE LOGIN dbm_login WITH PASSWORD = 'Password1';
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Password1';
-- ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'Password1';
GO
-- Paste the certificate to secondary first 
CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
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



use [master]
SELECT sequence_number from sys.availability_groups 

use [agtestdb]
select * from inventory;



DECLARE @lastCommitLSN VARCHAR(50);

SELECT TOP 1 @lastCommitLSN = [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT @lastCommitLSN AS LastCommitLSN;



DECLARE @commitLSNs TABLE (LSN VARCHAR(50));

INSERT INTO @commitLSNs (LSN)
SELECT [Current LSN]
FROM fn_dblog(NULL, NULL)
WHERE Operation = 'LOP_COMMIT_XACT'
ORDER BY [Current LSN] DESC;

SELECT LSN
FROM @commitLSNs;




ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

ALTER DATABASE [agtestdb]
     SET HADR RESUME



use [agtestdb]
SELECT * FROM inventory;
GO