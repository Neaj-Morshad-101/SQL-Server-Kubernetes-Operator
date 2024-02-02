CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa55w0rd!';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           DECRYPTION BY PASSWORD = 'Pa55w0rd!2'
        );

-- DROP ENDPOINT Hadr_endpoint;

CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;



ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);

ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
