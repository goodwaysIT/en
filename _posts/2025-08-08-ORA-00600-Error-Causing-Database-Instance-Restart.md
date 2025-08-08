---
layout: post
title: "ORA-00600 Error Causing Database Instance Restart"
excerpt: "The database alert log reported ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553], causing an abnormal restart of the database instance."
date: 2025-08-08 14:30:00 +0800
categories: [Oracle, Database]
tags: [ORA-00600, kclantilock_17, error 12752, terminating the instance, oracle]
image: /assets/images/posts/ORA-00600-Error-Causing-Database-Instance-Restart.jpg
---

## Symptoms
DB Version: 12.2.0.1
Platform: Linux (x86_64) OS-Version 4.4.21-69-default

LOG FILE
-----------------------
Filename = alert_odb2.log
See the following error:
```
2024-04-12T13:25:46.972646+08:00
Errors in file /u01/app/oracle/diag/rdbms/odb/odb2/trace/odb2_lms0_121803.trc:
ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553], [], [], [], [], [], [], [], [], [], []
2024-04-12T13:25:50.948254+08:00
Dumping diagnostic data in directory=[cdmp_20240412132550], requested by (instance=2, osid=121803 (LMS0)), summary=[incident=25793].
2024-04-12T13:25:53.559520+08:00
opidrv aborting process LMS0 ospid (121803) as a result of ORA-600
2024-04-12T13:25:56.564478+08:00
Instance Critical Process (pid: 24, ospid: 121803, LMS0) died unexpectedly
PMON (ospid: 121662): terminating the instance due to error 12752
2024-04-12T13:25:56.639707+08:00
System state dump requested by (instance=2, osid=121662 (PMON)), summary=[abnormal instance termination].
System State dumped to trace file /u01/app/oracle/diag/rdbms/odb/odb2/trace/odb2_diag_121779_20240412132556.trc
2024-04-12T13:25:58.324925+08:00
License high water mark = 59
2024-04-12T13:26:02.603406+08:00
Instance terminated by PMON, pid = 121662
2024-04-12T13:26:02.605425+08:00
Warning: 2 processes are still attach to shmid 767295519:
(size: 40960 bytes, creator pid: 121556, last attach/detach pid: 121779)
2024-04-12T13:26:03.325760+08:00
USER (ospid: 64081): terminating the instance
2024-04-12T13:26:03.326130+08:00
Instance terminated by USER, pid = 64081
2024-04-12T13:26:04.956513+08:00
Starting ORACLE instance (normal) (OS id: 64183)
```

Data Collection from file "odb2_lms0_121803.trc"
```
Trace file /u01/app/oracle/diag/rdbms/odb/odb2/trace/odb2_lms0_121803.trc
Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production
Build label: RDBMS_12.2.0.1.0_LINUX.X64_170125
ORACLE_HOME: /u01/app/oracle/product/12.2.0/db
System name: Linux
Node name: host7
Release: 4.4.21-69-default
Version: #1 SMP Tue Oct 25 10:58:20 UTC 2016 (9464f67)
Machine: x86_64
Instance name: odb2
Redo thread mounted by this instance: 0 <none>
Oracle process number: 24
Unix process pid: 121803, image: oracle@host7 (LMS0)

...
* drm (1453) window 1 - lms post-acks mtobep
2024-04-12T13:25:46.266433+08:00
Incident 25793 created, dump file: /u01/app/oracle/diag/rdbms/odb/odb2/incident/incdir_25793/odb2_lms0_121803_i25793.trc
ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553], [], [], [], [], [], [], [], [], [], []

kjmpbmsg: caught non-fatal error 600
kjmpbmsg fatal error on 86

...
```


## Cause  
The database alert log reported "ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553]", causing an abnormal restart of the database instance.  

Tracefile odb2_lms0_121803_i25793.trc shows the following error:
```
ORA-00600 [kclantilock_17] [25770556553]
```

This error looks like it may be due to an issue described in one of the following documents. Please review the documents to see if the situation matches, and for details of possible workarounds / fixes:  

Note:27162390.8 [ Bug:27162390 ] RAC LMS Process Hits ORA-600 [kclantilock_17] Error and Instance Crashes  
Reasons:  
~ Trace shows ORA-600 [kclantilock_17]  
~ Issue affects this version (12.2.0.1)  
+ Trace stack includes function "kclantilock"  
+ Trace stack includes function "kjblprmexp"  
+ Trace stack includes function "kjbmprmexp"  
This bug may be less relevant as:  
- Issue is RAC specific but it is not clear from the trace that RAC is active  


Note:33896423.8 [ Bug:33896423 ] [RAC] Flush Out Stale Antilocks and Convert kclcls_2 and kclantilock_17 to Soft Assert  
Reasons:  
~ Trace shows ORA-600 [kclantilock_17]  
~ Issue affects this version (12.2.0.1)  
This bug may be less relevant as:  
- Issue is RAC specific but it is not clear from the trace that RAC is active  

## Solution  
Disabling GCS read-mostly locking.  

-- Dynamic workaround  
alter system set "_lm_drm_disable"=4;  
oradebug setmypid  
oradebug lkdebug -m reconfig disrm  

-- Static workaround  
alter system set "_gc_read_mostly_locking"=false scope=spfile sid='*' ;  
alter system set "_gc_persistent_read_mostly"=false scope=spfile sid='*' ;  

Note that disabling read mostly can have a negative performance impact (higher cpu and interconnect traffic) if the application/db has a lot of "read only" or "read mostly" objects.  

## References  
Bug 33896423 - [RAC] Flush Out Stale Antilocks and Convert kclcls_2 and kclantilock_17 to Soft Assert (Doc ID 33896423.8)  
Bug 27162390 - RAC LMS Process Hits ORA-600 [kclantilock_17] Error and Instance Crashes (Doc ID 27162390.8)  
