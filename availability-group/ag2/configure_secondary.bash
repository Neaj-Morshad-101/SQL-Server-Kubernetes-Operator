#!/usr/bin/env bash
set -euo pipefail

# Constants
NAMESPACE="demo"
POD_PREFIX="ag1"
POD_COUNT=2        # ag1-1 and ag1-2
CERT_NAME="dbm_certificate"
AG_NAME="ag1"
PASSWORD="${MSSQL_SA_PASSWORD:-Pa55w0rd!}"

echo "🔄 Configuring secondary replicas and joining them to Availability Group '${AG_NAME}'..."

for i in $(seq 1 $((POD_COUNT))); do
  POD_NAME="${POD_PREFIX}-${i}"

  echo "⚙️  Configuring SQL objects on $POD_NAME..."
  kubectl exec -n "$NAMESPACE" -i "$POD_NAME" -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -Q "
    CREATE LOGIN dbm_login WITH PASSWORD = '$PASSWORD';
    GO
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$PASSWORD';
    GO
    CREATE CERTIFICATE ${CERT_NAME}
      FROM FILE = '/var/opt/mssql/${CERT_NAME}.cer'
      WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/${CERT_NAME}.pvk',
        DECRYPTION BY PASSWORD = 'Pa55w0rd!'
      );
    GO
    CREATE ENDPOINT [Hadr_endpoint]
      AS TCP (
        LISTENER_IP = (0.0.0.0),
        LISTENER_PORT = 5022
      )
      FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE ${CERT_NAME},
        ENCRYPTION = REQUIRED ALGORITHM AES
      );
    GO
    ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
    GO
    GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];
    GO
    ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
    GO
  "

  echo "🔗 Joining $POD_NAME to Availability Group $AG_NAME..."
  kubectl exec -n "$NAMESPACE" -i "$POD_NAME" -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -Q "
    ALTER AVAILABILITY GROUP [${AG_NAME}] JOIN WITH (CLUSTER_TYPE = NONE);
    GO
    ALTER AVAILABILITY GROUP [${AG_NAME}] GRANT CREATE ANY DATABASE;
    GO
  "
done

echo "✅ All secondary replicas have joined the Availability Group '$AG_NAME' successfully."
