---
layout: post
title: "ADG SWITCHOVER 新スタンバイへの切り替えでパスワードファイルの不一致が報告される"
excerpt: "元のプライマリが alter database switchover to escfsdb; を発行した後、新しいプライマリは正常に起動しました。
新しいスタンバイ（元のプライマリ）はMRPを開始し、次のエラーを報告しました: MRP0:Background Media Recovery terminated with error 46952"
date: 2025-08-26 15:00:00 +0800
categories: [ORA-46952, Oracle, Database]
tags: [mismtch for password, oracle]
image: /assets/images/posts/ADG-SWITCHOVER-Switching-to-New-Standby-Reports-Password-File-Mismatch.jpg
---

## 問題の説明  
Oracle 12.2 RAC ADG のスイッチオーバーによるプライマリ/スタンバイの切り替え。  
元のプライマリが alter database switchover to escfsdb; を発行した後、新しいプライマリは正常に起動しました。  
新しいスタンバイ（元のプライマリ）がMRPを開始し、次のエラーを報告しました:  
```
MRP0:Background Media Recovery terminated with error 46952
2023-09-17T00:09:43.472636+08:00
Errors in file /u01/app/oracle/diag/rdbms/ef/ef1/trace/ef1_pr00_221142.trc:
ORA-46952:standby database format mismtch for password file '+DATAC1/ef/PASSWORD/pwdef.359.1001353187'
```

## 分析  
プライマリDBのアラートログ  
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
ORA-46952: standby database format mismatch for password file '+DATAC1/ef/PASSWORD/pwdef.359.1001353187' <<<<<<< ここ
2023-09-17T00:09:43.474426+08:00
Managed Standby Recovery not using Real Time Apply
2023-09-17T00:09:43.755738+08:00
Clearing online redo logfile 3 complete
Clearing online redo logfile 4 +DATAC1/ef/ONLINELOG/group_4.372.1001353523
```
この現象は、「Standby Database MRP Fails With ORA-46952: Standby Database Format Mismatch For Password ( Doc ID 2503352.1 )」に非常によく一致しています。最終的な解決策は、プライマリデータベースからパスワードファイルをスタンバイデータベースにコピーすることです。  

## 解決策  
1- スタンバイ上のすべてのパスワードファイルの名前を変更します。  
2- アーカイブ適用を開始します:  
```
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```
3- 本番ノード1からスタンバイにパスワードファイルをコピーします。  
バージョン12.2はすでにプレミアサポートが終了しているため、できるだけ早くバージョン19cにアップグレードすることをお勧めします。ありがとうございました。  

## 参考情報  
Standby Database MRP Fails With ORA-46952: Standby Database Format Mismatch For Password (Doc ID 2503352.1)  
