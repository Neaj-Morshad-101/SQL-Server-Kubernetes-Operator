CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'hello++00A';
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
   TO FILE = '/var/opt/mssql/data/dbm_certificate.cer'
   WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           ENCRYPTION BY PASSWORD = 'hello++00B'
        );


CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;


CREATE AVAILABILITY GROUP [ag2]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
    N'node0' WITH (
       ENDPOINT_URL = N'tcp://node0:5022',
       AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
       FAILOVER_MODE = MANUAL,
       SEEDING_MODE = AUTOMATIC,
       SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    ),
    N'node1' WITH ( 
       ENDPOINT_URL = N'tcp://node1:5022', 
       AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
       FAILOVER_MODE = MANUAL,
       SEEDING_MODE = AUTOMATIC,
       SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    );

ALTER AVAILABILITY GROUP [ag2] GRANT CREATE ANY DATABASE;


select * from sys.dm_hadr_availability_replica_cluster_nodes


