-- /var/opt/mssql
-- Paste the certificate to secondary first 
CREATE CERTIFICATE server_certificate
   FROM FILE = '/var/opt/mssql/server.cer'
   WITH PRIVATE KEY (
   FILE = '/var/opt/mssql/server.key'
);


CREATE CERTIFICATE server_certificate
FROM FILE = '/var/opt/mssql/root_ca.crt'
WITH PRIVATE KEY (FILE = '/var/opt/mssql/root_ca.key');



USE master;  
CREATE CERTIFICATE HOST_A_cert   
   WITH SUBJECT = 'HOST_A certificate for database mirroring',   
   EXPIRY_DATE = '11/30/2013';  
GO  

-- Syntax for SQL Server and Azure SQL Database  
  
CREATE CERTIFICATE certificate_name [ AUTHORIZATION user_name ]   
    { FROM <existing_keys> | <generate_new_keys> }  
    [ ACTIVE FOR BEGIN_DIALOG = { ON | OFF } ]  
  
<existing_keys> ::=   
    ASSEMBLY assembly_name  
    | {   
        [ EXECUTABLE ] FILE = 'path_to_file'  
        [ WITH [FORMAT = 'PFX',]
          PRIVATE KEY ( <private_key_options> ) ]   
      }  
    | {   
        BINARY = asn_encoded_certificate  
        [ WITH PRIVATE KEY ( <private_key_options> ) ]  
      }  
<generate_new_keys> ::=   
    [ ENCRYPTION BY PASSWORD = 'password' ]   
    WITH SUBJECT = 'certificate_subject_name'   
    [ , <date_options> [ ,...n ] ]   
  
<private_key_options> ::=  
      {   
        FILE = 'path_to_private_key'  
         [ , DECRYPTION BY PASSWORD = 'password' ]  
         [ , ENCRYPTION BY PASSWORD = 'password' ]    
      }  
    |  
      {   
        BINARY = private_key_bits  
         [ , DECRYPTION BY PASSWORD = 'password' ]  
         [ , ENCRYPTION BY PASSWORD = 'password' ]    
      }  
  
<date_options> ::=  
    START_DATE = 'datetime' | EXPIRY_DATE = 'datetime'  