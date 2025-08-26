---
layout: post
title: "ADG SWITCHOVER Switching to New Standby Reports Password File Mismatch"
excerpt: "After the original primary issued alter database switchover to escfsdb;, the new primary started normally.
The new standby (original primary) started MRP and reported the following error: MRP0:Background Media Recovery terminated with error 46952"
date: 2025-08-26 15:00:00 +0800
categories: [ORA-46952, Oracle, Database]
tags: [mismtch for password, oracle]
image: /assets/images/posts/ADG-SWITCHOVER-Switching-to-New-Standby-Reports-Password-File-Mismatch.jpg
---

## Problem Description  
Oracle 12.2 RAC ADG switchover primary/standby switch.  
After the original primary issued `alter database switchover to escfsdb;`, the new primary started normally.  
The new standby (original primary) started MRP and reported the following error:  
```
MRP0:Background Media Recovery terminated with error 46952
2023-09-17T00:09:43.472636+08:00
Errors in file /u01/app/oracle/diag/rdbms/ef/ef1/trace/ef1_pr00_221142.trc:
ORA-46952:standby database format mismtch for password file '+DATAC1/ef/PASSWORD/pwdef.359.1001353187'
```

## Analysis  
Primary, DB alert log  
```
Starting ORACLE instance (normal) (OS id: 214994)
2023-09-17T00:08:51.478593+08:00
CLI notifier numLatches:131 maxDescs:5068
2023-09-17T00:08:51.481305+08:00

2023-09-17T00:08:51.481378+08:00
Dump of system resources acquired for SHARED GLOBAL AREA (SGA)

...

2023-09-17T00:09:22.805928+08:00
replication_dependency_tracking turned off (no async multimaster replication found)
Physical standby database opened for read only access.
Completed: ALTER DATABASE OPEN /* db agent *//* {1:25046:29480} */

...

2023-09-17T00:09:42.104231+08:00
Archived Log entry 747327 added for thread 1 sequence 187866 rlc 1001353316 ID 0xf03f7b79 LAD2 :
2023-09-17T00:09:42.454884+08:00
Completed: alter database recover managed standby database using current logfile disconnect from session
2023-09-17T00:09:42.510539+08:00

...

2023-09-17T00:09:43.353601+08:00
Media Recovery Waiting for thread 2 sequence 184825 (in transit)
2023-09-17T00:09:43.357045+08:00
Recovery of Online Redo Log: Thread 2 Group 31 Seq 184825 Reading mem 0
Mem# 0: +DATAC1/ef/ONLINELOG/group_31.443.1011206587
MRP0: Background Media Recovery terminated with error 46952
2023-09-17T00:09:43.472636+08:00
Errors in file /u01/app/oracle/diag/rdbms/ef/ef1/trace/ef1_pr00_221142.trc:
ORA-46952: standby database format mismatch for password file '+DATAC1/ef/PASSWORD/pwdef.359.1001353187' <<<<<<< Here
2023-09-17T00:09:43.474426+08:00
Managed Standby Recovery not using Real Time Apply
2023-09-17T00:09:43.755738+08:00
Clearing online redo logfile 3 complete
Clearing online redo logfile 4 +DATAC1/ef/ONLINELOG/group_4.372.1001353523
```
This phenomenon of ours is a good match for "Standby Database MRP Fails With ORA-46952: Standby Database Format Mismatch For Password ( Doc ID 2503352.1 )". The final solution is to copy the password file from the primary database to the standby database.  

## Solution  
1- Rename all password files on standby.  
2- Start the archive apply:  
```
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```
3- Copy the password file from production node 1 to standby.  
Since version 12.2 is already out of premier support, it is recommended to upgrade to version 19c as soon as possible. Thank you.  

## REFERENCE INFORMATION  
Standby Database MRP Fails With ORA-46952: Standby Database Format Mismatch For Password (Doc ID 2503352.1)  
