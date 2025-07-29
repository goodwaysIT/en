---
layout: post
title: "PGA Memory Operation Wait Event Caused by Different Table Data Volumes"
excerpt: "A SQL execution remained in ACTIVE state (the SQL contained CONNECT BY / regexp_substr) with wait time attributed to PGA memory operation."
date: 2025-07-29 15:00:00 +0800
categories: [Oracle, Database]
tags: [PGA Memory Operation, Wait Event, High Waits, oracle]
image: /assets/images/posts/PGA-Memory-Operation-Wait-Event.jpg
---

## Event Description  
A SQL execution remained in ACTIVE state (the SQL contained CONNECT BY / regexp_substr) with wait time attributed to PGA memory operation.
This SQL executed normally in the test environment (Oracle 19.3), but failed to execute in the production environment (Oracle 19.7).  

## SQLHC Report  
```
Description
--------------
SQLHC for c9333k2g237qx

Relevant Information Collection
---------------------------------------
SQL Text
SELECT DISTINCT REGEXP_SUBSTR(T.TASK_FRORGS, '[^,]+', 1, LEVEL) AS AA FROM EARLY_CONFIG_SP_TASK T
WHERE T.TASK_START_DATE = :B3
AND T.TASK_FRORGS = :B2
AND T.TASK_BATCH_ID = :B1
CONNECT BY REGEXP_SUBSTR(T.TASK_FRORGS, '[^,]+', 1, LEVEL) IS NOT NULL
AND PRIOR T.TASK_FRORGS = T.TASK_FRORGS
AND PRIOR SYS_GUID() IS NOT NULL

Current Plans Summary (GV$SQL)

Execution Plans performance metrics for c9333k2g237qx while still in memory. Plans ordered by average elapsed time.
# Plan HV Avg Avg Avg Avg Avg Avg Avg Avg Avg Avg Avg Avg Total Total Total Total Total Total Min Max Min Max First Load Last Load Last Active
Elapsed CPU IO Conc Appl Clus PLSQL Java Buffer Disk Direct Rows Execs Fetch Loads Inval Parse Child Cost Cost Opt Env HV Opt Env HV
Time Time Time Time Time Time Time Time Gets Reads Writes Proc Calls Cursors
(secs) (secs) (secs) (secs) (secs) (secs) (secs) (secs)
1 753884331 116074.806 116019.226 0 0 0 0 0 0 6 0 0 0 1 1 1 0 1 1 4 3228039672 2024-06-23/03:00:00 2024-06-23/03:00:00 2024-06-24/11:14:34

Active Session History by Plan Line (GV$ACTIVE_SESSION_HISTORY)

Snapshots counts per Plan Line and Wait Event for c9333k2g237qx.
This section includes data captured by AWR.
Available on 11g or higher..
# Plan Plan Plan Plan Plan Plan Session Wait Event Curr Curr Snaps
Hash Line Operation Options Object Object State Class Obj Object Count
Value ID Owner Name ID Name
1 753884331 2 FILTER ON CPU 2
2 753884331 3 CONNECT BY WITHOUT FILTERING (UNIQUE) ON CPU 110905. 《----- Top count
```

## Subsequent Analysis Steps  
Through analysis of the SQLHC information for SQL: c9333k2g237qx, this SQL did execute for a very long time, but the time was spent on CPU Time, with no significant long-term PGA memory operation wait event observed.
The issue might lie in the execution plan, table size, statistics, or differences in bind variables passed. We need to compare the execution status in your mentioned test environment. Please provide the following information.  

1. Collect SQLHC for this SQL in the test environment (Oracle 19.3).  
2. Collect 10046 and 10053 trace for this SQL statement in both the test and production environments.  

```SQL
SQL> connect executing_user  
SQL> alter session set max_dump_file_size = UNLIMITED;  
SQL> alter session set timed_statistics=true;  
SQL> alter session set events '10053 trace name context forever, level 2';  
SQL> alter session set events '10046 trace name context forever, level 12';  
```

Execute the statement to reproduce the issue.  
If the execution time is very long, forcibly interrupt it after 10-20 minutes.  
```SQL
SQL> alter session set events '10046 trace name context off';
SQL> alter session set events '10053 trace name context off';
```

List the trace files using the statement below  
```SQL
SQL> select * from v$diag_info where NAME in ('Default Trace File', 'Diag Trace')
```

3. DB alert logs from the production environment during the time period when the statement was executed.  

4. Execute the following queries in both test and production environments and provide the results.  
```SQL
spool /tmp/test or product.html
set markup html on
set time on
alter session set nls_date_format='dd-mon-yyyy hh24:mi:ss';
SELECT * FROM DBA_TAB_STATISTICS where TABLE_NAME='EARLY_CONFIG_SP_TASK';
SELECT * FROM DBA_IND_STATISTICS where TABLE_NAME='EARLY_CONFIG_SP_TASK';
SELECT * FROM DBA_TAB_COL_STATISTICS where TABLE_NAME='EARLY_CONFIG_SP_TASK';
SELECT * FROM DBA_OPTSTAT_OPERATIONS where START_TIME >=to_date('2024-06-17 00:00:00','yyyy-mm-dd hh24:mi:ss') and END_TIME <= to_date('2024-06-24 01:00:00','yyyy-mm-dd hh24:mi:ss') order by START_TIME;
SELECT * FROM DBA_TAB_STATS_HISTORY where TABLE_NAME='EARLY_CONFIG_SP_TASK';
set markup html off
spool off
```

## Issue Summary  
Subsequent analysis revealed that the data volume differed between the test environment (19.3) and production environment (19.7).  
The SQL also failed to execute in the test environment with the same data. After development modified the SQL (adding new filtering conditions), the SQL executed normally.  
