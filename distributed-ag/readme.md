# SQL Server Distributed Availability Groups (DAGs)

## Key Features & Guidelines

### **Version Compatibility**
- **Primary AG**: Same or lower version than secondary AGs.
- **Secondary AGs**: Same or higher version than primary AG.  
  *Designed for upgrades/migrations.*

### **Failover Support**
- **Manual failover only** (automated failover not recommended except in rare cases).  
- Ideal for disaster recovery (e.g., data center switches).

### **Data Movement Configuration**
- **Recommended**: Asynchronous mode (for disaster recovery).  
- **Migration finalization**:  
  1. Stop traffic to the original AG.  
  2. Switch to **synchronous mode** to ensure zero data loss.  
  3. Verify synchronization.  
  4. Fail over to the secondary AG.

### **Use Cases**
1. **Disaster recovery** (multi-site/data center).  
2. **Migrations** (replaces legacy methods like backup/restore or log shipping).  

### **Benefits**
- Supports hybrid AG configurations (different versions/settings).  
- Simplifies large-scale migrations with minimal downtime.  
You can use this method for OS and SQL Version upgrades also.

## Configure Distributed Availability Group on Kubernetes



First create the first availability group [ag1](../availability-group/ag1/readme.md) and second availability group [ag2](../availability-group/ag2/readme.md) following the steps detailed in readme file. 

Now create load balancer svc for each availability group for inter cluster communication. 

Create load balancer svc for first availability group (ag1) in the first cluster. 
`kubectl apply -f ag1-primary-svc.yaml`
```bash
kubectl get svc -n dag ag1-primary
NAME          TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
ag1-primary   LoadBalancer   10.43.238.68   10.2.0.149    1433:32400/TCP,5022:30466/TCP   4h25m
```

Create load balancer svc for second availability group (ag2) in the second cluster.
`kubectl apply -f ag2-primary-svc.yaml`
```bash
kubectl get svc -n dag ag2-primary
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
ag2-primary   LoadBalancer   10.43.173.130   10.2.0.188    1433:30752/TCP,5022:31052/TCP   4h24m
```


Verify which one is the primary pod (replica) of each AG. 
Run `SELECT is_local, role_desc from sys.dm_hadr_availability_replica_states` on each replica to see the role. 

Mine is `ag1-0` for ag1, and `ag2-0` for ag2. 



Add lable `role=primary` in ag1-0, ag2-0 (primary pods of each AG).
```
first cluster:
kubectl label pod ag1-0 -n dag role=primary
second cluster:
kubectl label pod ag2-0 -n dag role=primary
```



Now, create the DISTRIBUTED Availability Group named `DAG`.
ag1-primary:  EXTERNAL-IP    10.2.0.149
ag2-primary:  EXTERNAL-IP    10.2.0.188


```bash
# Primary Cluster 
kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
CREATE AVAILABILITY GROUP [DAG]  
   WITH (DISTRIBUTED)   
   AVAILABILITY GROUP ON  
      'ag1' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.149:5022',    
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      ),   
      'ag2' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.188 :5022',   
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      );    
GO 
"
```

```bash
# Secondary Cluster
kubectl exec -it -n dag ag2-0 -- bash
root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [DAG]
   JOIN   
   AVAILABILITY GROUP ON  
      'ag1' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.149:5022',    
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      ),   
      'ag2' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.188 :5022',   
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      );  
GO
"

root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use agtestdb
2> go
Changed database context to 'agtestdb'.
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
1> exit
root@ag2-0:/# exit
exit

kubectl exec -it -n dag ag2-2 -- bash
root@ag2-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use agtestdb
2> go
Changed database context to 'agtestdb'.
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
1> exit
root@ag2-2:/# exit
exit

kubectl exec -it -n dag ag2-1 -- bash
root@ag2-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use agtestdb;
2> go
Changed database context to 'agtestdb'.
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
1> 
```

We can see that, data has been replicated to all replicas of the ag2 successfully.




Now, let's insert some more data on global primary ag1-0. 



kubectl exec -it -n dag ag1-0 -- bash
root@ag1-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
2> go
is_local role_desc                                                    synchronization_health_desc                                 
-------- ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     

(5 rows affected)
1> use agtestdb;
2> go
Changed database context to 'agtestdb'.
1> INSERT INTO inventory VALUES (3, 'nana', 150); 
2> go
(1 rows affected)
1> 


➤ kubectl exec -it -n dag ag2-1 -- bash
root@ag2-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use agtestdb;
2> go
Changed database context to 'agtestdb'.
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150

(3 rows affected)
1> exit
root@ag2-1:/# exit
exit

kubectl exec -it -n dag ag2-2 -- bash
root@ag2-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use agtestdb;
2> go
Changed database context to 'agtestdb'.
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150

So the data is being replicated properly.



```bash
# You can check distributed AG health with command;
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT ag.[name] AS [AG Name], ag.is_distributed, ar.replica_server_name AS [Underlying AG], ars.role_desc AS [Role], ars.synchronization_health_desc AS [Sync Status] FROM sys.availability_groups AS ag INNER JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ar.replica_id = ars.replica_id WHERE ag.is_distributed = 1
"


OR 
SELECT ag.[name] AS [Distributed AG Name], ar.replica_server_name AS [Underlying AG], dbs.[name] AS [Database], ars.role_desc AS [Role], drs.synchronization_health_desc AS [Sync Status], drs.log_send_queue_size, drs.log_send_rate, drs.redo_queue_size, drs.redo_rate FROM sys.databases AS dbs INNER JOIN sys.dm_hadr_database_replica_states AS drs ON dbs.database_id = drs.database_id INNER JOIN sys.availability_groups AS ag ON drs.group_id = ag.group_id INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ars.replica_id = drs.replica_id INNER JOIN sys.availability_replicas AS ar ON ar.replica_id = ars.replica_id WHERE ag.is_distributed = 1


OR 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT ag.name AS group_name, ag.is_distributed, ar.replica_server_name AS replica_name, ar.availability_mode_desc, ar.failover_mode_desc, ar.primary_role_allow_connections_desc AS allow_connections_primary, ar.secondary_role_allow_connections_desc AS allow_connections_secondary, ar.seeding_mode_desc AS seeding_mode FROM sys.availability_replicas AS ar JOIN sys.availability_groups AS ag ON ar.group_id = ag.group_id"

```



## Now. test fail over in ag1: (Having issue, the ag2 replicas including the forwarder is not getting synced with the new primary like after ag1-0 to ag1-1 fail over)



➤ kubectl exec -it -n dag ag1-1 -- bash
root@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No
1> use [master]
2> go
Changed database context to 'master'.
1> ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 
2> go
1> SELECT is_local, role_desc, synchronization_health_desc from sys.dm_hadr_availability_replica_states
2> go
is_local role_desc                                                    synchronization_health_desc                                 
-------- ------------------------------------------------------------ ------------------------------------------------------------
       0 SECONDARY                                                    NOT_HEALTHY                                                 
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    NOT_HEALTHY                                                 
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    NOT_HEALTHY                                                 

(5 rows affected)
1> use agtestdb;
2> go
Changed database context to 'agtestdb'.
1> INSERT INTO inventory VALUES (4, 'firstfailover', 150); 
2> go

(1 rows affected)
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150
          4 firstfailover                                              150

(4 rows affected)
1> exit
root@ag1-1:/# exit
exit




Now. set the role to seondary, and resume on all the secondaries. then they will be in sync with the new global primary.


```
--  After failover, all secondary databases are suspended, we need to change the role and resume synchronization from the old primary replica. It need to be done for the secondary replicas also.
use [master]
ALTER AVAILABILITY GROUP [ag1]  SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME
```

If old primary was unavailable / offline during the force fail-over:

```
-- we need to make the AG offline when the old primary joins back. to change it's role from primary to secondary. (if it wasn't online during fail-over, then  after joining it's role will be primary also, Old primary's role will not be changed by running    
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY);

-- We need to make the AG offline from the old primary then it's role will be "RESOLVING".      
USE [master]
ALTER AVAILABILITY GROUP [ag1] OFFLINE

-- Now we can change it's role by running the following command

use [master]
ALTER AVAILABILITY GROUP [ag1] 
     SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb]
     SET HADR RESUME

```



ag2's replicas are not joining. 

use [master]
ALTER AVAILABILITY GROUP [dag]  SET (ROLE = SECONDARY);

use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME




### To Fail-over from ag1 to ag2:

Change the availability mode to sync commit. (if ag1 primary alive)
Execute this command on Primary and Forwarder;
`ALTER AVAILABILITY GROUP DAG MODIFY AVAILABILITY GROUP ON ‘AG!’ WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT ),‘AG2’ WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);`

Now our distributed AG in sync-commit mode.
We should check last_hardened_lsn it has to be the same for all databases on and both AG state should be in “SYNCHRONIZED” status. Check by running this query on global primary and forwarder.
`SELECT ag.name, drs.database_id, drs.group_id, drs.replica_id, drs.synchronization_state_desc, drs.end_of_log_lsn FROM sys.dm_hadr_database_replica_states drs, sys.availability_groups ag WHERE drs.group_id = ag.group_id`



With this query, we will set the distributed AG role on the primary to SECONDARY, run the query on the primary.
`ALTER AVAILABILITY GROUP [DAG] SET (ROLE = SECONDARY);`
!! Now distributed AG went offline and client connections are terminated.

With this query, failover the distributed AG to the secondary Availability Group. Run the query on the forwarder.
`ALTER AVAILABILITY GROUP [DAG] FORCE_FAILOVER_ALLOW_DATA_LOSS;`



After this, global primary is ag2-0, forwader is ag1-1. all replica is syncing with new global primary.
insert new data on new global primary. 
`INSERT INTO inventory VALUES (5, 'ag11Toag20', 150); `

You should see all the replicas of ag1 and ag2 are synced with new data. see from all replicas of ag1 and ag2. 
1> select * from inventory;
2> go
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150
          4 firstfailover                                              150
          5 ag11Toag20                                                 150



##### Again Fail-over from ag2 to ag1 tested: inserted new data to ag1-1 (new global primary). all replicas are synced. So Distributed AG fail over is working fine. 
