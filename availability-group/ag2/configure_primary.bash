#!/usr/bin/env bash

set -euo pipefail

DIR="/scripts"
FILE="$DIR/run_signal.txt"

# Create or truncate the file
: > "$FILE"

# (Optional) Add a timestamp or any content you like
echo "Signal file created at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$FILE"

echo "Created $FILE"




# Use your SA password (or pull from env var)
PASSWORD="${MSSQL_SA_PASSWORD:-Pa55w0rd}"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

echo "Waiting for SQL Server to be ready on localhost:1433 …"
until $SQLCMD -S localhost -U sa -P "$PASSWORD" -Q "SELECT 1;" -b -o /dev/null; do
  echo "  ↳ not ready yet, retrying in 5s…"
  sleep 5
done

echo "✅ SQL Server is ready!"


# Constants
NAMESPACE="demo"
# STS_YAML="availability-group/ag1/sts.yaml"
AG_NAME="ag1"
POD_PREFIX="ag1"
POD_COUNT=3
CERT_NAME="dbm_certificate"
PASSWORD="Pa55w0rd"

# Ensure namespace exists
kubectl get namespace "$NAMESPACE" &>/dev/null || {
  echo "Namespace '$NAMESPACE' not found. Exiting."
  exit 1
}

# 1. Deploy StatefulSet and headless service
# echo "Applying StatefulSet & Service..."
# kubectl apply -f "$STS_YAML"

# 2. Wait for pods to be ready
# echo "Waiting for StatefulSet rollout..."
# kubectl rollout status statefulset/${POD_PREFIX} -n "$NAMESPACE"

# 3. Generate certificates
# echo "Generating certificates in $TEMP_DIR..."
# rm -rf "$TEMP_DIR" && mkdir -p "$TEMP_DIR"
# cd "$TEMP_DIR"

# openssl genrsa -out dbm_private_key.pem 3072
# openssl req -new -key dbm_private_key.pem -out dbm_csr.pem -subj "/CN=${POD_PREFIX}-0"
# openssl x509 -req -in dbm_csr.pem -signkey dbm_private_key.pem -out dbm_certificate.pem -days 3650

# openssl pkcs12 -export -out ${CERT_NAME}.pfx -inkey dbm_private_key.pem \
#   -in dbm_certificate.pem -passout pass:"${PASSWORD}"



for i in $(seq 0 $((POD_COUNT-1))); do
  POD_NAME="${POD_PREFIX}-${i}"
  echo "Installing ping tool on $POD_NAME..."
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c "apt-get update && apt-get install -y iputils-ping"
done


echo "=== Checking pod‑to‑pod connectivity ==="
for i in $(seq 0 $((POD_COUNT-1))); do
  SRC_POD="${POD_PREFIX}-${i}"
  for j in $(seq 0 $((POD_COUNT-1))); do
    DST_POD_HOST="${POD_PREFIX}-${j}.${POD_PREFIX}.${NAMESPACE}.svc.cluster.local"
    # Skip pinging self
    if [ "$i" -eq "$j" ]; then
      continue
    fi

    echo "--- From $SRC_POD to $DST_POD_HOST ---"
    kubectl exec -n "$NAMESPACE" "$SRC_POD" -- ping -c 3 "$DST_POD_HOST" || \
      echo "⚠️  $SRC_POD → $DST_POD_HOST failed!"
  done
done



echo "📦 Copying certificates to all replicas..."
for i in $(seq 0 $((POD_COUNT))); do
  POD_NAME="${POD_PREFIX}-${i}"
  echo "🔁 Copying certs to $POD_NAME..."
  kubectl cp ./${CERT_NAME}.cer "$NAMESPACE/$POD_NAME:/var/opt/mssql/${CERT_NAME}.cer"
  kubectl cp ./${CERT_NAME}.pvk "$NAMESPACE/$POD_NAME:/var/opt/mssql/${CERT_NAME}.pvk"
done



# 6. Create logins, keys & endpoints on each replica
for i in $(seq 0 $((POD_COUNT - 1))); do
  POD_NAME="${POD_PREFIX}-${i}"
  echo "🔧 Configuring SQL on $POD_NAME..."

  kubectl exec -n "$NAMESPACE" -i "$POD_NAME" -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -Q "
    CREATE LOGIN dbm_login WITH PASSWORD = '$PASSWORD';
    GO
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$PASSWORD';
    GO
    CREATE CERTIFICATE dbm_certificate
      FROM FILE = '/var/opt/mssql/dbm_certificate.cer'
      WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/dbm_certificate.pvk',
        DECRYPTION BY PASSWORD = 'Pa55w0rd\!'
      );
    GO
    CREATE ENDPOINT Hadr_endpoint 
      AS TCP (LISTENER_PORT = 5022, LISTENER_IP = (0.0.0.0)) 
      FOR DATA_MIRRORING (
        ROLE = ALL, 
        AUTHENTICATION = CERTIFICATE dbm_certificate, 
        ENCRYPTION = REQUIRED ALGORITHM AES
      );
    GO
    ALTER ENDPOINT Hadr_endpoint STATE = STARTED;
    GO
    GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO dbm_login;
    GO
    ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
    GO
  "
done


# 7. Create Availability Group on primary
PRIMARY_POD="${POD_PREFIX}-0"
echo "Creating Availability Group $AG_NAME on $PRIMARY_POD..."

REPLICA_DEFS=""
for i in $(seq 0 $((POD_COUNT-1))); do
  HOST="${POD_PREFIX}-${i}.ag1"
  REPLICA_DEFS+=" N'${POD_PREFIX}-${i}' WITH ( ENDPOINT_URL = N'tcp://${HOST}:5022', AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = MANUAL, SEEDING_MODE = AUTOMATIC, SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL) ),"
done
# Trim trailing comma
REPLICA_DEFS=${REPLICA_DEFS%,}
echo "$REPLICA_DEFS"

kubectl exec -n "$NAMESPACE" -i "$PRIMARY_POD" -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$PASSWORD" -Q "\
CREATE AVAILABILITY GROUP [${AG_NAME}] WITH (CLUSTER_TYPE = NONE) FOR REPLICA ON ${REPLICA_DEFS}; 
ALTER AVAILABILITY GROUP [${AG_NAME}] GRANT CREATE ANY DATABASE;
"

echo "Availability Group cluster '${AG_NAME}' is configured successfully!"