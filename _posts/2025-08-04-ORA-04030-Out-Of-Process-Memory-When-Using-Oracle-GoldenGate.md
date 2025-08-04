---
layout: post
title: "ORA-04030: Out Of Process Memory When Trying To Allocate <nn> Bytes (kxs-heap-w,krvxlogact) When Using Oracle GoldenGate"
excerpt: "The problem is caused due to the large number of entries at SYSTEM.LOGMNR_LOG$ table. The SYSTEM.LOGMNR_LOG$ stores the archived log files required by Oracle GoldenGate Extract and Streams Capture processes."
date: 2025-08-04 15:00:00 +0800
categories: [Oracle, Database, GoldenGate]
tags: [ORA-04030, Out Of Process Memory, SYSTEM.LOGMNR_LOG$, GoldenGate, oracle]
image: /assets/images/posts/ORA-04030-Out-Of-Process-Memory-When-Using-Oracle-GoldenGate.jpg
---

## Symptoms
Database alert log showing following memory error:
```
Errors in file /u01/app/oracle/diag/rdbms/oggdb/oggdb1/trace/oggdb1_ppa7_120312.trc (incident=52058):
ORA-04030: out of process memory when trying to allocate bytes (,)
Use ADRCI or Support Workbench to package the incident.
See Note 411.1 at My Oracle Support for error and packaging details.
2024-08-29T05:58:18.611120+08:00
Errors in file /u01/app/oracle/diag/rdbms/oggdb/oggdb1/trace/oggdb1_ora_67839.trc (incident=52033):
ORA-04030: out of process memory when trying to allocate 278587224 bytes (kxs-heap-w,krvxlogact)
Use ADRCI or Support Workbench to package the incident.
See Note 411.1 at My Oracle Support for error and packaging details.
```

A database trace file is produced as well with following content:
```
*** 2024-08-28T15:58:23.231573+08:00
*** SESSION ID:(291.42918) 2024-08-28T15:58:23.231582+08:00
*** CLIENT ID:() 2024-08-28T15:58:23.231587+08:00
*** SERVICE NAME:(SYS$USERS) 2024-08-28T15:58:23.231591+08:00
*** MODULE NAME:(emagent_SQL_rac_database) 2024-08-28T15:58:23.231595+08:00
*** ACTION NAME:(streams_latency_throughput) 2024-08-28T15:58:23.231600+08:00
*** CLIENT DRIVER:(jdbcthin) 2024-08-28T15:58:23.231604+08:00

[TOC00000]
Jump to table of contents
Dump continued from file: /u01/app/oracle/diag/rdbms/oggdb/oggdb1/trace/oggdb1_ora_67839.trc
[TOC00001]
ORA-04030: out of process memory when trying to allocate 278615672 bytes (kxs-heap-w,krvxlogact)

[TOC00001-END]
[TOC00002]
========= Dump for incident 51807 (ORA 4030) ========

*** 2024-08-28T15:58:23.231929+08:00
dbkedDefDump(): Starting incident default dumps (flags=0x2, level=3, mask=0x0)
[TOC00003]
----- Current SQL Statement for this session (sql_id=7sy4dzsndmh0k) -----
SELECT streams_name, streams_type, streams_latency, total_messages
FROM (
select capture_name streams_name, 'capture' streams_type , (available_message_create_time-capture_message_create_time)*86400 streams_latency, nvl(total_messages_enqueued,0) total_messages
from gv$streams_capture
union all
:
WHERE apc.apply_name = apr.apply_name AND apr.apply_name = aps.apply_name
) WHERE EXISTS
(SELECT 1 FROM v$database WHERE database_role IN ('PRIMARY', 'LOGICAL STANDBY'))
[TOC00003-END]

[TOC00004]
ksedst <- dbkedDefDump <- ksedmp <- dbgexPhaseII <- dbgexProcessError
<- dbgePostErrorKGE <- 1767 <- dbkePostKGE_kgsf <- kgereml <- kxfpProcessError
<- 1786 <- kxfpProcessMsg <- kxfpqidqr <- kxfpqdqr <- kxfxgs
<- kxfxcw <- qerpxFetch <- rwsfcd <- rwsfcd <- qeruaFetch
<- qervwFetch <- qerflFetch <- opifch2 <- kpoal8 <- opiodr
<- ttcpip <- opitsk <- opiino <- opiodr <- opidrv

[TOC00004-END]
```

## Changes
Using GoldenGate or Streams monitoring feature via Oracle Grid Control.  

## Cause  
The problem is caused due to the large number of entries at SYSTEM.LOGMNR_LOG$ table.  
The SYSTEM.LOGMNR_LOG$ stores the archived log files required by Oracle GoldenGate Extract and Streams Capture processes.
If for whatever reason the archived log files are not getting purged properly from the system, this table will grow and whenever querying any view that uses such table such as dba_capture, gv$streams_capture, gv$xstream_capture, or gv$goldengate_capture, the error may be seen.  
In this case, Grid Control DB agent is issue this query as part of the GG/Streams latency throughput statistics:  

```
SELECT streams_name, streams_type, streams_latency, total_messages
FROM (
select capture_name streams_name, 'capture' streams_type , (available_message_create_time-capture_message_create_time)*86400 streams_latency, nvl(total_messages_enqueued,0) total_messages
from gv$streams_capture
union all
```

## Solution  
Important: If your database is on 19.17DBRU level or lower, or 21c release, fix for known internal Bug 34115836 is required otherwise the purge routine may not work. The bug fix has been included starting on 19.18DBRU and 23.1. Find more details at Doc ID 34115836.8.  
We may have a couple of different causes that lead for archived log files not getting purged properly after being used by the GoldenGate or Streams, the below steps is the generic approach to help in solving both issues, the archive log files purge and ORA-04030 error:  
### 1. Use below queries to determine the number of archived log files associated to each GoldenGate extract (or Streams capture) processes:  

```SQL
sqlplus / as sysdba

spool support1.out
col CONSUMER_NAME for a30
set line 200
alter session set nls_date_format = 'dd/mon/rrrr hh24:mi:ss';
select min(FIRST_TIME) from SYSTEM.LOGMNR_LOG$ ;
select max(FIRST_TIME) from SYSTEM.LOGMNR_LOG$ ;
select count(*) from SYSTEM.LOGMNR_LOG$ ;
select count(*), PURGEABLE from dba_registered_archived_log group by PURGEABLE;
select count(*), PURGEABLE , CONSUMER_NAME from dba_registered_archived_log group by PURGEABLE , CONSUMER_NAME order by 2,1;
select count(*), status from v$archived_log group by status ;
select capture_name, status, to_char(APPLIED_SCN), to_char(REQUIRED_CHECKPOINT_SCN) from dba_capture;
exit
```

```
SYS@oggdb1> col CONSUMER_NAME for a30
SYS@oggdb1> set line 200
SYS@oggdb1> alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';

Session altered.

SYS@oggdb1> select min(first_time),max(first_time) from system.logmnr_log$;

MIN(FIRST_TIME) MAX(FIRST_TIME)
------------------- -------------------
2022-06-21 08:01:45 2024-09-05 15:54:37

SYS@oggdb1> select count(*) from system.logmnr_log$;

COUNT(*)
----------
274717

SYS@oggdb1> select count(*),purgeable from dba_registered_archived_log group by purgeable;

COUNT(*) PUR
---------- ---
1309 NO
273409 YES

SYS@oggdb1> select count(*),purgeable,consumer_name from dba_registered_archived_log group by purgeable,consumer_name order by 2,1;

COUNT(*) PUR CONSUMER_NAME
---------- --- ------------------------------
1309 NO OGG$CAP_IRDCB
273409 YES OGG$CAP_IRDCB

SYS@oggdb1> select count(*),status from v$archived_log group by status;

COUNT(*) S
---------- -
36237 D
131 A

SYS@oggdb1> select capture_name,status,to_char(applied_scn),to_char(required_checkpoint_scn) from dba_capture;

CAPTURE_NAME STATUS TO_CHAR(APPLIED_SCN)
-------------------------------------------------------------------------------------------------------------------------------- -------- ----------------------------------------
TO_CHAR(REQUIRED_CHECKPOINT_SCN)
----------------------------------------
OGG$CAP_IRDCB ENABLED 22465368276
22465368276


SYS@oggdb1> spool off
```

### 2. Stop any GoldenGate Extract or Streams Capture processes on such database.  

### 3. Use RMAN "crosscheck command" in order to re-catalog only the actual existing files:  
Note: Even if RMAN is not your backup tool, it must be used as noted below to resync the database control file with the actual existing files on disk.  
e.g.:  
```SQL
rman target / log /tmp/crosscheck.log
rman> crosscheck archivelog all;
```
```
crosscheck.log
-------------------------------------
Recovery Manager: Release 12.2.0.1.0 - Production on Thu Sep 12 08:52:46 2024

Copyright (c) 1982, 2017, Oracle and/or its affiliates. All rights reserved.

RMAN>
using target database control file instead of recovery catalog
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=219 instance=oggdb1 device type=DISK
validation succeeded for archived log
archived log file name=+RECODG1/oggdb/ARCHIVELOG/2024_09_11/thread_1_seq_562177.719.1179394927 RECID=1014710 STAMP=1179394929
：
archived log file name=+RECODG1/oggdb/ARCHIVELOG/2024_09_12/thread_2_seq_452465.816.1179478241 RECID=1014875 STAMP=1179478242
Crosschecked 168 objects
RMAN>
Recovery Manager complete.
```

### 4. Then via SQL*Plus, set parameter '_CHECKPOINT_FORCE'' to the capture component associated to such GoldenGate Extract or Streams Capture:  
Note: If there are more than one Extract / Capture, you can use only one process to complete this task, usually the process that has more entries from the previous queries on step 1:  
```SQL
conn / as sysdba  
exec dbms_capture_adm.set_parameter('<capture_name>','_CHECKPOINT_FORCE','Y');  
```

### 5. Set FIRST_SCN from such extract/capture process to the lowest value between APPLIED_SCN and REQUIRED_CHECKPOINT_SCN from this query:  
```SQL
select capture_name, status, to_char(APPLIED_SCN), to_char(REQUIRED_CHECKPOINT_SCN) from dba_capture where capture_name = '<capture_name>';  
```
Note: This is a safe call and the below procedure must finish fine.  

```SQL
conn / as sysdba
BEGIN
DBMS_CAPTURE_ADM.ALTER_CAPTURE(
capture_name => '<capture_name>',
first_scn => &SCN );
END;
/
```
Where &SCN must be the lowest SCN value between APPLIED_SCN and REQUIRED_CHECKPOINT_SCN columns from previous query.   

### 6. Start GoldenGate Extract / Streams Capture processes back normally.  

### 7. Monitor the environment, it should take some time, maybe up to one hour, for the underneath clean up to complete. You can use same queries as from step 1 to monitor the cleanup progress.  
Once the row count from SYSTEM.LOGMNR_LOG$ comes down, no more ORA-04030 should be seen.  

### If currently the OGG processes cannot be stopped, you can consider handling this problem during a maintenance window. The suggested solutions are as follows:  
1. Re-create the OGG extract process  
We re-create the OGG extract process, then the PURGEABLE archived logs released.   

2. Manually clear the accumulated archived logs (This method is theoretically derived. Must perform a full backup before deletion!):  
1). Stop all extract processes.  
2). Back up the SYSTEM.LOGMNR_LOG$ table.  
3). Manually delete all archived logs where purgeable is 'YES' (purgeable is 'YES').  
```SQL
DELETE FROM SYSTEM.LOGMNR_LOG$ WHERE (THREAD#, SEQUENCE#, RESETLOGS_CHANGE#, RESET_TIMESTAMP) IN
(SELECT DISTINCT P.THREAD#, P.SEQUENCE#, P.RESETLOGS_CHANGE#, P.RESET_TIMESTAMP AS RESETLOGS_ID FROM SYSTEM.LOGMNR_LOG$ P WHERE BITAND(P.STATUS, 2) = 2 MINUS SELECT DISTINCT Q.THREAD#, Q.SEQUENCE#, Q.RESETLOGS_CHANGE#, Q.RESET_TIMESTAMP AS RESETLOGS_ID FROM SYSTEM.LOGMNR_LOG$ Q WHERE BITAND(Q.STATUS, 2) <> 2) ;
```
