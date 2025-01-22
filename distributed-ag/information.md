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