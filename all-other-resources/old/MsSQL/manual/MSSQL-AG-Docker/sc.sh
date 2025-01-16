#!/bin/bash

declare -i pid

echo "haclusterpwd
haclusterpwd" | passwd hacluster

# systemctl enable pcsd
# service pcsd start

# systemctl enable pacemaker
# service pacemaker start

# service corosync restart

# service pacemaker restart

/opt/mssql/bin/sqlservr

# sleep 3650d

# pid=$!

# wait $pid