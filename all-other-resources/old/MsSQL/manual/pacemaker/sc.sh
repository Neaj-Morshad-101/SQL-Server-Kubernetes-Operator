#!/bin/bash

declare -i pid

echo "haclusterpwd
haclusterpwd" | passwd hacluster

systemctl enable pcsd
service pcsd start

systemctl enable pacemaker
service pacemaker start

# corosync-keygen

# scp /etc/corosync/authkey my-cluster-1.my-cluster:/etc/corosync

# scp /etc/corosync/corosync.conf my-cluster-1.my-cluster:/etc/corosync

service corosync restart

service pacemaker restart

sleep 3650d

# pid=$!

# wait $pid