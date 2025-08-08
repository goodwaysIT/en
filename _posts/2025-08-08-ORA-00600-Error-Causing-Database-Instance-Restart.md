---
layout: post
title: "ORA-00600 エラーによるデータベースインスタンスの再起動"
excerpt: "データベースアラートログに ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553] が記録され、データベースインスタンスの異常な再起動を引き起こしました。"
date: 2025-08-08 14:30:00 +0800
categories: [Oracle, Database]
tags: [ORA-00600, kclantilock_17, error 12752, terminating the instance, oracle]
image: /assets/images/posts/ORA-00600-Error-Causing-Database-Instance-Restart.jpg
---

## 症状  
DBバージョン: 12.2.0.1  
プラットフォーム: Linux (x86_64) OS-Version 4.4.21-69-default  

ログファイル  
-----------------------  
ファイル名 = alert_odb2.log  
以下のエラーを確認:  
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

ファイル "odb2_lms0_121803.trc" からのデータ収集  
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

drm (1453) window 1 - lms post-acks mtobep
2024-04-12T13:25:46.266433+08:00
Incident 25793 created, dump file: /u01/app/oracle/diag/rdbms/odb/odb2/incident/incdir_25793/odb2_lms0_121803_i25793.trc
ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553], [], [], [], [], [], [], [], [], [], []

kjmpbmsg: caught non-fatal error 600
kjmpbmsg fatal error on 86

...

```


## 原因  
データベースアラートログに "ORA-00600: internal error code, arguments: [kclantilock_17], [25770556553]" が記録され、データベースインスタンスの異常な再起動を引き起こしました。  

トレースファイル odb2_lms0_121803_i25793.trc には以下のエラーが示されています:  
```
ORA-00600 [kclantilock_17] [25770556553]  
```

このエラーは、以下のいずれかのドキュメントで説明されている問題による可能性があります。状況が一致するか確認し、回避策/修正の詳細についてはドキュメントを参照してください:  

Note:27162390.8 [ Bug:27162390 ] RAC LMSプロセスがORA-600 [kclantilock_17]エラーを発生させインスタンスがクラッシュする  
理由:  
~ トレースに ORA-600 [kclantilock_17] が表示  
~ このバージョン(12.2.0.1)に影響  
+ トレーススタックに関数 "kclantilock" が含まれる  
+ トレーススタックに関数 "kjblprmexp" が含まれる  
+ トレーススタックに関数 "kjbmprmexp" が含まれる  
関連性が低い可能性:  
- 問題はRAC固有だが、トレースからRACがアクティブか不明  

Note:33896423.8 [ Bug:33896423 ] [RAC] 古いAntilockをフラッシュし、kclcls_2とkclantilock_17をソフトアサートに変換  
理由:  
~ トレースに ORA-600 [kclantilock_17] が表示  
~ このバージョン(12.2.0.1)に影響  
関連性が低い可能性:  
- 問題はRAC固有だが、トレースからRACがアクティブか不明  

## 解決策  
GCS読み取り専用ロックを無効化します。  

-- 動的な回避策  
alter system set "_lm_drm_disable"=4;  
oradebug setmypid  
oradebug lkdebug -m reconfig disrm  

-- 静的な回避策  
alter system set "_gc_read_mostly_locking"=false scope=spfile sid='*' ;  
alter system set "_gc_persistent_read_mostly"=false scope=spfile sid='*' ;  

注意: 読み取り専用を無効にすると、アプリケーション/DBに多数の「読み取り専用」または「読み取りが主」オブジェクトがある場合、パフォーマンスに悪影響（CPUとインターコネクトのトラフィック増加）が出る可能性があります。  

## 関連情報  
Bug 33896423 - [RAC] 古いAntilockをフラッシュし、kclcls_2とkclantilock_17をソフトアサートに変換 (Doc ID 33896423.8)  
Bug 27162390 - RAC LMSプロセスがORA-600 [kclantilock_17]エラーを発生させインスタンスがクラッシュする (Doc ID 27162390.8)  
