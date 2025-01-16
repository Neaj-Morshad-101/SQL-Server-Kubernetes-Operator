CREATE AVAILABILITY GROUP [ag3]
     WITH (DB_FAILOVER = ON, CLUSTER_TYPE = NONE)
     FOR REPLICA ON
         N'mssql0' 
 	      	WITH (
  	       ENDPOINT_URL = N'tcp://mssql0:1433',
  	       AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
  	       FAILOVER_MODE = EXTERNAL,
  	       SEEDING_MODE = AUTOMATIC
  	       ),
         N'mssql1' 
  	    WITH ( 
  	       ENDPOINT_URL = N'tcp://mssql1:1433', 
  	       AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
  	       FAILOVER_MODE = EXTERNAL,
  	       SEEDING_MODE = AUTOMATIC
  	       ),
  	   N'mssql2'
         WITH( 
  	      ENDPOINT_URL = N'tcp://mssql2:1433', 
  	      AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
  	      FAILOVER_MODE = EXTERNAL,
  	      SEEDING_MODE = AUTOMATIC
  	      );

ALTER AVAILABILITY GROUP [ag3] GRANT CREATE ANY DATABASE;