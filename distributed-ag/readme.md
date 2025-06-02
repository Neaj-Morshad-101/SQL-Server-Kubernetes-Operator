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

Now create load balancer svc for each availability group for inter-cluster communication. 

Create load balancer svc for the first availability group (ag1) in the first cluster. 
`kubectl apply -f ag1-primary-svc.yaml`
```bash
kubectl get svc -n dag ag1-primary
NAME          TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
ag1-primary   LoadBalancer   10.43.238.68   10.2.0.83    1433:32400/TCP,5022:30466/TCP   4h25m
```

Create load balancer svc for a second availability group (ag2) in the second cluster.
`kubectl apply -f ag2-primary-svc.yaml`
```bash
kubectl get svc -n dag ag2-primary
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
ag2-primary   LoadBalancer   10.43.173.130   10.2.0.64    1433:30752/TCP,5022:31052/TCP   4h24m
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
ag1-primary:  EXTERNAL-IP    10.2.0.83
ag2-primary:  EXTERNAL-IP    10.2.0.64


```bash
# Primary Cluster: Create DAG
kubectl exec -it -n dag ag1-0 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
CREATE AVAILABILITY GROUP [DAG]  
   WITH (DISTRIBUTED)   
   AVAILABILITY GROUP ON  
      'ag1' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.83:5022',    
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      ),   
      'ag2' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.64 :5022',   
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      );    
GO 
"
```

```bash
# Secondary Cluster: JOIN DAG
kubectl exec -it -n dag ag2-0 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
ALTER AVAILABILITY GROUP [DAG]
   JOIN   
   AVAILABILITY GROUP ON  
      'ag1' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.83:5022',    
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      ),   
      'ag2' WITH    
      (   
         LISTENER_URL = 'tcp://10.2.0.64 :5022',   
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,   
         FAILOVER_MODE = MANUAL,   
         SEEDING_MODE = AUTOMATIC   
      );  
GO
"

If we have any databases in ag2: 
Msg 19511, Level 16, State 1, Server ag2-1, Line 2
Cannot join distributed availability group 'DAG'. The local availability group 'AG2' contains one or more databases. Remove all the databases or create an empty availability group to join a distributed availability group.


root@ag2-0:/# 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb
go
select * from inventory;
go
exit
"
Changed database context to 'agtestdb'.
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)


kubectl exec -it -n dag ag2-1 -- bash
root@ag2-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb
go
select * from inventory;
go
exit
"
Changed database context to 'agtestdb'.
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)


kubectl exec -it -n dag ag2-2 -- bash
root@ag2-2:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb
go
select * from inventory;
go
exit
"
Changed database context to 'agtestdb'.
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154

(2 rows affected)
```

We can see that, data has been replicated to all replicas of the ag2 successfully.




#### Now, let's insert some more data on global primary ag1-0. 


```bash
kubectl exec -it -n dag ag1-0 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go 
"
```
is_local role_desc                                                    synchronization_health_desc                                 
-------- ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     
       1 PRIMARY                                                      HEALTHY                                                     
       0 SECONDARY                                                    HEALTHY                                                     

```bash
kubectl exec -it -n dag ag1-0 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
go
INSERT INTO inventory VALUES (3, 'nana', 150);
go
select * from inventory;
go
"
```

```bash
kubectl exec -it -n dag ag2-1 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
go
select * from inventory;
go
"
```
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150

```bash
kubectl exec -it -n dag ag2-2 -- bash
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
go
select * from inventory;
go
"
```
id          name                                               quantity
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150

So the data is being replicated properly.



```bash
# You can check distributed AG health with command;
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT ag.[name] AS [AG Name], ag.is_distributed, ar.replica_server_name AS [Underlying AG], ars.role_desc AS [Role], ars.synchronization_health_desc AS [Sync Status] FROM sys.availability_groups AS ag INNER JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ar.replica_id = ars.replica_id WHERE ag.is_distributed = 1"

OR 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT ag.name AS group_name, ag.is_distributed, ar.replica_server_name AS replica_name, ar.availability_mode_desc, ar.failover_mode_desc, ar.primary_role_allow_connections_desc AS allow_connections_primary, ar.secondary_role_allow_connections_desc AS allow_connections_secondary, ar.seeding_mode_desc AS seeding_mode FROM sys.availability_replicas AS ar JOIN sys.availability_groups AS ag ON ar.group_id = ag.group_id"

OR only in primary ag 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "SELECT ag.[name] AS [Distributed AG Name], ar.replica_server_name AS [Underlying AG], dbs.[name] AS [Database], ars.role_desc AS [Role], drs.synchronization_health_desc AS [Sync Status], drs.log_send_queue_size, drs.log_send_rate, drs.redo_queue_size, drs.redo_rate FROM sys.databases AS dbs INNER JOIN sys.dm_hadr_database_replica_states AS drs ON dbs.database_id = drs.database_id INNER JOIN sys.availability_groups AS ag ON drs.group_id = ag.group_id INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ars.replica_id = drs.replica_id INNER JOIN sys.availability_replicas AS ar ON ar.replica_id = ars.replica_id WHERE ag.is_distributed = 1"
```



## Now, test failover in ag1: (Having issue, the ag2 replicas including the forwarder is not getting synced with the new primary like after ag1-0 to ag1-1 fail over)
Error: A connection timeout has occurred while attempting to establish a connection to availability replica 'ag1' with id [6CD38135-9FFF-24A2-9401-E9833DBDC2D1]. Either a networking or firewall issue exists, or the endpoint address provided for the replica is not the database mirroring endpoint of the host server instance.
Oooh! Got synced automatically after some time!!!!!!!!!!!!!!!!! (Maybe I failed back again to ag1-0 (the old first primary)). 


```bash
kubectl exec -it -n dag ag1-1 -- bash
root@ag1-1:/# 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
go 
ALTER AVAILABILITY GROUP ag1 FORCE_FAILOVER_ALLOW_DATA_LOSS; 
go
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"
````
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       0 SECONDARY                                                    30B2DB3D-A624-4CBF-8FE3-FBA82057C799 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB NOT_HEALTHY                                                  CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      EEFD62C3-5D3F-448C-9CF3-7C095B52E874 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    3C276D68-D215-4A8E-BE04-BF97DCBC34EB BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB NOT_HEALTHY                                                  CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      6CD38135-9FFF-24A2-9401-E9833DBDC2D1 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 NOT_HEALTHY                                                  DISCONNECTED                                                 NULL                                                 




root@ag2-0:/# 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
" 
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      62047802-0452-4AC3-8763-8638203E7DA3 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    7308E1A7-06B0-4A20-B719-2BBD7A7CD069 04539685-21FA-DFF2-D990-B45A6BCDD4CD NOT_HEALTHY                                                  CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    0B386958-C0CE-4C78-8EFA-581DB51FA921 04539685-21FA-DFF2-D990-B45A6BCDD4CD NOT_HEALTHY                                                  CONNECTED                                                    NULL                                                        
       1 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      DISCONNECTED                                                 ONLINE                   



Now, remove the `primary` label from previous primary ag1-0 and add on new global primary ag1-1. 
```bash
kubectl get pods -n dag -owide
NAME    READY   STATUS    RESTARTS        AGE     IP           NODE   NOMINATED NODE   READINESS GATES
ag1-0   1/1     Running   2 (3h18m ago)   6d23h   10.42.0.32   neaj   <none>           <none>
ag1-1   1/1     Running   2 (3h18m ago)   6d23h   10.42.0.28   neaj   <none>           <none>
ag1-2   1/1     Running   2 (3h18m ago)   6d23h   10.42.0.31   neaj   <none>           <none>

kubectl get endpoints -n dag ag1-primary
NAME          ENDPOINTS                         AGE
ag1-primary   10.42.0.32:5022,10.42.0.32:1433   6d20h

kubectl label pod ag1-0 -n dag role-

kubectl get endpoints -n dag ag1-primary
NAME          ENDPOINTS   AGE
ag1-primary   <none>      6d22h

kubectl label pod ag1-1 -n dag role=primary

kubectl get endpoints -n dag ag1-primary
NAME          ENDPOINTS                         AGE
ag1-primary   10.42.0.28:5022,10.42.0.28:1433   6d22h
```

Now. set the role to secondary, and resume on all the secondaries of (ag1 & ag2). then they will be healthy and will sync with the new global primary.     
```
--  After failover, all secondary databases are suspended, we need to change the role and resume synchronization from the old primary replica. It needs to be done for the secondary replicas also.
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
go
ALTER AVAILABILITY GROUP [ag1]  SET (ROLE = SECONDARY); 
go
ALTER DATABASE [agtestdb] SET HADR RESUME
go
"

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
go
ALTER AVAILABILITY GROUP [ag2]  SET (ROLE = SECONDARY); 
go
ALTER DATABASE [agtestdb] SET HADR RESUME
go
"
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
ALTER AVAILABILITY GROUP [ag1] SET (ROLE = SECONDARY); 

use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME

```


Now, the status is 
root@ag1-1:/# 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       0 SECONDARY                                                    30B2DB3D-A624-4CBF-8FE3-FBA82057C799 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      EEFD62C3-5D3F-448C-9CF3-7C095B52E874 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    3C276D68-D215-4A8E-BE04-BF97DCBC34EB BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      6CD38135-9FFF-24A2-9401-E9833DBDC2D1 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 NOT_HEALTHY                                                  DISCONNECTED                                                 NULL                                                        


root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      62047802-0452-4AC3-8763-8638203E7DA3 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    7308E1A7-06B0-4A20-B719-2BBD7A7CD069 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    0B386958-C0CE-4C78-8EFA-581DB51FA921 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      DISCONNECTED                                                 ONLINE



ag2 remains `DISCONNECTED & NOT_HEALTHY`. 






run these commands in ag2's primary: ag2-0 
root@ag2-0:/# 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
ALTER AVAILABILITY GROUP [dag] SET (ROLE = SECONDARY);
go
"
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME
go
"









Let's insert new data after ag1's internal failover. 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
go
INSERT INTO inventory VALUES (4, 'SecoundInternalAg1Failover2', 150); 
go
select * from inventory;
go
"


id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150
          4 FirstInternalAg1Failover                                   150





See from all replica of ag1 & ag2: 
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
select * from inventory;
"


#### The forwarder & ag2's replicas are not getting synced. 


root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      62047802-0452-4AC3-8763-8638203E7DA3 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    7308E1A7-06B0-4A20-B719-2BBD7A7CD069 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    0B386958-C0CE-4C78-8EFA-581DB51FA921 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      DISCONNECTED                                                 ONLINE                                                      

(4 rows affected)
root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No     
1> use master;
2> go
Changed database context to 'master'.
1> ALTER AVAILABILITY GROUP [dag] SET (ROLE = SECONDARY);
2> go

root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go
"
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      62047802-0452-4AC3-8763-8638203E7DA3 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    7308E1A7-06B0-4A20-B719-2BBD7A7CD069 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    0B386958-C0CE-4C78-8EFA-581DB51FA921 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    6CD38135-9FFF-24A2-9401-E9833DBDC2D1 6BC05A51-AA36-A196-09BD-481D7A0973C0 NOT_HEALTHY                                                  DISCONNECTED                                                 NULL                                                        
       1 PRIMARY                                                      0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    ONLINE                                                      



root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
select * from inventory;
"
Changed database context to 'agtestdb'.
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150

(3 rows affected)
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use [master]
go
ALTER AVAILABILITY GROUP [dag] SET (ROLE = SECONDARY);
go
use [master]
ALTER DATABASE [agtestdb] SET HADR RESUME
go
"

Sqlcmd: Warning: The last operation was terminated because the user pressed CTRL+C.
root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go                      
"
\is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       1 PRIMARY                                                      62047802-0452-4AC3-8763-8638203E7DA3 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    7308E1A7-06B0-4A20-B719-2BBD7A7CD069 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       0 SECONDARY                                                    0B386958-C0CE-4C78-8EFA-581DB51FA921 04539685-21FA-DFF2-D990-B45A6BCDD4CD HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    ONLINE                                                      

(4 rows affected)
root@ag2-0:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
use agtestdb;
select * from inventory;
"
Changed database context to 'agtestdb'.
id          name                                               quantity   
----------- -------------------------------------------------- -----------
          1 banana                                                     150
          2 orange                                                     154
          3 nana                                                       150
          4 FirstInternalAg1Failover                                   150

(5 rows affected)

oot@ag1-1:/# /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pa55w0rd!" -No -Q "
SELECT is_local, role_desc, replica_id, group_id, synchronization_health_desc, connected_state_desc, operational_state_desc from sys.dm_hadr_availability_replica_states
go                      
"
is_local role_desc                                                    replica_id                           group_id                             synchronization_health_desc                                  connected_state_desc                                         operational_state_desc                                      
-------- ------------------------------------------------------------ ------------------------------------ ------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------ ------------------------------------------------------------
       0 SECONDARY                                                    30B2DB3D-A624-4CBF-8FE3-FBA82057C799 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      EEFD62C3-5D3F-448C-9CF3-7C095B52E874 BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    3C276D68-D215-4A8E-BE04-BF97DCBC34EB BE9BE8C9-6E17-1132-BFBA-8B7D2C28AFDB HEALTHY                                                      CONNECTED                                                    NULL                                                        
       1 PRIMARY                                                      6CD38135-9FFF-24A2-9401-E9833DBDC2D1 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    ONLINE                                                      
       0 SECONDARY                                                    0EAC444F-1CF1-8D21-0178-B43D2842ACF5 6BC05A51-AA36-A196-09BD-481D7A0973C0 HEALTHY                                                      CONNECTED                                                    NULL                                                        

(5 rows affected)


# Okay, I have to impose the secondary role in dag's label in the ag2's primary (forwarder), and it works after I run the command 2nd time. NICE!





Try again without writing to ag2-0..............









SELECT r.replica_server_name, r.endpoint_url,
rs.connected_state_desc, rs.role_desc, rs.operational_state_desc,
rs.recovery_health_desc,rs.synchronization_health_desc,
r.availability_mode_desc, r.failover_mode_desc
FROM sys.dm_hadr_availability_replica_states rs
INNER JOIN sys.availability_replicas r
ON rs.replica_id=r.replica_id
ORDER BY r.replica_server_name
replica_server_name








Additional Information on Fail over & Resume: 
[Manual SQL Server Availability Group Failover](https://www.mssqltips.com/sqlservertip/3437/manual-sql-server-availability-group-failover/)

https://www.mssqltips.com/sqlservertip/6988/sql-server-availability-group-maintenance-distributed-availability-groups/

https://www.mssqltips.com/sqlservertip/5053/setup-and-implement-sql-server-2016-always-on-distributed-availability-groups/

Not Sync Issue 
https://dba.stackexchange.com/questions/305737/sql-server-distributed-availability-group-databases-not-syncing-after-a-global-p

https://www.mssqltips.com/sqlservertip/6988/sql-server-availability-group-maintenance-distributed-availability-groups/
https://www.mssqltips.com/sqlservertip/5053/setup-and-implement-sql-server-2016-always-on-distributed-availability-groups/

https://www.sqlshack.com/monitor-and-failover-a-distributed-sql-server-always-on-availability-group/

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No -Q "
USE [master]
GO
ALTER AVAILABILITY GROUP [DAG]  
MODIFY AVAILABILITY GROUP ON  
 'AG1' WITH    
    (   
        LISTENER_URL = 'tcp://10.2.0.83:5022'
    )
GO"

/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -No -Q "
USE [master]
GO
ALTER AVAILABILITY GROUP [DAG]  
MODIFY AVAILABILITY GROUP ON  
  'AG2' WITH    
    (   
        LISTENER_URL = 'tcp://10.2.0.64 :5022'
    )
GO"



We Need to explore more on the above links.







### Data Center Failover: To Fail-over from ag1 to ag2:

Change the availability mode to sync commit. (if ag1 primary alive)
Execute this command on Primary and Forwarder;
`ALTER AVAILABILITY GROUP DAG MODIFY AVAILABILITY GROUP ON ‘AG!’ WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT ),‘AG2’ WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);`

Now our distributed AG in sync-commit mode.
We should check last_hardened_lsn it has to be the same for all databases on and both AG, the state should be in “SYNCHRONIZED” status. Check by running this query on global primary and forwarder.
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
