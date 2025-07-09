---
layout: post
title: "Gathering Other Types of Statistics"
excerpt: "Since the Cost Based Optimizer is now the only supported optimizer, all tables in the database need to have statistics, including all of the dictionary tables (tables owned by SYS,SYSTEM, etc., and residing in the system and SYSAUX tablespace) and the x$ tables used by the dynamic v$ performance views."
date: 2025-07-09 15:00:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/Gathering-Other-Types-of-Statistics.jpg
---

Since the Cost Based Optimizer is now the only supported optimizer, all tables in the database need to have statistics, including all of the dictionary tables (tables owned by SYS,SYSTEM, etc., and residing in the system and SYSAUX tablespace) and the x$ tables used by the dynamic v$ performance views.  

### Dictionary Statistics  
Statistics on the dictionary tables are maintained via the automated statistics gathering task run during the nightly maintenance window. It is highly recommended that you allow the automated statistics gather task to maintain dictionary statistics even if you choose to switch off the automatic statistics gathering job for your main application schema. You can do this by changing the value of AUTOSTATS_TARGET to ORACLE instead of AUTO using the
procedure DBMS_STATS.SET_GLOBAL_PREFS.  
```sql
exec dbms_stats.set_global_prefs('autostats_target','oracle')
```

### Fixed Object Statistics  
Beginning with Oracle Database 12c, fixed object statistics are collected by the automated statistics gathering task if they have not been previously collected. Beyond that, the database does not gather fixed object statistics. Unlike other database tables, dynamic sampling is not automatically used for SQL statements involving X$ tables when optimizer statistics are missing so the optimizer uses predefined default values for the statistics if they are missing.  

These defaults may not be representative and could potentially lead to a suboptimal execution plan, which could cause severe performance problems in your system. It is for this reason that we strongly recommend you manually gather fixed objects statistics.  

You can collect statistics on fixed objects using DBMS_STATS.GATHER_FIXED_OBJECTS_STATS procedure.  
Because of the transient nature of the x$ tables it is import that you gather fixed object statistics when there is a representative workload on the system. This may not always be feasible on large systems due to additional resources needed to gather the statistics. If you can’t do it during peak load you should do it after the system has warmed up and the three key types of fixed object tables have been populated:  
» Structural data - for example, views covering datafiles, controlfile contents, etc.  
» Session based data - for example, v$session, v$access, etc.  
» Workload data - for example, v$sql, v$sql_plan, etc.  

It is recommended that you re-gather fixed object statistics if you do a major database or application upgrade,implement a new module, or make changes to the database configuration. For example if you increase the SGA size then all of the x$ tables that contain information about the buffer cache and shared pool may change significantly,such as x$ tables used in v$buffer_pool or v$shared_pool_advice.  

### System Statistics  
System statistics enable the optimizer to more accurately cost each operation in an execution plan by using information about the actual system hardware executing the statement, such as CPU speed and IO performance.  

System statistics are enabled by default, and are automatically initialized with default values; these values are representative for most systems.   

### Conclusion  
In order for the Oracle Optimizer to accurately determine the cost for an execution plan it must have accurate statistics about all of the objects (table and indexes) accessed in the SQL statement and information about the system on which the SQL statement will be run.  

By using a combination of the automated statistics gathering task and the other techniques described in this paper a DBA can maintain an accurate set of statistics for their environment and ensure the optimizer always has the necessary information in order to select the most optimal plan. Once a statistics gathering strategy has been put in place, changes to the strategy should be done in a controlled manner and take advantage of key features such as pending statistics to ensure they do not have an adverse effect on application performance.  
