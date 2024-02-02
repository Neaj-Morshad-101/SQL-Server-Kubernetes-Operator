CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$tronGest++00';
CREATE CERTIFICATE dbm_certificate
    FROM FILE = '/var/opt/mssql/data/dbm_certificate.cer'
    WITH PRIVATE KEY (
           FILE = '/var/opt/mssql/data/dbm_certificate.pvk',
           DECRYPTION BY PASSWORD = 'W33Kest++00'
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

ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);

ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;