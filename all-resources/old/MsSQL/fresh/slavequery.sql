CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'hello++00A';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           DECRYPTION BY PASSWORD = 'hello++00B'
        );


CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;


ALTER AVAILABILITY GROUP [ag2] JOIN WITH (CLUSTER_TYPE = NONE);

ALTER AVAILABILITY GROUP [ag2] GRANT CREATE ANY DATABASE;