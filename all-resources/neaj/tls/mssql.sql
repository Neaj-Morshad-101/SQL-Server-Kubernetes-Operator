create certificate dbm from file = '/var/opt/mssql/certs/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'provide_the_pfx_encryption_password');
go


create certificate dbm_pfx from file = '/var/opt/mssql/certs/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'Pa55w0rd!');
go

select * from sys.certificates 

drop certificate dbm_pfx;

BACKUP CERTIFICATE dbm_pfx
TO FILE = '/tmp/CERTIFICATE.pfx'
With format = 'PFX', PRivate key (
    Encryption by password = 'Pa55w0rd!',
    ALGORITHM = 'AES_256'
)
go


drop certificate dbm_pfx;
create certificate dbm_pfx from file = '/tmp/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'Pa55w0rd!');
go

select * from sys.endpoints 

drop endpoint Hadr_pfx

CREATE ENDPOINT [Hadr_pfx]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_pfx,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [Hadr_pfx] STATE = STARTED;

-- Grant the login permission to connect to the endpoint
GRANT CONNECT ON ENDPOINT::[Hadr_pfx] TO [dbm_login];




-- # this two part is just for practice purpose

-- # 1. backup password if you want 
BACKUP CERTIFICATE dbm_restore
TO FILE = '/tmp/CERTIFICATE3.pfx'
With format = 'PFX', PRivate key (
    Encryption by password = 'ENCRYPTION_PASSWORD',
    ALGORITHM = 'AES_256'
)
go

-- # 2. you can create certificate again from that backup certificate
drop certificate dbm_custom_pfx;
create certificate dbm_pfx from file = '/tmp/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'Pa55w0rd!');
go





-- root ca 
create certificate dbm_root from file = '/var/opt/mssql/certs/root_ca.pfx' with format = 'PFX', 
private key ( Decryption by password = 'Pa55w0rd!');
go

select * from sys.certificates 

drop certificate dbm_root;

BACKUP CERTIFICATE dbm_root
TO FILE = '/tmp/root_ca.pfx'
With format = 'PFX', PRivate key (
    Encryption by password = 'Pa55w0rd!',
    ALGORITHM = 'AES_256'
)
go


drop certificate dbm_root;
create certificate dbm_root from file = '/tmp/root_ca.pfx' with format = 'PFX', 
private key ( Decryption by password = 'Pa55w0rd!');
go

select * from sys.endpoints 

drop endpoint dbm_root

CREATE ENDPOINT [dbm_root]
   AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
   FOR DATA_MIRRORING (
      ROLE = ALL,
      AUTHENTICATION = CERTIFICATE dbm_root,
      ENCRYPTION = REQUIRED ALGORITHM AES
      );
ALTER ENDPOINT [dbm_root] STATE = STARTED;


CREATE CERTIFICATE dbm_certificate
   FROM FILE = '/tmp/dbm_certificate.cer'
   WITH PRIVATE KEY (
   FILE = '/tmp/dbm_certificate.pvk',
   DECRYPTION BY PASSWORD = 'Private_Key_Password'
);


-- wrong query 
USE master; 
CREATE CERTIFICATE dbm_root 
    FROM FILE = '/tmp/root_ca.pfx'
    WITH PRIVATE KEY ( 
    FILE = '/tmp/root_ca.pfx'
);




CREATE CERTIFICATE Shipping04
    FROM FILE = 'c:\storedcerts\shipping04cert.pfx'
    WITH 
    FORMAT = 'PFX', 
	PRIVATE KEY (
        DECRYPTION BY PASSWORD = '9n34khUbhk$w4ecJH5gh'
	);  