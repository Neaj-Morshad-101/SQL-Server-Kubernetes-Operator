CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$tronGest++00';
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
   TO FILE = '/var/opt/mssql/data/dbm_certificate.cer'
   WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           ENCRYPTION BY PASSWORD = 'W33Kest++00'
        );

CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = 1433)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;


---

CREATE AVAILABILITY GROUP [ag1]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
        N'node_a' WITH (
            ENDPOINT_URL = N'tcp://node_a:1433',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            FAILOVER_MODE = MANUAL,
            SEEDING_MODE = AUTOMATIC,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            ),
        N'node_b' WITH ( 
            ENDPOINT_URL = N'tcp://node_b:1433', 
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            FAILOVER_MODE = MANUAL,
            SEEDING_MODE = AUTOMATIC,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            );

ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;


CREATE DATABASE [db1];
ALTER DATABASE [db1] SET RECOVERY FULL;
BACKUP DATABASE [db1]
   TO DISK = N'/var/opt/mssql/data/db1.bak';



ALTER AVAILABILITY GROUP [ag1] ADD DATABASE [db1];


SELECT * FROM sys.databases WHERE name = 'db1';
GO
SELECT DB_NAME(database_id) AS 'database', synchronization_state_desc FROM sys.dm_hadr_database_replica_states;


SELECT * FROM sys.availability_groups;