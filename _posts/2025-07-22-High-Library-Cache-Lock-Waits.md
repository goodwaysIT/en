---
layout: post
title: "High Library Cache Lock Waits During Concurrent Heavy Mixed PMOPs and DML on Several Partitioned Tables"
excerpt: "High 'library cache lock' with 'library cache load lock' waits were seen when there were partition maintenance operations (PMOPs) with concurrent DML on the same table. "
date: 2025-07-22 17:00:00 +0800
categories: [Oracle, Database]
tags: [Library Cache Lock, library cache load lock, High Waits, oracle]
image: /assets/images/posts/High-Library-Cache-Lock-Waits.jpg
---

## Symptoms
High "library cache lock" with "library cache load lock" waits were seen when there were partition maintenance operations (PMOPs) with concurrent DML on the same table.  In this case, for the same table, a new partition was added and a different one dropped about every second while DML was also occurring.   This same type of workload was being done on other partitioned tables at the same time.
An AWR might look something like the following:

Top 10 Foreground Events by Total Wait Time

|Event                            |Waits     |Total Wait Time (sec)      |Wait Avg(ms)      |% DB time      |Wait Class|
|:----|----:|----:|----:|----:|----:|
|library cache lock              |64,604                   |144.2K            |2232.7            |75.6     |Concurrency|
|library cache load lock         |14,231                    |12.3K            |860.92             |6.4     |Concurrency|
|DB CPU                          |                         |8156.9               |4.3             |                   |
|db file sequential read     |16,734,388                   |5672.9              |0.34             |3.0        |User I/O|
|row cache lock              |14,571,514                   |4442                |0.30             |2.3     |Concurrency|
|cursor: pin S wait on X          |2,278                   |2167.6            |951.53             |1.1     |Concurrency|
|gc cr disk read              |8,135,284                   |1524.6              |0.19              |.8         |Cluster|
|enq: IV - contention           |423,859                      |271              |0.64              |.1           |Other|
|SQL*Net message from dblink     |38,133                    |202.7              |5.31              |.1         |Network|
|Disk file operations I/O    |14,810,701                    |140.5              |0.01              |.1        |User I/O|

## Solution
Oracle does not recommend mixing PMOPs with DML on a partitioned table because of the cursor invalidations that PMOPs cause (expected behavior). Take the following actions to help reduce the impact of mixing PMOPs with heavy DML on the same partitioned tables.  
1. Consider applying patches for these bugs if you also see "cursor: pin S wait on X" waits in the same top 10 events list of the AWR:  
Patch 14380605 : HIGH LIBRARY CACHE LOCK,CURSOR: PIN S WAIT ON X AND LIBRARY CACHE: MUTEX X  
Patch 23003919 : LIBRARY CACHE LOCK & CURSOR: PIN S WAIT ON X DUE TO INVALIDATION PARALLEL QUERY  

2. Reduce impact from this query (below) by setting deferred_segment_creation = false if you insert into the partition just shortly after it's created:  
```sql
select pctfree_stg, pctused_stg, size_stg,initial_stg, next_stg,
minext_stg,
  maxext_stg, maxsiz_stg, lobret_stg,mintim_stg, pctinc_stg, initra_stg,
  maxtra_stg, optimal_stg, maxins_stg,frlins_stg, flags_stg, bfp_stg,
enc_stg,
  cmpflag_stg, cmplvl_stg,imcflag_stg
from
 deferred_stg$ where obj# =:1
```
Rationale: if you insert into the segment right after creating it. If you always insert into the partition you are adding, deferred segment creation does not provide a benefit but does add a cost. We need to take the X library cache lock twice: once for add partition DDL, and again when the insert creates the segment. If deferred segment creation is disabled we will take the X lock once for the DDL and will add the partition and create the segment under this one lock.  

3. Reduce extent scans for library cache loads by   
(a) gathering statistics on all partitions  
Rationale:  
Having many partitions without statistics will cause slow library cache loads because we will do extent scans to estimate # of blocks in the partition.  You can eliminate these extent scans by gathering stats on every partition (which is a good idea for other reasons as well).  Eliminating these extent scans will improve CPU time for indpart$ and tabpart$ queries. .  


4. If you are dropping or adding multiple partitions on the same table, consider using the new feature in 12c that lets you drop or add multiple partitions in a single DDL statement.  This causes the invalidation of the row cache object to occur only once per DDL statement vs. once for each partition add and drop.
```
You may also want to reference Document 1530075.1 - High Waits for 'library cache lock' Event when Using Table Partitioned by Interval, which applies to < 11.2.0.4.
```
