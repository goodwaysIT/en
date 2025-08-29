---
layout: post
title: "ORACLE 12c and 19c Coexistence System, DBCA Reports Error"
excerpt: "The current system is a coexistence system of 12c and 19c. The cluster is 19C, DBs are 19c+12c. The software is under different users: 19c (ORACLE user), 12c (oracle2 user).Now, when running DBCA to create a database in the 12c environment, the following error is reported:DBT-00007 Users does not have the appropiate write privileges ."
date: 2025-08-29 15:00:00 +0800
categories: [Oracle, Database, RAC]
tags: [PRVF-7595, PRVG-2043, DBT-00007, rac, oracle]
image: /assets/images/posts/ORACLE-12c-and-19c-Coexistence-System-DBCA-Reports-Error.jpg
---

## Symptoms  
The current system is a coexistence system of 12c and 19c. The cluster is 19C, DBs are 19c+12c. The software is under different users: 19c (ORACLE user), 12c (oracle2 user).  
Now, when running DBCA to create a database in the 12c environment, the following error is reported:  
```
DBT-00007 Users does not have the appropiate write privileges .  
```
Afterwards, the CRS Check reported the following error:  
```
PRVF-7595 : CRS status check cannot be performed on node "xxxx"
PRVG-2043 : Command "/u01/app/19.7.0.0/grid/bin/crs_stat -t " failed on node "xxxx"
```

## Cause  
```
Check the permissions of files like `$ORACLE_BASE/cfgtoollogs/dbca`
node-a:~ # id -a oracle2
uid=54323(oracle2) gid=54421(oinstall) groups=54322(dba),54327(asmdba),54421(oinstall)
node-a:~ # su - oracle2
oracle2@node-a:/home/oracle2$ echo $ORACLE_BASE
/u01/app/oracle
oracle2@node-a:/home/oracle2$ ls -la $ORACLE_BASE/cfgtoollogs
total 0
drwxr-x--- 4 oracle oinstall 34 May 22 14:46 .
drwxrwxr-x 10 oracle oinstall 126 May 22 15:09 ..
drwxr-x--- 3 oracle oinstall 98 Jun 14 14:29 dbca
drwxr-x--- 9 oracle oinstall 249 May 22 15:21 sqlpatch
node-a:~ # id -a grid
uid=54322(grid) gid=54421(oinstall) groups=54327(asmdba),54328(asmoper),54329(asmadmin),54330(racdba),54421(oinstall)
node-a:~ # id -a oracle
uid=54321(oracle) gid=54421(oinstall) groups=54322(dba),54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54327(asmdba),54328(asmoper),54330(racdba),54421(oinstall)
node-a:~ # su - grid
grid@node-a:/home/grid$ echo $ORACLE_BASE
/u01/app/grid
grid@node-a:/home/grid$ ls -la $ORACLE_BASE/cfgtoollogs
ls: cannot access '$ORACLE_BASE/cfgtoollogs': No such file or directory
grid@node-a:/home/grid$ ls -la $ORACLE_BASE/cfgtoollogs
total 0
drwxrwxr-x 9 grid oinstall 102 May 10 15:08 .
drwxrwxr-x 8 grid oinstall 97 May 11 10:13 ..
drwxr-x--- 2 grid oinstall 298 May 11 16:03 asmca
drwxr-x--- 4 grid oinstall 36 May 10 15:21 dbca
drwxrwxr-x 2 grid oinstall 156 May 10 15:23 mgmtca
drwxrwxr-x 2 grid oinstall 6 May 10 14:52 mgmtua
drwxr-x--- 2 grid oinstall 142 May 10 15:04 netca
drwxrwxr-x 2 grid oinstall 6 May 10 14:52 restca
drwxr-x--- 6 grid oinstall 174 May 10 15:22 sqlpatch
grid@node-a:/home/grid$ exit
logout
node-a:~ # su - oracle
oracle@node-a:/home/oracle$ echo $ORACLE_BASE
/u01/app/oracle
oracle@node-a:/home/oracle$ ls -la $ORACLE_BASE/cfgtoollogs
total 0
drwxr-x--- 4 oracle oinstall 34 May 22 14:46 .
drwxrwxr-x 10 oracle oinstall 126 May 22 15:09 ..
drwxr-x--- 3 oracle oinstall 98 Jun 14 14:29 dbca
drwxr-x--- 9 oracle oinstall 249 May 22 15:21 sqlpatch
```

The CRS Check reported the following error:  
```
PRVF-7595 : CRS status check cannot be performed on node "node-b" - Cause: Could not verify the status of CRS on the node indicated using ''crsctl check''. - Action: Ensure the ability to communicate with the specified node. Make sure that Clusterware daemons are running using ''ps'' command. Make sure that the Clusterware stack is up.
PRVG-2043 : Command "/u01/app/19.7.0.0/grid/bin/crs_stat -t " failed on node "node-b" and produced the following output: /u01/app/19.7.0.0/grid/bin/crs_stat.bin: error while loading shared libraries: libocr12.so: cannot open shared object file: No such file or directory - Cause: An executed command failed. - Action: Respond based on the failing command and the reported results.
```
The error during CRS CHECK indicates there is an incompatible command between the 12c DB and the 19c Grid.  

## Solution  
1. Check and ensure the CRS are truly running on all nodes .  
2. Ignore this error if CRS is running fine on all nodes.  
3. Continue to run installer.  
Or you can use workaround:  
$ export ORA_DISABLED_CVU_CHECKS=TASKCRSINTEGRITY,TASKNTP,STASKRESOLVCONFINTEGRITY  
$ echo ORA_DISABLED_CVU_CHECKS  

Reset the user and permissions for `/u01`.  
Example:  
```
chown -R oracle2:oinstall /u01
chmod -R 775 /u01
```

## REFERENCE INFORMATION  
DBCA Database Creation Fails With Error PRCR-1154 Due to Wrong Ownership/Permission (Doc ID 2165706.1)  
