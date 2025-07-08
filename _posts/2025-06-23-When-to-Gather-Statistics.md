---
layout: post
title: "When to Gather Statistics"
excerpt: "In order to select an optimal execution plan the optimizer must have representative statistics. Representative statistics are not necessarily up to the minute statistics but a set of statistics that help the optimizer to determine the correct number of rows it should expect from each operation in the execution plan."
date: 2025-06-23 11:40:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/When-to-Gather-Statistics.jpg
---

In order to select an optimal execution plan the optimizer must have representative statistics. Representative statistics are not necessarily up to the minute statistics but a set of statistics that help the optimizer to determine the correct number of rows it should expect from each operation in the execution plan.  

**Automatic Statistics Gathering Task**  
Oracle automatically collects statistics for all database objects, which are missing statistics or have stale statistics during a predefined maintenance window (10pm to 2am weekdays and 6am to 2am at the weekends). You can change the maintenance window that the job will run in via Enterprise Manager or using the DBMS_SCHEDULER and DBMS_AUTO_TASK_ADMIN packages.  

If you already have a well-established statistics gathering procedure or if for some other reason you want to disable automatic statistics gathering you can disable the task altogether:  
```sql
begin
dbms_auto_task_admin.disable(
client_name=>'auto optimizer stats collection',
operation=>null,
window_name=>null);
end;
/
```

**Manual Statistics Collection**  
If you plan to manually maintain optimizer statistics you will need to determine when statistics should be gathered.  
You can determine when statistics should be gathered based on staleness, as it is for the automatic job, or based on when new data is loaded in your environment. It is not recommended to continually re-gather statistics if the  underlying data has not changed significantly as this will unnecessarily waste system resources.  
If data is only loaded into your environment during a pre-defined ETL or ELT job then the statistics gathering operations can be scheduled as part of this process. You should try and take advantage of online statistics gathering and incremental statistics as part of your statistics maintenance strategy.  

**Online Statistics Gathering**  
In Oracle Database 18c, online statistics gathering “piggybacks” statistics gather as part of a direct-path data loading operation such as, create table as select (CTAS) and insert as select (IAS) operations. Gathering statistics as part of the data loading operation means no additional full data scan is required to have statistics available immediately after the data is loaded.  

Online statistics gathering does not gather histograms or index statistics, as these types of statistics require additional data scans, which could have a large impact on the performance of the data load. To gather the necessary histogram and index statistics without re-gathering the base column statistics use the DBMS_STATS.GATHER_TABLE_STATS procedure with the new options parameter set to GATHER AUTO. Note that for performance reasons, GATHER AUTO builds histogram using a sample of rows rather than all rows in the table.  

The notes column “HISTOGRAM_ONLY” indicates that histograms were gathered without re-gathering basic column statistics. There are two ways to confirm online statistics gathering has occurred: check the execution plan to see if the new row source OPTIMIZER STATISTICS GATHERING appears in the plan or look in the new notes column of the USER_TAB_COL_STATISTICS table for the status STATS_ON_LOAD.  

Since online statistics gathering was designed to have a minimal impact on the performance of a direct path load operation it can only occur when data is being loaded into an empty object. To ensure online statistics gathering kicks in when loading into a new partition of an existing table, use extended syntax to specify the partition explicitly.  
In this case partition level statistics will be created but global level (table level) statistics will not be updated. If incremental statistics have been enabled on the partitioned table a synopsis will be created as part of the data load operation.  

Online statistics gathering can be disabled for individual SQL statements using the NO_GATHER_OPTIMIZER_STATISTICS hint.  

**Incremental Statistics and Partition Exchange Data Loading**  
Gathering statistics on partitioned tables consists of gathering statistics at both the table level (global statistics) and (sub)partition level. If the INCREMENTAL3 preference for a partitioned table is set to TRUE, the DBMS_STATS.GATHER_*_STATS parameter GRANULARITY includes GLOBAL, and ESTIMATE_PERCENT is set to AUTO_SAMPLE_SIZE, Oracle will accurately derive all global level statistics by scanning only those
partitions that have been added or modified, and not the entire table. Incremental global statistics works by storing a synopsis for each partition in the table. A synopsis is statistical metadata for that partition and the columns in the partition. Aggregating the partition level statistics and the synopses from each partition will accurately generate global level statistics, thus eliminating the need to scan the entire table.  When a new partition is added to the table, you only need to gather statistics for the new partition. The table level statistics will be automatically and accurately calculated using the new partition synopsis and the existing partitions’ synopses.  

Note that partition statistics are not aggregated from subpartition statistics when incremental statistics are enabled.  

If you are using partition exchange loads and wish to take advantage of incremental statistics, you will need to set the DBMS_STATS table preference INCREMENTAL_LEVEL on the non-partitioned table to identify that it will be used in partition exchange load. By setting the INCREMENTAL_LEVEL to TABLE (default is PARTITION), Oracle will automatically create a synopsis for the table when statistics are gathered on it. This table level synopsis will then become the partition level synopsis after the exchange.  

However, if your environment has more trickle feeds or online transactions that only insert a small number of rows but these operations occur throughout the day, you will need to determine when your statistics are stale and then trigger the automated statistics gathering task. If you plan to rely on the STALE_STATS column in USER_TAB_STATISTICS to determine if statistics are stale you should be aware that this information is updated on a daily basis only. If you need more timely information on what DML has occurred on your tables you will need to look in USER_TAB_MODIFICATIONS, which lists the number of INSERTS, UPDATES, and DELETES that occurs on each table, whether the table has been truncated (TRUNCATED column) and calculate staleness yourself. Again, you should note this information is automatically updated, from memory, periodically. If you need the latest information you will need to manual flush the information using the DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO function.  

**Preventing "Out of Range" Condition**  
Regardless of whether you use the automated statistics gathering task or you manually gather statistics, if end-users start to query newly inserted data before statistics have been gathered, it is possible to get a suboptimal execution plan due to stale statistics, even if less than 10% of the rows have changed in the table. One of the most common cases of this occurs when the value supplied in a where clause predicate is outside the domain of values represented by the [minimum, maximum] column statistics. This is commonly known as an ‘out-of-range’ error. In
this case, the optimizer prorates the selectivity based on the distance between the predicate value, and the maximum value (assuming the value is higher than the max), that is, the farther the value is from the maximum or minimum value, the lower the selectivity will be.  

This scenario is very common with range partitioned tables.  A new partition is added to an existing range partitioned table, and rows are inserted into just that partition. End-users begin to query this new data before statistics have been gathered on this new partition.  For partitioned tables, you can use the DBMS_STATS.COPY_TABLE_STATS4 procedure (available from Oracle Database 10.2.0.4 onwards) to prevent "Out of Range" conditions. This procedure copies the statistics of a representative source [sub] partition to the newly created and empty destination [sub] partition. It also copies the statistics of the dependent objects: columns, local (partitioned) indexes, etc. and sets the high bound partitioning value as the max value of the partitioning column and high bound partitioning value of the previous partition as the min value of the partitioning column. The copied statistics should only be considered as temporary solution until it is possible to gather accurate statistics for the partition. Copying statistics should not be used as a substitute for actually gathering statistics.  

Note by default, DBMS_STATS.COPY_TABLE_STATS only adjust partition statistics and not global or table level statistics. If you want the global level statistics to be updated for the partition column as part of the copy you need to set the flags parameter of the DBMS_STATS.COPY_TABLE_STATS to 8.  

For non-partitioned tables you can manually set the max value for a column using the DBMS_STATS.SET_COLUMN_STATS procedure. This approach is not recommended in general and is not a substitute for actually gathering statistics.
