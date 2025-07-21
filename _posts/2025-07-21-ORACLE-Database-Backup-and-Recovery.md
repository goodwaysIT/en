---
layout: post
title: "ORACLE Database Backup and Recovery (Multi-Scenario)"
excerpt: "Ensure the effectiveness of backups to prevent data loss caused by hardware failures, application logic errors, human operational mistakes, viruses, hacker attacks, etc."
date: 2025-07-21 17:00:00 +0800
categories: [Oracle, Database]
tags: [Database Backup, ADG, Database Recovery, Disaster Recovery, Logical Replication, Physical Replication, oracle]
image: /assets/images/posts/ORACLE-Database-Backup-and-Recovery.jpg
---

## 1. Purpose  
Ensure the effectiveness of backups to prevent data loss caused by hardware failures, application logic errors, human operational mistakes, viruses, hacker attacks, etc.  
When issues occur, proficiently and quickly recover relevant data to minimize data loss risk, aiming for zero data loss (Recovery Point Objective, RPO=0), and achieve rapid data restoration (Recovery Time Objective, RTO as low as possible).  

## 2. Common ORACLE Database Backup Methods  
Physical Backup (rman/alter tablespace begin backup/flashback/cold copy)  
Logical Backup (exp/expdp/sqlloader/create table as/rename table, etc.)  

## 3. Common ORACLE Database Recovery Scenarios  
<style>
      .mypic {
            float: left;  
            margin-right: 10px;
      }
      .left-align {
            text-align: left;
    }
    table {
        width: 100%;
        border-collapse: collapse;
    }
    th, td {
        border: 1px solid black;
        padding: 8px;
        text-align: left;
    }
    th {
        background-color: #f2f2f2;
    }
</style>

| Recovery Method         | Prerequisites                          | Recovery Time | Recovery Complexity | Data Integrity |  
|:------------------------|:---------------------------------------|:--------------|:--------------------|:---------------|  
| rman backup             | Valid rman backup                      | Generally      | Generally            | Whole       |  
| expdp backup            | Valid expdp backup                     | Generally      | Easy                | Basically whole|  
| Flashback Standby       | Standby database + flashback on        | Fastest       | Generally            | Whole       |  
| Delayed Standby         | Standby database + delay apply         | Fast          | Generally            | Whole       |  

### 3.1 Fast Recovery Using ORACLE Flashback  
(Requires enabling relevant features/configurations beforehand. See "Emergency Data Recovery Scenarios" below.)  
Flashback unsupported object types:  
```SQL
- Tables that are part of a cluster  
- Materialized views  
- Advanced Queuing tables  
- Static data dictionary tables  
- System tables  
- Partitions of a table  
- Remote tables (via database link)  
```

Flashback unsupported DDL operations:  
```SQL
- ALTER TABLE ... DROP COLUMN  
- ALTER TABLE ... DROP PARTITION  
- CREATE CLUSTER  
- TRUNCATE TABLE  
- ALTER TABLE ... MOVE  
- ALTER TABLE ... ADD PARTITION  
- ALTER TABLE ... SPLIT PARTITION  
- ALTER TABLE ... DISABLE / ENABLE PRIMARY KEY  
```

Official References:  
https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-oracle-flashback.html  
Configure flashback database (Doc ID 249319.1)  
DDL, Editions and Flashback (Doc ID 2780613.1)  
Restrictions on Flashback Table Feature (Doc ID 270535.1)  
How To Flashback Primary Database In Standby Configuration (Doc ID 728374.1)  

### 3.2 Physical Database Recovery (See "Emergency Data Recovery Scenarios" below)  
Restore and Recover using RMAN (local or remote), typically for full database recovery. Recovery speed depends on backup network bandwidth, disk/tape I/O.  

### 3.3 Logical Database Recovery (Simpler, steps omitted)  
Use exp/expdp/sqlloader/create table as/rename table for logical backups, then restore with imp/impdp/sqlloader/insert into (more flexible).  

## 4. Prerequisites for Data Recovery  
Continuous availability of backup files/media (recycle bin files, full/incremental/differential backups, archive logs, online logs, etc.).  

## 5. Prerequisites for Fast Recovery of Database/Table/Deleted Data  
### 5.1 Configure and Use Oracle Flashback  
Note: Oracle Flashback allows viewing/restoring past states of databases/objects/transactions/rows without point-in-time media recovery.  
1) Enable Flashback Database (can enable only on Standby)  
2) Set Flash Recovery Area large enough  
3) Set UNDO_RETENTION parameter appropriately (for Flashback Query/Table)  

### 5.2 Configure ADG and Enable Delayed Log Apply  
ADG delay apply setup:  
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DELAY 5 DISCONNECT FROM SESSION; -- (DELAY 5 = 5-minute delay)
```
(delay 5 here means applying the log after a delay of 5 minutes)  

or  
by modifying the log_archive_dest_n parameter and using "DELAY=", for example: DELAY=5 (in minutes), which means a delay of 5 minutes  
```sql
ALTER SYSTEM SET log_archive_dest_2='service=standby reopen=60 lgwr async delay=5 valid_for=(online_logfiles,primary_role) db_unique_name=standby' SCOPE=BOTH;
```

## 6. Preventing Data Loss  
1) Run in Archivelog Mode  
2) Multiplex Control Files  
3) Perform Regular Backups  
4) Backup Data Before Deletion (ensure consistency; disconnect apps before backup)  
5) Have validated rollback plans for all DB changes; confirm acceptance by dev/business teams before execution.  
6) Periodically conduct cross-host recovery drills for various scenarios to validate backups and improve proficiency.  
7) Use Expdp/Create Table As/Rename Table for single-table logical backups.  
8) For massive changes, pre-configure ADG delay apply, Flashback Database (create restore point), or full DB backup.  

## 7. 10 Backup and Recovery Best Practices  
### 7.1 Enable Block Checking  
Detects database block corruption early with minimal performance overhead.  
```SQL
SQL> ALTER SYSTEM SET db_block_checking = TRUE SCOPE=BOTH;
```

### 7.2 Enable Block Change Tracking for RMAN Incremental Backups (10g+)  
Tracks modified blocks to avoid reading unchanged data during incremental backups.  
```SQL
SQL> ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/oradata/ora1/change_tracking.f';
```

### 7.3 Mirror Redo Log Groups/Members & Store Archive Logs in Multiple Locations  
Ensures redundancy if logs are lost/corrupted.
```SQL
SQL> ALTER SYSTEM SET log_archive_dest_2='location=/new/location/archive2' SCOPE=BOTH;
SQL> ALTER DATABASE ADD LOGFILE MEMBER '/new/location/redo21.log' TO GROUP 1;
```

### 7.4 Use "CHECK LOGICAL" in RMAN Backups  
Checks for logical corruption in data blocks beyond physical checksums.  
```SQL
RMAN> BACKUP CHECK LOGICAL DATABASE PLUS ARCHIVELOG DELETE INPUT;
```

### 7.5 Test Backups  
Validates backup integrity without restoring.  
```SQL
RMAN> RESTORE VALIDATE DATABASE;
```

### 7.6 Store Each Data File in a Separate Backup Piece (RMAN)  
When performing a partial restore, RMAN must read the entire backup piece to get the required datafiles/archive logs. Therefore, the smaller the backup piece, the faster the restore can complete. This is especially true for tape backups of large databases or restores of only a single/few files.  
However, a small value for filesperset also results in more backup pieces being created, which can reduce backup performance and increase maintenance operation time. These factors must be weighed against the desired restore time requirements.  
```SQL
RMAN> BACKUP DATABASE FILESPERSET 1 PLUS ARCHIVELOG DELETE INPUT;
```

### 7.7 Maintain RMAN Catalog/Control File  
**Choose your Retention Policy carefully.**  
Make sure it meets your tape retention policy as well as your backup recovery policy. If you are not using a catalog, make sure the CONTROL_FILE_RECORD_KEEP_TIME parameter matches the retention policy.    
```SQL
SQL> ALTER SYSTEM SET control_file_record_keep_time=21 SCOPE=BOTH; -- Keeps records for 21 days
```
This will retain the backup record in the control file for 21 days.  
See the following documents for more details:  
Reference: Note 461125.1 How to ensure that backup metadata is retained in the controlfile when setting a retention policy and an RMAN catalog is NOT used.

**Run the following catalog maintenance commands regularly.**  
Reason: Delete Obsolete will delete backups outside of the retention policy.  
If expired backups are not deleted, the catalog will continue to grow until performance issues occur.   
```SQL
RMAN> DELETE OBSOLETE;
```

Reason: Crosschecking will check if the catalog/control file matches the physical backup.  
If a backup is lost, this command will set the backup piece to "EXPIRED". When starting recovery, this backup will not be used, but an earlier backup will be used. To delete the expired backup in the catalog/control file, use the Delete Expired command.    
```SQL
RMAN> CROSSCHECK BACKUP;
RMAN> DELETE EXPIRED BACKUP;
```

### 7.8 Prevent and control file loss  
This will ensure that you always have the latest control file, and that the control file backup is performed at the end of the current backup, rather than during the backup.   
```SQL
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;
```

### 7.9 Test Recovery  
Reason: When you need to perform a recovery, you can learn how the recovery process works without actually performing the recovery and avoid restoring the data files again.  
```SQL
SQL> RECOVER DATABASE TEST;
```

### 7.10 Avoid "DELETE ALL INPUT" for Archive Log Backups  
Reason: "delete all input" will delete all copies of the archive log in different archive directories after backing up the archive log in one archive directory, while "delete input" will only delete the archive log in one archive directory after backing up the archive log in that directory. The next backup will back up the log in archive directory 2 and the new log in archive directory 1, and then delete all the backed up logs. This means that you will keep the archive logs available in archive directory 2 since the last backup (including the logs that have been backed up) and the two copies backed up before the last backup.    
```SQL
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT; -- Correct approach
```
Reference MOS: Top 10 Backup and Recovery Best Practices (Doc ID 388422.1)  

## 8. Emergency Data Recovery Scenarios  
**Regular cross-host recovery drills recommended!**  

### 8.1 Block Corruption Detection and Recovery  
Issue the rman-validate command with the "check logical" clause to validate the database for physical and logical corruption.  
The following example shows how to validate all data files:   
```sql
$ rman target / nocatalog
```

Full DB check:
```SQL
RMAN> RUN {
       ALLOCATE CHANNEL d1 TYPE DISK;
       BACKUP CHECK LOGICAL VALIDATE DATABASE;
       RELEASE CHANNEL d1;
     }
```

Specific datafile check:  
```sql
RMAN> RUN {
       ALLOCATE CHANNEL d1 TYPE DISK;
       BACKUP CHECK LOGICAL VALIDATE DATAFILE 1;
       RELEASE CHANNEL d1;
     }
```

View corrupt blocks:  
```sql
SQL> SELECT * FROM V$DATABASE_BLOCK_CORRUPTION;
```

Use the following statement to check all affected objects found in the V$DATABASE_BLOCK_CORUPTION view.  
```sql
RMAN> RUN {
      ALLOCATE CHANNEL d1 TYPE DISK;
      BLOCKRECOVER CORRUPTION LIST;
      RELEASE CHANNEL d1;
     }
```

Or use Data Recovery Advisor (DRA):  
```sql
RMAN> VALIDATE CHECK LOGICAL DATABASE;
RMAN> LIST FAILURE;
RMAN> ADVISE FAILURE;
RMAN> REPAIR FAILURE PREVIEW;
RMAN> REPAIR FAILURE NOPROMPT;
```
Ref: Quick guide RMAN corrupt block recover steps (Doc ID 1428823.1)

### 8.2 DDL(Drop Table)/DML(Insert/Delete/Update) Single Table Recovery (Non-Partitioned Table/Single Partition)  
***Note: undo_retention: indicates the expiration time of undo data. The system defaults to 900, which is 15 minutes.***  
***However, please note that the premise for ensuring that undo data is valid within this time is that there is enough space in the undo tablespace to store it.***  
***If the undo space is full and a new transaction is executed, the original undo data will be overwritten regardless of whether the undo data is expired.***  
***However, if the undo space is sufficient, even if the undo data has exceeded the specified time, as long as it is not overwritten, the undo data still exists, so it can still be flashbacked (but alter table table_name enable row movement must be executed before adding, deleting, or modifying table records, that is, allowing the table to move rows, otherwise after the specified time, the undo data will not be able to be flashed back even if it is not overwritten, and an ora-01466 error will be prompted).***  

#### 1) Recover Deleted Rows  
a) Change the current session time format  
```sql
ALTER SESSION SET nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
```

b) View the current system time
```sql
SELECT SYSDATE FROM DUAL;
```

c) Use Flashback Query to view the data of the table before the accidental deletion  
```sql
SELECT * FROM test AS OF TIMESTAMP TO_TIMESTAMP('2018-02-15 13:38:05','yyyy-mm-dd hh24:mi:ss');
```

d) Data recovery using Flashback Query  
```sql
-- Option 1: Create backup table
CREATE TABLE test_old AS
SELECT * FROM test AS OF TIMESTAMP TO_TIMESTAMP('2018-02-15 13:38:05','yyyy-mm-dd hh24:mi:ss');

-- Option 2: Insert back deleted rows
INSERT INTO test
SELECT * FROM test AS OF TIMESTAMP TO_TIMESTAMP('2018-02-15 13:38:05','yyyy-mm-dd hh24:mi:ss');

-- Option 3: Flashback Table (requires row movement)
ALTER TABLE test ENABLE ROW MOVEMENT;
FLASHBACK TABLE test TO SCN 11111;
FLASHBACK TABLE test TO TIMESTAMP TO_TIMESTAMP('2013/06/23 19:17:00','yyyy/mm/dd hh24:mi:ss');
```

In addition, you can use Flashback Version Query to see how records have changed over a period of time in the past.  
```sql
col versions_xid for a16 heading 'XID'
col versions_startscn for 99999999 heading 'Vsn|Start|Scn'
col versions_endscn for 99999999 heading 'Vsn|End|Scn'
col versions_operation for a12 heading 'Operation'
select versions_xid,versions_startscn,versions_endscn,
decode(
versions_operation,
'I','Insert',
'U','Update',
'D','Delete','Original') Operation,
id,name
from test2
VERSIONS BETWEEN SCN MINVALUE AND MAXVALUE
where id=1;
```

You can also use the Flashback Transaction Query function to view all changes made to a transaction.
The same XID represents the same transaction.
```sql
select xid,operation,commit_scn,undo_sql
from flashback_transaction_query
where xid in (
select  versions_xid
from test4
versions between scn minvalue and maxvalue
);
```

#### 2) Recover Dropped Table (Non-Partitioned)
```SQL
flashback table test to before drop;
select * from test;
```

## 8.3 Truncate Table/Drop Table Partition Recovery (No Logical Backup)
1) Preferred: you need to set up a delayed application on the ADG Standby side in advance to recover from accidental deletions.
ADG delay application setting method:
```SQL
alter database recover managed standby database delay 5 disconnect from session;（delay 5 这里表示 延迟5分钟后在对日志进行应用）
```
Or  
By modifying the log_archive_dest_n parameter to use "DELAY=", for example: DELAY=5 (in minutes), it means a delay of 5 minutes  
```SQL
alter system set log_archive_dest_2='service=standby reopen=60 lgwr async delay=5 valid_for=(online_logfiles,primary_role) db_unique_name=standby' scope=both;
```
Restore data through ADG delayed standby function. Delayed standby is to actively set the delay of standby log application to avoid the operation of the main database being immediately applied to the standby database. In this way, when the main database accidentally deletes data, the data in the standby database can be guaranteed not to be deleted within the delay time limit, so that we can restore data from the delayed standby database.
The specific operation steps are as follows:  
a) Cancel the log application of the standby database immediately  
```sql
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
```

b) Switch logs on primary:
```SQL
SQL> ALTER SYSTEM SWITCH LOGFILE;
```

c) Mount standby:
```SQL
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
```
d) Recover standby to pre-truncate time:
```SQL
RUN {
  SET UNTIL TIME "to_date('2023-10-11 16:45:00','yyyy-mm-dd hh24:mi:ss')";
  RECOVER DATABASE;
}
```

e) Open standby read-only & verify data:
```SQL
SQL> ALTER DATABASE OPEN READ ONLY;
SQL> SELECT COUNT(*) FROM test.testdebug; -- Confirm data exists
```

f) The standby database is turned on in snapshot database mode to export table data
```
SQL> ALTER DATABASE CONVERT TO SNAPSHOT STANDBY;
SQL> ALTER DATABASE OPEN;
$ expdp \'/ AS SYSDBA\' DUMPFILE=test.dmp TABLES=test.testdebug DIRECTORY=expdir LOGFILE=test.log  
```

g) Switch to physical standby database and restore synchronization
```SQL
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
SQL> ALTER DATABASE CONVERT TO PHYSICAL STANDBY;
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP;
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DELAY 120 DISCONNECT FROM SESSION;
```

#### 2) Flashback Standby Database (Requires pre-enabled flashback)
Flashback flashes back the database, and flashes back the entire database data to the time point before the data was accidentally deleted. The disadvantage of this method is very obvious. Flashback flashes back the data of the entire database together, and this recovery method is almost impossible to operate in the production master database environment, because it is impossible to flash back the data of the entire database to the previous time point for the data of a table. Therefore, this method is suitable for the backup database environment. When the flashback function is enabled in the backup database, we can choose to flash back and restore data on the backup database.  
The specific operation steps are as follows:  
a) Check oldest flashback time:  
```SQL
SQL> SELECT * FROM V$FLASHBACK_DATABASE_LOG;
```

b) Mount standby:
```SQL
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
```

c) Flashback to pre-truncate time:
```SQL
SQL> FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2023-10-11 17:45:00','yyyy-mm-dd hh24:mi:ss');
```

d) Open the database in read-only mode and confirm the data to be restored.
```SQL
SQL> alter database open read only;
SQL> select count(*) from test.testdebug;


  COUNT(*)
----------
    172864
```

e) Open the standby database to snapshot database mode to export table data  
```SQL
SQL> alter database convert to snapshot standby;
SQL> Alter database open;
```

--expdp export table data  
```SQL
expdp 'userid="/ as sysdba"' dumpfile=test.dmp tables=test.testdebug directory=expdir logfile=test.log
```

f) Switch to physical standby database to restore synchronization  
```SQL
SQL> shutdown immediate;
SQL> startup mount ;
SQL> alter database convert to physical standby;
```

--Re-sync  
```SQL
SQL> shutdown immediate;
SQL> startup;
SQL> alter database recover managed standby database using current logfile  disconnect from session;
```

#### 3) RECOVER TABLE (Oracle 12c+ Feature)
Steps:  
Identifies backup containing table/partition.  
Checks auxiliary space.  
Creates auxiliary instance for recovery.  
Generates Data Pump export dump.  
(Optional) Imports recovered object.  
(Optional) Renames object during import.  

**Example 1: Execute the recover table recovery command on a different machine to recover partition p20 of table test_part in EBSDB PDB**  
--- until time recovery time point  
---AUXILIARY DESTINATION auxiliary instance data file path  
---DATAPUMP DESTINATION export dmp file path  
---DATAPUMP FILE export dmp file name  
---NOTABLEIMPORT do not import into the target database  
```sql
rman target sys/oracle@racpdg log /tmp/recover_table.log
RECOVER TABLE "TEST"."TEST_PART":"P_20" OF PLUGGABLE DATABASE ebsdb
UNTIL TIME "to_date('11/09/2022 15:18:11','MM/DD/YYYY HH24:MI:SS')"
AUXILIARY DESTINATION '/u01/app/oracle/auxinstance'
DATAPUMP DESTINATION '/tmp'
DUMP FILE 'test_part_p20.dmp'
NOTABLEIMPORT;
```

**Example 2: Directly import the recovered data into the target database (fastest recovery)**
```sql
RECOVER TABLE "TEST"."TEST_PART":"P_20" OF PLUGGABLE DATABASE ebsdb
UNTIL TIME "to_date('11/09/2022 15:18:11','MM/DD/YYYY HH24:MI:SS')"
AUXILIARY DESTINATION '/u01/app/oracle/auxinstance';
```

---Execute the import operation, the table imported into the target database is table name_partition  
```sql
Performing import of tables...
   IMPDP> Master table "SYS"."TSPITR_IMP_lAng_oigD" successfully loaded/unloaded
   IMPDP> Starting "SYS"."TSPITR_IMP_lAng_oigD":  
   IMPDP> Processing object type TABLE_EXPORT/TABLE/TABLE
   IMPDP> Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
   IMPDP> . . imported "TEST"."TEST_PART_P_20"                     5.484 KB       1 rows
   IMPDP> Job "SYS"."TSPITR_IMP_lAng_oigD" successfully completed at Sun Nov 13 15:15:50 2022 elapsed 0 00:00:06
Import completed
```

---Will not affect other table data in the table space  
```sql
SQL> select * from "TEST"."TEST_PART_P_20"  ;

        ID INSERTDATE
---------- -------------------
        11 2022-11-09 15:15:25

SQL>  select * from "TEST".test_recover;

INSERTDATE
-------------------
2022-11-09 15:23:08

SQL>
```

**Example 3: Multi-partition recovery with remapping**  
Restore multiple partition tables based on log sequence numbers and remap the restored tablespaces and table names  
```sql
RECOVER TABLE SH.SALES:SALES_1998, SH.SALES:SALES_1999
    UNTIL SEQUENCE 354
    AUXILIARY DESTINATION '/tmp/oracle/recover'
    REMAP TABLE 'SH'.'SALES':'SALES_1998':'HISTORIC_SALES_1998',
              'SH'.'SALES':'SALES_1999':'HISTORIC_SALES_1999'
    REMAP TABLESPACE 'SALES_TS':'SALES_PRE_2000_TS';
```

**Example 4: Multi-table recovery with schema remap**  
Restore multiple tables and remap the restored users and table names  
```sql
RECOVER TABLE HR.DEPARTMENTS, SH.CHANNELS
UNTIL TIME 'SYSDATE – 1'
AUXILIARY DESTINATION '/tmp/auxdest'
REMAP TABLE hr.departments:example.new_departments, sh.channels:example.new_channels;
```
