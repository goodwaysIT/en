---
layout: post
title: "Alert Log of the Primary Database Shows Error 16063"
excerpt: "Every day from 1:00 AM to 3:00 AM, the primary database's alert log reports the following messages. The synchronization between the primary and standby databases is not affected."
date: 2025-08-25 10:00:00 +0800
categories: [Oracle, Database]
tags: [Error 16063, oracle]
image: /assets/images/posts/Alert-Log-of-the-Primary-Database-Shows-Error-16063.jpg
---

## Problem Description  
The alert log of the Primary Database shows the error: `Error 16063 archiving LNO:x to 'xxxdg'`.  
Environment: Oracle 19.7 RAC, one primary and two standby databases.  
Every day from 1:00 AM to 3:00 AM, the primary database's alert log reports the following messages. The synchronization between the primary and standby databases is not affected.  

Alert log errors:  
```
TT02 (PID:26639): Error 16063 archiving LNO:1 to 'fcdbdg'
2024-04-13T04:21:31.131104+08:00
TT05 (PID:284880): SRL selected for T-1.S-86392 for LAD:2
2024-04-13T04:27:02.543062+08:00
Thread 1 advanced to log sequence 86393 (LGWR switch)
Current log# 3 seq# 86393 mem# 0: +DATAC1/fCDB/ONLINELOG/group_3.272.1043431153
2024-04-13T04:27:03.733427+08:00
TT02 (PID:26639): SRL selected for T-1.S-86393 for LAD:3
TT02 (PID:26639): SRL selected for T-1.S-86393 for LAD:2
2024-04-13T04:27:04.165936+08:00
LOGMINER: End mining logfile for session 2 thread 1 sequence 86392, +DATAC1/fCDB/ONLINELOG/group_1.261.1043431153
2024-04-13T04:27:04.221339+08:00
LOGMINER: Begin mining logfile for session 2 thread 1 sequence 86393, +DATAC1/fCDB/ONLINELOG/group_3.272.1043431153
2024-04-13T04:27:07.213294+08:00
ARC1 (PID:26630): Archived Log entry 319543 added for T-1.S-86392 ID 0x73041d97 LAD:1
2024-04-13T04:29:01.299251+08:00
TT02 (PID:26639): Error 16063 archiving LNO:3 to 'fcdbsdb'
```

## Analysis  
Confirm the ADG parameter settings:  
```
SYS@fcdb2> show parameter fal

NAME TYPE VALUE
------------------------------------ ----------- ------------------------------
fal_client string
fal_server string fcdbsdb,fcdbdg

SYS@fcdb2> show parameter log_archive

NAME TYPE VALUE
------------------------------------ ----------- ------------------------------
log_archive_config string DG_CONFIG=(fcdb,fcdbdg,f
cdbsdb)
log_archive_dest string
log_archive_dest_1 string LOCATION=+RECOC1 VALID_FOR=(AL
L_LOGFILES,ALL_ROLES) DB_UNIQU
E_NAME=fcdb


log_archive_dest_2 string SERVICE=fcdbdg ASYNC REOPEN=
15 VALID_FOR=(ONLINE_LOGFILES,
PRIMARY_ROLE) DB_UNIQUE_NAME=a
facdbdg

log_archive_dest_3 string SERVICE=fcdbsdb ASYNC REOPEN
=15 VALID_FOR=(ONLINE_LOGFILES
,PRIMARY_ROLE) DB_UNIQUE_NAME=
fcdbsdb

log_archive_format string %t_%s_%r.dbf
log_archive_max_processes integer 4
log_archive_min_succeed_dest integer 1
log_archive_start boolean FALSE
log_archive_trace integer 0
```

Dataguard Configuration Report  
```
Database Name: fcdb
Database Unique Name: fcdb
Database Home: /u01/app/oracle/product/19.0.0.0/dbhome_1
Database SID: fcdb1
Database Version: 19.7.0.0.0
Database Owner: oracle
Database Role: PRIMARY
Database TNS Admin: /u01/app/oracle/product/19.0.0.0/dbhome_1/network/admin


DB_UNIQUE_NAME PARENT_DBUN DEST_ROLE CURRENT_SCN CON_ID
----------------------------- ----------------------------- ----------------- ---------------- -------------
fcdb NONE PRIMARY DATABASE 300985562490 0
fcdbdg fcdb PHYSICAL STANDBY 300985510289 0
fcdbsdb fcdb PHYSICAL STANDBY 300985510884 0
```

Verify the last sequence# received and the last sequence# applied to standby database.  
```
SYS@fcdb1>
SYS@fcdb1> SELECT al.thrd "Thread", almax "Last Seq Received", lhmax "Last Seq Applied" FROM (select thread# thrd, MAX(sequence#) almax FROM v$archived_log WHERE resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) al, (SELECT thread# thrd, MAX(sequence#) lhmax FROM v$log_history WHERE resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) lh WHERE al.thrd = lh.thrd;

Thread Last Seq Received Last Seq Applied
1 89891 89891
2 76653 76653

2 rows selected.
```

Check the transport lag and apply lag from the V$DATAGUARD_STATS view. This is only relevant when LGWR log transport and real time apply are in use.  
```
SYS@fcdb1>
SYS@fcdb1>SELECT * FROM v$dataguard_stats WHERE name LIKE '%lag%';

SOURCE_DBID SOURCE_DB_UNIQUE_NAME NAME VALUE UNIT TIME_COMPUTED DATUM_TIME CON_ID
0 transport lag +00 00:00:00 day(2) to second(0) interval 06/03/2024 11:18:52 06/03/2024 11:18:51 0
0 apply lag +00 00:00:00 day(2) to second(0) interval 06/03/2024 11:18:52 06/03/2024 11:18:51 0

SYS@fcdb1> SELECT * FROM v$dataguard_stats WHERE name LIKE '%lag%';

SOURCE_DBID SOURCE_DB_UNIQUE_NAME NAME VALUE UNIT TIME_COMPUTED DATUM_TIME CON_ID
0 transport lag +00 00:00:00 day(2) to second(0) interval 06/03/2024 11:24:24 06/03/2024 11:24:24 0
0 apply lag +00 00:00:00 day(2) to second(0) interval 06/03/2024 11:24:24 06/03/2024 11:24:24 0

```
Based on all logs from the primary and standby databases, it can be confirmed that the primary database and the standby databases are synchronized. There is no lag between the primary database and the two standby databases.  

## Solution  
After investigation, it was found that other customers have encountered this issue. The recommended solution is to set the following hidden parameter and restart the primary database, then monitor for the error messages.  
```
alter system set "_REDO_TRANSPORT_ASYNC_MODE"=1 scope=spfile sid='*'; --> this parameter needs database restart.
```

## REFERENCE INFORMATION  
Error 16063 archiving LNO:n to '<db>' (Doc ID 2722180.1)  
