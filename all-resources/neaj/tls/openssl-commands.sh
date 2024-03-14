--Certificates 

--convert to der format
openssl x509 -in custom.cer -out mycustom.cer -outform DER
openssl rsa -inform pem -in custom.pvk -outform der -out mycustom.pvk
openssl rsa -in custom.pvk -outform der -out mycustom.pvk

-- generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout custom.pvk -out custom.cer -subj "/CN=RootCA/O=KubeDB"
openssl req -x509 -nodes -days 365 -newkey rsa:3072 -keyout custom.pvk -out custom.cer -subj "/CN=dbm"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout root_ca.key -out root_ca.crt -subj "/CN=RootCA/O=KubeDB"
openssl req -x509 -nodes -days 365 -newkey rsa:3072 -keyout root_ca.pvk -out root_ca.cer -subj "/CN=dbm"

-- generate server cert from root_ca
openssl req -new -nodes -newkey rsa:2048 -keyout server.key -out server.csr -subj "/CN=MsSQL/O=KubeDB"
openssl req -new -nodes -newkey rsa:3072 -keyout server.pvk -out server.csr -subj "/CN=dbm"
openssl x509 -req -in server.csr -CA root_ca.crt -CAkey root_ca.key -CAcreateserial -out server.cer -days 365
openssl x509 -req -in server.csr -CA root_ca.cer -CAkey root_ca.pvk -CAcreateserial -out server.cer -days 365

-- openssl x509 -in dbm_certificate.cer -inform DER -text

-- convert to pkcs12 / pfx 
openssl pkcs12 -export -out root_ca.pfx -inkey root_ca.key -in root_ca.crt


-- view file contents
openssl x509 -in root_ca.crt -text
openssl rsa -in root_ca.key -text
openssl rsa -in hostcn.pvk -text -noout




openssl req -x509 -nodes -days 365 -newkey rsa:3072 -keyout root_ca.pvk -out root_ca.cer -subj "/CN=dbm"
openssl pkcs12 -export -out root_ca.pfx -inkey root_ca.pvk -in root_ca.cer
