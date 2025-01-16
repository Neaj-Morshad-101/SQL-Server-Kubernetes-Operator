```bash
openssl genrsa -out dbm_private_key.pem 3072
openssl req -new -key dbm_private_key.pem -out dbm_csr.pem -subj "/CN=dbm1"
openssl x509 -req -in dbm_csr.pem -signkey dbm_private_key.pem -out dbm_certificate.pem -days 3650

openssl pkcs12 -export -out CERTIFICATE.pfx -inkey dbm_private_key.pem -in dbm_certificate.pem
# this will ask for password. provide a password


```

```bash
kubectl cp CERTIFICATE.pfx repl-0:/var/opt/mssql/certs/CERTIFICATE.pfx 
kubectl cp CERTIFICATE.pfx repl-1:/var/opt/mssql/certs/CERTIFICATE.pfx 
kubectl cp CERTIFICATE.pfx repl-2:/var/opt/mssql/certs/CERTIFICATE.pfx 
```

```SQL
CREATE LOGIN dbm_login WITH PASSWORD = 'LoginPassword';
go

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Master_Key_Password';
GO

create certificate dbm from file = '/var/opt/mssql/certs/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'provide_the_pfx_encryption_password');
go

# this two part is just for practice purpose

# 1. backup password if you want 
BACKUP CERTIFICATE dbm
TO FILE = '/tmp/CERTIFICATE3.pfx'
With format = 'PFX', PRivate key (
    Encryption by password = 'ENCRYPTION_PASSWORD',
    ALGORITHM = 'AES_256'
)
go

# 2. you can create certificate again from that backup certificate
drop certificate dbm;
create certificate dbm from file = '/tmp/CERTIFICATE.pfx' with format = 'PFX', 
private key ( Decryption by password = 'ENCRYPTION_PASSWORD');
go
```