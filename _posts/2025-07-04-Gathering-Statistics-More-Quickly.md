---
layout: post
title: "Gathering Statistics More Quickly"
excerpt: "This paper will discuss in detail, when and how to gather statistics for the most common scenarios seen in an Oracle Database."
date: 2025-07-04 11:00:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/Gathering-Statistics-More-Quickly.jpg
---

## Gathering Statistics More Quickly  
As data volumes grow and maintenance windows shrink, it is more important than ever to gather statistics in a timely manner. Oracle offers a variety of ways to speed up the statistics collection, from parallelizing the statistics gathering operations to generating statistics rather than collecting them.  

**Using Parallelism**  
Parallelism can be leveraged in several ways for statistics collection  
» Using the DEGREE parameter  
» Concurrent statistics gathering  
» A combination of both DEGREE and concurrent gathering  

**Using the DEGREE Parameter**  
The DBMS_STATS, DEGREE parameter controls the number of parallel execution processes that will be used to gather the statistics.
By default Oracle uses the same number of parallel server processes specified as an attribute of the table in the data dictionary (Degree of Parallelism). All tables in an Oracle database have this attribute set to 1 by default. It may be useful to explicitly set this parameter for the statistics collection on a large table to speed up statistics collection.

Alternatively you can set DEGREE to AUTO_DEGREE; Oracle will automatically determine the appropriate number of parallel server processes that should be used to gather statistics, based on the size of an object. The value can be between 1 (serial execution) for small objects to DEFAULT_DEGREE (PARALLEL_THREADS_PER_CPU XCPU_COUNT) for larger objects.  

You should note that setting the DEGREE for a partitioned table means that multiple parallel sever processes will be used to gather statistics on each partition but the statistics will not be gathered concurrently on the different partitions. Statistics will be gathered on each partition one after the other.  

**Concurrent Statistic Gathering**  
Concurrent statistics gathering enables statistics to be gathered on multiple tables in a schema (or database), and multiple (sub)partitions within a table concurrently. Gathering statistics on multiple tables and (sub)partitions concurrently can reduce the overall time it takes to gather statistics by allowing Oracle to fully utilize a multi processor environment.  

Concurrent statistics gathering is controlled by the global preference, CONCURRENT, which can be set to MANUAL, AUTOMATIC, ALL, OFF. By default it is set to OFF.  When CONCURRENT is enabled, Oracle employs Oracle Job Scheduler and Advanced Queuing components to create and manage multiple statistics gathering jobs concurrently.  

Calling DBMS_STATS.GATHER_TABLE_STATS on a partitioned table when CONCURRENT is set to MANUAL or ALL, causes Oracle to create a separate statistics gathering job for each (sub)partition in the table. How many of these jobs will execute concurrently, and how many will be queued is based on the number of available job queue processes (JOB_QUEUE_PROCESSES initialization parameter, per node on a RAC environment) and the available system resources. As the currently running jobs complete, more jobs will be dequeued and executed until all of the (sub)partitions have had their statistics gathered.  

If you gather statistics using DBMS_STATS.GATHER_DATABASE_STATS,DBMS_STATS.GATHER_SCHEMA_STATS, or DBMS_STATS.GATHER_DICTIONARY_STATS, then Oracle will
create a separate statistics gathering job for each non-partitioned table, and each (sub)partition for the partitioned tables. Each partitioned table will also have a coordinator job that manages its (sub)partition jobs. The database will then run as many concurrent jobs as possible, and queue the remaining jobs until the executing jobs complete.  

However, to prevent possible deadlock scenarios multiple partitioned tables cannot be processed simultaneously.
Hence, if there are some jobs running for a partitioned table, other partitioned tables in a schema (or database or dictionary) will be queued until the current one completes. There is no such restriction for non-partitioned tables.

Each of the individual statistics gathering jobs can also take advantage of parallel execution if the DEGREE parameter is specified.  

If a table, partition, or sub-partition is very small or empty, the database may automatically batch the object with other small objects into a single job to reduce the overhead of job maintenance.

**Configuring Concurrent Statistics Gathering**  
The concurrency setting for statistics gathering is turned off by default. It can be turned on as follows:  
```sql
exec dbms_stats.set_global_prefs('concurrent', 'all')
```
You will also need some additional privileges above and beyond the regular privileges required to gather statistics.  
The user must have the following Job Scheduler and AQ privileges:  
» CREATE JOB  
» MANAGE SCHEDULER  
» MANAGE ANY QUEUE  

The SYSAUX tablespace should be online, as the Job Scheduler stores its internal tables and views in SYSAUX tablespace. Finally, the JOB_QUEUE_PROCESSES parameter should be set to fully utilize all of the system resources available (or allocated) for the statistics gathering process. If you don't plan to use parallel execution you should set the JOB_QUEUE_PROCESSES to 2 X total number of CPU cores (this is a per node parameter in a RAC environment). Please make sure that you set this parameter system-wise (ALTER SYSTEM ... or in init.ora file) rather than at the session level (ALTER SESSION).  

If you are going to use parallel execution as part of concurrent statistics gathering you should disable the parallel adaptive multi user:  
```sql
ALTER SYSTEM SET parallel_adaptive_multi_user=false;
```
Resource manager must be activated using, for example:  
```sql
ALTER SYSTEM SET resource_manager_plan = 'DEFAULT_PLAN';
```

It is also recommended that you enable parallel statement queuing. This requires resource manager to be activated,and the creation of a temporary resource plan where the consumer group "OTHER_GROUPS" should have queuing enabled. By default, Resource Manager is activated only during the maintenance windows. The following script illustrates one way of creating a temporary resource plan (pqq_test), and enabling the Resource Manager with this plan.  
```sql
-- connect as a user with dba privileges
begin
dbms_resource_manager.create_pending_area();
dbms_resource_manager.create_plan('pqq_test', 'pqq_test');
dbms_resource_manager.create_plan_directive(
'pqq_test',
'OTHER_GROUPS',
'OTHER_GROUPS directive for pqq',
parallel_target_percentage => 90);
dbms_resource_manager.submit_pending_area();
end;
/
ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = 'pqq_test' SID='*';  
```

If you want the automated statistics gathering task to take advantage of concurrency, set CONCURRENT to either AUTOMATIC or ALL. A new ORA$AUTOTASK consumer group has been added to the Resource Manager plan
used during the maintenance window, to ensure concurrent statistics gathering does not use too much of the system
resources.
