---
layout: post
title: "ADG Standby Database Hung I/O"
excerpt: "Standby instance 1 was accessible and could execute query SQL, but executing `alter database recover managed standby cancel;` had no response. tnsping cdbdg was normal. The standby database returned to normal after restart."
date: 2025-07-31 11:00:00 +0800
categories: [Oracle, Database]
tags: [process hung, Wait Event, Error 12609, ORA-12609, hung on an I/O, High Waits, oracle]
image: /assets/images/posts/ADG-Standby-Database-Hung-IO.jpg
---

## Problem Description  
Database Version: oracle 19.12  
ADG standby database, experienced two consecutive hangs on 11/29 and 12/9.  
The alert log of the node where the MRP process resides continuously reported:  
```
TMON (PID:63853): WARN: Terminating process hung on an operation (PID:47391)
2024-11-29T13:56:06.994326+08:00
TMON (PID:63853): Process (PID:49286) hung on an I/O after 1068 seconds with threshold of 240 at [krsh.c:2867]
TMON (PID:63853): WARN: Terminating process hung on an operation (PID:49286)
2024-11-29T13:56:09.108848+08:00
TMON (PID:63853): Process (PID:50743) hung on an I/O after 1041 seconds with threshold of 240 at [krsh.c:2867]
TMON (PID:63853): WARN: Terminating process hung on an operation (PID:50743)
```

Primary database reported:  
```
ORA-12609：TNS:Receive timeout occurred
TT04 (PID:44614);Error 12609 for LNO:5 to 'cdbdg'
```
Standby instance 1 was accessible and could execute query SQL, but executing `alter database recover managed standby cancel;` had no response. tnsping cdbdg was normal. The standby database returned to normal after restart.  

ERROR
-----------------------
```
2024-12-09T06:49:13.120319+08:00
TMON (PID:98459): Process (PID:4809) hung on an I/O after 250 seconds with threshold of 240 at [krsh.c:2867]
TMON (PID:98459): WARN: Terminating process hung on an operation (PID:4809)
2024-12-09T06:49:17.360617+08:00
TMON (PID:98459): Killing 1 processes (PIDS:4809) (Process by index) in order to remove hung processes. Requested by OS process 98459 on instance 1
2024-12-09T06:49:17.361119+08:00
Process termination requested for pid 4809 [source = rdbms], [info = 2] [request issued by pid: 98459, uid: 1001]
```

## Problem Analysis  

**Collect TFA Information from Primary and Standby:**  
On PRIMARY: as the RDBMS/DB homeowner, run the TFA collection using the following command:  
$TFA_HOME/bin/tfactl diagcollect -srdc dbdataguard  

On STANDBY: as the RDBMS/DB homeowner, run the TFA collection using the following command:  
$TFA_HOME/bin/tfactl diagcollect -srdc dbdataguard  


==============================  
**System Configuration Update**  
=============================  
```
OS Details
OS Platform : Linux
OS Parameter : Refer to file: oda2acc01_os_report in the TFA collection(s)
OS Version : Oracle Linux Server release 7.9
OS Kernel : 4.14.35-2047.505.4.3.el7uek.x86_64
**********************************
Exadata Details
Exadata Cell Names : {EXADATA_CELL_NAMES}*
Exadata DB Node Version : {EXADATA_DB_NODE_VERSION_REVISION}*
Exadata Hardware Version : {EXADATA_HARDWARE_VERSION}*
Oracle Home : Refer to file: oda2acc01_OPATCH_DBHOMES in the TFA collection(s)
Exadata HW Serial No : {EXADATA_HARDWARE_SERIAL}*
**********************************
Cluster Details
Cluster Node Name : {CLUSTER_NODE_NAMES}
Grid Infrastructure (GI) Home : /u01/app/19.12.0.0/grid
GI Version : 19.12.0.0.0
**********************************
Database Details
Database Count :
DB Home / DB Version / DB Names -
/u01/app/odaorahome/oracle/product/19.0.0.0/dbhome_1 - 19.12.0.0.0 - 3 databases
/u01/app/odaorahome/oracle/product/12.2.0.1/dbhome_1 - 12.2.0.1.0 - 2 databases
```

**From alert_.log:**
```
2024-12-09T06:45:03.125201+08:00
rfs (PID:4809): Selected LNO:22 for T-1.S-213920 dbid 3054843085 branch 1129541200 ★★★ rfs (PID:4809)

2024-12-09T06:46:42.738693+08:00
rfs (PID:24689): krsr_rfs_atc: Identified database type as 'PHYSICAL STANDBY': Client is ASYNC (PID:41789)
rfs (PID:24689): Primary database is in MAXIMUM PERFORMANCE mode

2024-12-09T06:46:47.957078+08:00
rfs (PID:24870): krsr_rfs_atc: Identified database type as 'PHYSICAL STANDBY': Client is ASYNC (PID:44614)
rfs (PID:24870): Primary database is in MAXIMUM PERFORMANCE mode

2024-12-09T06:49:13.120319+08:00
`TMON (PID:98459): Process (PID:4809) hung on an I/O after 250 seconds with threshold of 240 at [krsh.c:2867] ★★★ The process hung on I/O is rfs`
TMON (PID:98459): WARN: Terminating process hung on an operation (PID:4809)
2024-12-09T06:49:17.360617+08:00
TMON (PID:98459): Killing 1 processes (PIDS:4809) (Process by index) in order to remove hung processes. Requested by OS process 98459 on instance 1
2024-12-09T06:49:17.361119+08:00
Process termination requested for pid 4809 [source = rdbms], [info = 2] [request issued by pid: 98459, uid: 1001]

2024-12-09T06:50:49.888168+08:00
TMON (PID:98459): Process (PID:24689) hung on an I/O after 247 seconds with threshold of 240 at [krsh.c:2867]
TMON (PID:98459): WARN: Terminating process hung on an operation (PID:24689)
2024-12-09T06:50:52.003731+08:00
TMON (PID:98459): Process (PID:24870) hung on an I/O after 244 seconds with threshold of 240 at [krsh.c:2867]
TMON (PID:98459): WARN: Terminating process hung on an operation (PID:24870)
```

**Comment**
---------
The hung process each time is rfs.


**-- Trace File --**

File Name or Source
-------------------------
`cdb1_rfs_4809.trc`

```
Relevant Information Collection
---------------------------------------
*** 2024-12-09T06:43:21.039203+08:00 (CDB$ROOT(1))
*** 2024-12-09 06:43:21.039191 [krsr.c:16852]
krsr_dump_alert_msg: Archival completed for LNO:21 T-1.S-213917 dbid 3054843085 branch 1129541200
*** 2024-12-09 06:43:21.057349 [krsr.c:16840]
krsr_dump_alert_msg: Header received for LNO:22 T-1.S-213918 dbid 3054843085 branch 1129541200

*** 2024-12-09T06:44:12.133379+08:00 (CDB$ROOT(1))
*** 2024-12-09 06:44:12.133368 [krsr.c:16852]
krsr_dump_alert_msg: Archival completed for LNO:22 T-1.S-213918 dbid 3054843085 branch 1129541200
*** 2024-12-09 06:44:12.154730 [krsr.c:16840]
krsr_dump_alert_msg: Header received for LNO:21 T-1.S-213919 dbid 3054843085 branch 1129541200

*** 2024-12-09T06:45:03.109216+08:00 (CDB$ROOT(1))
*** 2024-12-09 06:45:03.109205 [krsr.c:16852]
krsr_dump_alert_msg: Archival completed for LNO:21 T-1.S-213919 dbid 3054843085 branch 1129541200
Process termination requested for pid 4809 [source = rdbms], [info = 2] [request issued by pid: 98459, uid: 1001] ★★★ last line

*** 2024-12-09T06:45:35.993253+08:00 (CDB$ROOT(1))
`HM: Early Warning - Session ID 4142 serial# 52788 OS PID 4809 (FG) ★★★ 4809`
is waiting on 'reliable message' for 32 seconds, wait id 333783272
p1: 'channel context'=0x6403deca90, p2: 'channel handle'=0x195ea23b0, p3: 'broadcast message'=0x6403e350f8
Enclosing wt evt 'RFS create'
`Final Blocker is Session ID 7333 serial# 32476 on instance 2`

IO
Total Self- Total Total Outlr Outlr Outlr
Hung Rslvd Rslvd Wait WaitTm Wait WaitTm Wait
Sess Hangs Hangs Count Secs Count Secs Count Wait Event
------ ------ ------ ------ ------ ------ ------ ------ -----------
1 0 0 93712599 18397 1 1536 0 reliable message


HM: Dumping Short Stack of pid[150.4809] (sid:4142, ser#:52788)
Short stack dump:
ksedsts()+426<-ksdxfstk()+58<-ksdxcb()+872<-sspuser()+223<-__sighandler()<-semtimedop()+10<-skgpwwait()+192<-ksliwat()+2199<-kslwaitctx()+205<-ksrpubwait_ctx()+1131<-ksbxicpoll()+183<-krsh_rwc()+1816<-krss_req_xpt_asyncsrl_stop()+155<-krsw_srl_startup()+374<-krsr_rfs_oda()+15973<-krsr_rfs_dsp()+4472<-opirfs()+1417<-opiodr()+1202<-ttcpip()+1231<-opitsk()+1900<-opiino()+936<-opiodr()+1202<-opidrv()+1094<-sou2o()+165<-opimai_real()+422<-ssthrdmain()+417<-main()+256<-__libc_start_main()+245

HM: Current SQL: none


...
```

**Comment**
==============
Final Blocker is Session ID 7333 serial# 32476 on instance 2


File Name or Source
-------------------------
`cdb2_gen0_33151.trc`

```
Description
--------------
Instance 2 gen0 trace

Relevant Information Collection
---------------------------------------
*** 2024-11-29T13:57:57.599448+08:00 (CDB$ROOT(1))
*** SESSION ID:(7333.32476) 2024-11-29T13:57:57.599513+08:00 ★★★ (7333.32476), final blocker of instance 1 rfs process
*** CLIENT ID:() 2024-11-29T13:57:57.599525+08:00
*** SERVICE NAME:() 2024-11-29T13:57:57.599535+08:00
*** MODULE NAME:() 2024-11-29T13:57:57.599545+08:00
*** ACTION NAME:() 2024-11-29T13:57:57.599555+08:00
*** CLIENT DRIVER:() 2024-11-29T13:57:57.599564+08:00
*** CONTAINER ID:(1) 2024-11-29T13:57:57.599575+08:00

*** 2024-12-09T05:51:37.974313+08:00 (CDB$ROOT(1))
kjznppl0: database in migration or not writable
kjznppl0: database in migration or not writable
kjznppl0: database in migration or not writable

*** 2024-12-09T06:21:39.054708+08:00 (CDB$ROOT(1))
kjznppl0: database in migration or not writable
kjznppl0: database in migration or not writable
kjznppl0: database in migration or not writable

*** 2024-12-09T06:44:49.517039+08:00 (CDB$ROOT(1))
Setting Resource Manager CDB plan DEFAULT_CDB_PLAN via parameter
IPCLW:[0.0]{-}[WAIT]:PROTO: [1733697889520699]ipclw_data_chunk_process:1165 Discarding msg with seq # 3369647172, expecting 853971411
IPCLW:[0.1]{-}[WAIT]:PROTO: [1733697890199144]ipclw_data_chunk_process:1165 Discarding msg with seq # 3369647703, expecting 853971411

*** 2024-12-09T06:44:50.712530+08:00 (CDB$ROOT(1))
IPCLW:[0.2]{-}[WAIT]:PROTO: [1733697890712505]ipclw_data_chunk_process:1165 Discarding msg with seq # 3369648109, expecting 853971411
IPCLW:[0.3]{-}[WAIT]:PROTO: [1733697891232103]ipclw_data_chunk_process:1165 Discarding msg with seq # 3369648464, expecting 853971411

...

*** 2024-12-09T07:39:59.693288+08:00 (CDB$ROOT(1))
IPCLW:[0.6013]{-}[WAIT]:PROTO: [1733701199693264]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370444877, expecting 853971411
IPCLW:[0.6014]{-}[WAIT]:PROTO: [1733701200208270]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445253, expecting 853971411

*** 2024-12-09T07:40:00.748327+08:00 (CDB$ROOT(1))
IPCLW:[0.6015]{-}[WAIT]:PROTO: [1733701200748304]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445482, expecting 853971411
`IPCLW:[0.6016]{-}[WAIT]:PROTO: [1733701201298371]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445483, expecting 853971411 ★★★ last line`
```

Based on the log analysis, when the problem occurred, the rfs process on standby 'instance 1' was hung, triggering the Warning message in the alert log.  

At that time, the rfs process on 'instance 1' had a blocker, confirmed by dia0 to be the gen0 process on 'instance 2'.  

`From cdb1_dia0_98019_lws_1.trc`
```
*** 2024-12-09T06:45:35.993253+08:00 (CDB$ROOT(1))
HM: Early Warning - Session ID 4142 serial# 52788 OS PID 4809 (FG) ★★★ 4809, this should be the rfs process on instance 1
is waiting on 'reliable message' for 32 seconds, wait id 333783272
p1: 'channel context'=0x6403deca90, p2: 'channel handle'=0x195ea23b0, p3: 'broadcast message'=0x6403e350f8
Enclosing wt evt 'RFS create'
Final Blocker is Session ID 7333 serial# 32476 on instance 2 ★★★ Final Blocker is 7333.32476 on instance 2
```

`From cdb2_gen0_33151.trc:`
```
*** SESSION ID:(7333.32476) 2024-11-29T13:57:57.599513+08:00 ★★★ (7333.32476), final blocker of instance 1 rfs process

*** 2024-12-09T07:40:00.748327+08:00 (CDB$ROOT(1))
IPCLW:[0.6015]{-}[WAIT]:PROTO: [1733701200748304]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445482, expecting 853971411
IPCLW:[0.6016]{-}[WAIT]:PROTO: [1733701201298371]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445483, expecting 853971411 ★★★ last line
```

However, with the above information, the root cause of the problem cannot yet be confirmed. (These traces do not contain more helpful information)  

## Problem Analysis Summary  
When the problem occurred, the rfs process on standby 'instance 1' was hung, triggering the Warning message in the alert log.  
At that time, the rfs process on 'instance 1' had a blocker, confirmed by dia0 to be the gen0 process on 'instance 2'.  

`From cdb1_dia0_98019_lws_1.trc：`  
```
*** 2024-12-09T06:45:35.993253+08:00 (CDB$ROOT(1))
HM: Early Warning - Session ID 4142 serial# 52788 OS PID 4809 (FG) ★★★ 4809, this should be the rfs process on instance 1
is waiting on 'reliable message' for 32 seconds, wait id 333783272
p1: 'channel context'=0x6403deca90, p2: 'channel handle'=0x195ea23b0, p3: 'broadcast message'=0x6403e350f8
Enclosing wt evt 'RFS create'
Final Blocker is Session ID 7333 serial# 32476 on instance 2 ★★★ Final Blocker is 7333.32476 on instance 2
```

`From cdb2_gen0_33151.trc:`  
```
*** SESSION ID:(7333.32476) 2024-11-29T13:57:57.599513+08:00 ★★★ (7333.32476), final blocker of instance 1 rfs process

*** 2024-12-09T07:40:00.748327+08:00 (CDB$ROOT(1))
IPCLW:[0.6015]{-}[WAIT]:PROTO: [1733701200748304]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445482, expecting 853971411
IPCLW:[0.6016]{-}[WAIT]:PROTO: [1733701201298371]ipclw_data_chunk_process:1165 Discarding msg with seq # 3370445483, expecting 853971411 ★★★ last line
```

In summary, when the problem occurred, the rfs process was hung, and the final blocker was the gen0 process.  

This phenomenon is similar to the following 2 bugs:  

---
++ Bug 34019478 : 19.13 ERROR 3135 - ERROR 16198 DUE TO HUNG I/O OPERATION -- Fixed in 19.18 DBRU RFS hung duo to resilver during mid-connection of SRL. Register a TAC callback routine for some time.  

++ Bug 33633469 - TMON hung on an I/O after <nnn> seconds with threshold of 240 ( Doc ID 33633469.8 ) -- Fixed in 19.17 DBRU From the hang analysis, The final blocker will be Gen0 waiting on 'enq :RF - synch: DG Broker metadata'.  

---

These 2 bugs were fixed in the 19.18 DBRU.  

## Recommendation  
It is recommended to upgrade to 19.18 or the latest DBRU.  

Regarding the patch fix strategy for Oracle Database 19c:  
Oracle Database 19c on-premise version was released in April 2019.  

1. Within the first 3 years after the official release of Oracle Database 19c, that is, from April 2019 to the 19.14 RU version released in January 2022, patch support services are available for 1 year.  
2. After the first 3 years of the official release of Oracle Database 19c, starting from April 2022, the RU versions 19.15 and higher receive patch support services for 2 years.  
3. Currently, patch support services for RU versions 19.3 to 19.17 have ended. You can still download and install published patch fixes, but no new fixes will be provided.  
4. Currently, RU versions 19.18 and higher still accept new patch fix requests. The following is the end time of patch support services for each RU version:  

- 19.18 Patch Support Service End Time: January 2025  
- 19.19 Patch Support Service End Time: April 2025  
- 19.20 Patch Support Service End Time: July 2025  
- 19.21 Patch Support Service End Time: October 2025  
- 19.22 Patch Support Service End Time: January 2026  
- 19.23 Patch Support Service End Time: April 2026  
- 19.24 Patch Support Service End Time: July 2026  
- 19.25 Patch Support Service End Time: October 2026  

For detailed patch correction policies, please refer to:  
Database, FMW, Enterprise Manager, TimesTen In-Memory Database, and OCS Software Error Correction Support Policy ( Doc ID 209768.1 )
