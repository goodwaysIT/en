---
layout: post
title: "ORACLE 19C Database Architecture and Operation and Maintenance Guide"
excerpt: "Since ORACLE 12c&19C databases were implemented and deployed earlier and have been put into production for a long time, many problems have been encountered during use. In order to improve the stability of Oracle databases and ensure the healthy and continuous operation of business, based on the existing product architecture and future architecture trends, the following guidance suggestions are given."
date: 2025-05-27 16:36:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle, Leo.Wang]
image: /assets/images/posts/ORACLE-19C-Database-Architecture-and-Operation-and-Maintenance-Guide.jpg
author: Leo.Wang
---

## 一、	Overview  
### 1.1	Project Background

With the product conversion from DB2 to Oracle database, more and more Oracle databases are put into use. Since ORACLE 12c&19C databases were implemented and deployed earlier and have been put into production for a long time, many problems have been encountered during use. In order to improve the stability of Oracle databases and ensure the healthy and continuous operation of business, based on the existing product and future architecture trends, the following guidance suggestions are given.  
<TABLE>
<TR>
<TD align="left">
<FONT><strong>19C version database operation and maintenance system:</strong></FONT>
</TD>
</TR>
<TR>
<TD align="left">
<img src="https://goodwaysit.github.io/en/assets/images/database/db_architecture.png" style="float:left;" />
</TD>
</TR>
</TABLE>

    
### 1.2	Hardware environment
<TABLE>
<TR>
<TD align="left">
<FONT><strong>Exadata(X6-2、 X7-2、 X8-2) + PC Server (several)</strong></FONT>
</TD>
</TR>
<TR>
<TD align="left">
<img src="https://goodwaysit.github.io/en/assets/images/database/exadata.JPG" style="float:left;" />
</TD>
</TR>
</TABLE>

### 1.3	Software Environment  
<TABLE>
<TR>
<TD align="left">
<img src="https://goodwaysit.github.io/en/assets/images/database/version.png" style="float:left;" />
</TD>
</TR>
</TABLE>

## 二、	Multi-dimensional analysis and suggestions
### 2.1	Version
From the existing database list, the main database version currently in use is 12.2.0.1, and the RU patch version basically stays in 2017. From the official Oracle database version support cycle, the standard support for version 12.2 expires at the end of March 2020. In order to better provide product support, it is recommended to consider version 19C for subsequent database version selection, and upgrade or migrate the existing 12c version database to 19C through medium- and short-term plans.

> The product support life cycle diagram of each version is given below:  
> ![support timelines](https://goodwaysit.github.io/en/assets/images/database/timelines.jpg#pic_left)

According to the Oracle database product lifecycle support policy, as shown in the figure above, we can see that:  

    The standard support period for version 12.2.0.1 ends on March 31, 2020, and is extended to March 31, 2022 (extended support must be purchased separately)  
    The standard support period for version 19C ends on April 30, 2024, and is extended to April 30, 2027 (extended support must be purchased separately)  
    The support period for 19C ends in mid-2027, and it is a long-term support version in the 12C product family.

### 2.2	Architecture
#### 2.2.1	Database Architecture
<TABLE width="500">
<TR>
<TD align="left">
<FONT><strong>NON-CDB Architecture</strong></FONT>
</TD>
<TD align="left">
<FONT><strong>CDB Architecture</strong></FONT>
</TD>
</TR>
<TR>
<TD align="left">
<img src="https://goodwaysit.github.io/en/assets/images/database/non-cdb.jpg" style="float:left;" />
</TD>
<TD align="left">
<img src="https://goodwaysit.github.io/en/assets/images/database/cdb.jpg" style="float:left;" />
</TD>
</TR>
</TABLE>

**NON-CDB:**  
A large enterprise faces hundreds or even thousands of databases to manage. Generally speaking, these databases will run on multiple physical servers and may be on different platforms. As hardware technology improves, especially the number of CPUs increases, servers can support heavier loads. This means that a database only consumes a small part of the resources of a server, which wastes a lot of hardware and human resources. A team of DBAs needs to manage the SGA, database files, accounts, security, etc. of each database separately.

**CDB:**  
1. Each application can have its own PDB
* Application operation does not need to be changed
* New PDBs can be quickly generated through replication, and migration is fast
* Portability, because it is pluggable

2. General operations at the CDB level
* No need to manage multiple PDBs separately, such as patching, upgrading, HA configuration and backup operations, etc. Operations on CDB are equivalent to operations on all PDBs inserted into the CDB
* Granular management

3. Shared memory and background processes
* Because each DB does not need to have its own SGA/PGA and background processes as in the past, it is equivalent to saving memory, and each server can have more applications

**Current status:**  
The current production database architecture is mainly NON-CDB architecture, and most of them are the same physical machine running multiple instances. The databases are very small and relatively scattered small databases.

**Solution:**  
CDB architecture is particularly suitable for some relatively small scattered databases to avoid resource waste caused by single database and single instance. Starting from 20C, Oracle no longer supports NON-CDB architecture by default. The only architecture option is CDB architecture. To adapt to the CDB software architecture of Oracle database, it is recommended to use CDB software architecture to deploy database in the future. Hardware resources can be more fully utilized, and the efficiency of operation and maintenance can be greatly improved.

#### 2.2.2	Maximum Availability Architecture (MAA)
Oracle Maximum Availability Architecture (MAA) is Oracle's best practices approach, based on proven Oracle high availability technologies and recommendations. The purpose of MAA is to achieve the best high availability architecture at the lowest cost and complexity.  
* MAA best practices involve Oracle Database, Oracle Application Server, Oracle Applications, and Grid Control.  
* MAA takes into account a variety of business requirements to make these best practices as widely applicable as possible.  
* MAA uses lower-cost servers and storage.  
* MAA continues to evolve with new Oracle versions and features.  
* MAA is independent of hardware and operating systems.  
> ![MMA](https://goodwaysit.github.io/en/assets/images/database/mma.jpg#pic_left)  

**Current status:**  
In the existing environment, the core database is equipped with ADG, which complies with the MAA architecture.

**Solution:**  
The secondary core database does not have ADG, and it is recommended to configure it if the hardware allows.

### 2.3	Environment Baseline
To ensure the stability of subsequent database operation, it is recommended to formulate parameter and patch implementation baselines in a best practice manner to provide a unified reference guide for subsequent database environment deployment. A stable environment can ensure the stable operation of the database.  
Parameter and patch baselines need to be done in depth and in detail. It is recommended to spend man-days to do it in detail and perform parameter performance evaluation through stress testing.

#### 2.3.1	19C Standard Operating Procedure
**Current status:**  
There is no relatively complete 19C installation guide

**Solution:**  
Improve the 19C installation guide, covering different platforms, RAC, Alone and single instance scenarios.

#### 2.3.2	Parameter baseline  
Parameter baselines should be subdivided into NON-CDB and CDB according to the database software architecture.  
Parameter baselines should include the following key points:  
*	Two baseline standards for NON-CDB and CDB
*	CDB architecture, PDB resource allocation and isolation
*	CDB architecture, memory configuration (SGA/PGA)
*	DRM and ACS related features
*	New feature parameters

**Current status:**  
19C parameter analysis has been completed.  

**Solution:**  
Based on the specific CDB architecture, further improve the parameter recommendations of the CDB architecture.  

#### 2.3.3	Patches
Based on the OS platform and database version, combined with the experience of Oracle users around the world, we have compiled the best patch recommendations to avoid programmatic bugs as much as possible.  
Among the recent failures, two of them were caused by outdated patch RUs, which led to production failures. The details are as follows:  

**Bug 27162390 - RAC LMS Process Hits ORA-600 [kclantilock_17] Error and Instance Crashes (Doc ID 27162390.8)**  
> ![Bug 27162390](https://goodwaysit.github.io/en/assets/images/database/Bug_27162390.jpg#pic_left)

**Bug 28681153 - ORA-600: [qosdexpstatread: expcnt mismatch] (Doc ID 28681153.8)**  
> ![Bug 28681153](https://goodwaysit.github.io/en/assets/images/database/Bug_28681153.jpg#pic_left)

**Current status:**  
Version 12.2: No detailed patch analysis has been conducted, and the patch RU currently in production is still in August 2017.
Version 19C: Patch analysis based on 19.7 has been completed recently.

**Solution:**  
Version 19C has been analyzed, and detailed patch analysis and patch installation are recommended for version 12.2.

### 2.4	Application Testing and SQL Auditing  
Whether it is an upgrade or a daily application version change, the application SQL statements should be audited, which can be done through software product auditing or manual auditing.
As can be seen from recent failures, uncontrolled application SQL has caused many production failures.

##### Current situation:   
There is no complete SQL audit or standardized process for manual DBA audit, which has caused many production failures.

**For example:**  
* Exadata login is slow  
**Problem phenomenon:**    
There are a large number of statements in the DB that do not use bind variables, resulting in abnormally high "version count" and frequent "reload"s, such as:  
`select zno from branch where zno = '982052'`  
**Cause analysis:**  
SQL development specification problem - no use of bind variables  

* Tablespace cannot be extend  
**Problem phenomenon:**  
Data in the business table (INFO_TAB) cannot be inserted normally. It is found in the warning log that DATA_TBS cannot normally extend the space required for the table.  
**Cause analysis:**  
SQL development is not standardized, the fragmentation rate is high, and there are frequent insert and delete operations. Temporary tables and truncate technology are not used for temporary operations.

* RAC Hang problem  
**Problem phenomenon:**  
top event is “cr request retry”  
**current sql:**  
`select a.CUsT CODE,
b.PRO_TYPE,
b.type,
from app_info a
inner join (
SELECT a.CUST CODE,
CASE
WHEN SUBSTR(a.PRO_TYPE,1,4)='2012' THEN
'锟斤拷锟斤'`;  
`sys@clmdb> select * from cwm.remp_info where rownum < 2;`  
**Cause analysis:**  
SQL is not written in a standardized way: query statements without conditions; unnecessary table associations; full table scans

#### Suggestions:  
1. Introduce SQL audit products, conduct audit checks on the corresponding SQL before the application goes online, and avoid SQL problems in advance.
2. The program must be audited by DBA before it goes online (multi-department cooperation is required).

### 2.5	Stability and Performance Evaluation
To ensure the stable operation of the database, necessary monitoring and maintenance are required. Some common monitoring and maintenance scenarios are listed below:  

**Monitoring category:**
*	Object level, such as table space, core table fragmentation rate, index fragmentation rate, index splitting, etc.
*	SQL level, such as TOP SQL, execution plan changes, hard parsing
*	Memory pool, such as Shared Pool, Buffer Cache

**Maintenance category:**  
A good data cleanup plan, slim down the database, and confirm that the database is running in the best state.

**Current situation:**  
The existing monitoring includes ORACLE EM and a third-party monitoring, and the key monitoring is not very complete.

**Suggestions:**  
1. Improve relevant monitoring. (High priority)
2. Develop a complete data cleanup and slimming plan (low priority).

### 2.6	Operation and maintenance guidance manual and emergency guidance manual  
> In order to cope with daily operation and maintenance and emergency situations, in addition to the regular inspection manual, the emergency manual for regular operation and maintenance and emergency handling should be improved, such as:  
> ![maintenance](https://goodwaysit.github.io/en/assets/images/database/maintenance.jpg#pic_left)  

**Current situation:**  
There are inspection and routine operation and maintenance manuals.

**Suggestions:**  
Improve the emergency manual and continue to improve it.

### 2.7	Baseline Improvement  
With the continuous operation, the baselines related to parameters and patches will be continuously improved. A dedicated person or process is needed to implement the maintenance of the baseline.

### 2.8	Backup
ORACLE ZDLRA online backup + tape backup offline storage, the backup architecture is relatively complete and does not need to be adjusted.

### 2.9	Other suggestions
**Configure Service:**  
Based on the serious GC waiting during batch running of some systems, if a single node can meet the load requirements, it is recommended to use the Service method to run the business on one node to avoid GC contention.  

# Appendix: Example of configuring resource isolation parameters under CDB  
> Comparison of resource control version control levels:  
> ![resource management](https://goodwaysit.github.io/en/assets/images/database/resource.jpg)  

### Case1: A bank  

#### PDB CPU resource management  
CDB parameter setting resource manager, to enforce CPU resource allocation, you must set the CDB-level "RESOURCE_MANAGER_PLAN" to "DEFAULT_CDB_PLAN".  
(1) The CPU usage of the PDB is limited by the CPU_COUNT count of the PDB, starting from 12.2.  
(2) Based on the CPU_COUNT count of the PDB, the system automatically sets the CPU scheduling share of the PDB, starting from 18.1.  
> ![task plans](https://goodwaysit.github.io/en/assets/images/database/plan.jpg)

*	autotask：
```bash
shares: -1  
utilization_limit: 90  
parallel_server_limit: 100  
```
***shares = -1 means that the automatic maintenance task uses 20% of the  system resources.***  
***v$rsrcmgrmetric_history records the allocation and usage of resources.***

*	default_pdb_directive：
```bash
new_shares: 1
utilization_limit: 100
parallel_server_limit: 100
```  
***Note:*** Shares=1  
Default_pdb_directive allocates all resources to the created PDB by default. Currently, cpu_count is used to limit resource allocation. Shares defaults to 1.  

***Documentation reference:***  
How to Provision PDBs, based on CPU_COUNT Doc ID 2326708.1  

#### PDB memory resource management  
**Functional description:**  
Using multiple PDBs will inevitably cause resource contention. Oracle 12.2 can effectively control and coordinate the use of various resources.  
> Parameters that need to be set for PDB memory management:  
> ![resource limit](https://goodwaysit.github.io/en/assets/images/database/resource_limit.JPG#pic_left)

**Parameter annotation:**  
*	`PDB: SGA_TARGET PDB maximum memory usage parameter`  
***This parameter is smaller than the CDB parameter setting***

*	`PDB: DB_CACHE_SIZE PBD data cache, set this parameter, memory will not be "stolen"`  
***ASMM memory management mode, minimum configuration of data cache 20%SGA-30%SGA***

*	`PDB: SHARED_POOL_SIZE PDB shared pool cache, set this parameter, memory will not be "stolen"`  
***ASMM memory management mode, minimum configuration of shared pool 30%SGA-20%SGA***  
***Shared pool priority principle: <50%* SGA_TARGET, ensure that shared pool memory is sufficient***

*	`PDB: PGA_AGGREGATE_LIMIT, [2G, sessions*3M]`  
***PDB parameter setting, small CDB parameter setting***  
***PDB parameter setting is not less than twice the setting of PGA_AGGREGATE_TARGET***

*	`PDB: PGA_AGGREGATE_TARGET, [< PGA_AGGREGATE_LIMIT/2]`  
***The parameter setting at the PDB level is less than the parameter setting at the CDB level***  
***The parameter setting at the PDB level is less than PDB PGA_AGGREGATE_LIMIT*50%***  

***Document reference:***  
How to Control and Monitor the Memory Usage (Both SGA and PGA) Among the PDBs in Mutitenant Database- 12.2 New Feature (Doc ID 2170772.1)  How To Deal With "SGA: allocation forcing component growth" Wait Events (Doc ID 1270867.1)  

#### PDB IO resource management  
PDB-level IO usage control:  
*	PDB: MAX_IOPS, PDB maximum IO request per second, unit: times, can be modified dynamically  
*	PDB: MAX_MBPS, PDB maximum IO request per second, unit: M, can be modified dynamically  
```sql  
SQL> alter system set MAX_IOPS=1000;   -- Maximum value in stress test
SQL> alter system set MAX_MBPS=500;   -- Maximum value in stress test
```  
***Document reference:***   
I/O Rate Limits for PDBs 12.2 New feature . (Doc ID 2164827.1)  
It is recommended to set these parameters when IO performance problems occur.    


### Case 2: A certain operator  

#### Objective  
* Limit CDB-level resource allocation for UAT, STANDBY, and DR databases in normal production.  
* Limit PDB-level resource allocation in production databases in special cases.  

#### IORM at CDB level   
* I/O Resource Management (IORM) is a tool for managing multiple databases and how workloads within a database share the I/O resources of Oracle Exadata System Software.  
* Set up "dbplan" to manage resource allocation between databases using "share", "limit", and "flashcachesize" attributes.  
`share`- Specifies the relative priority of databases.  
`limit`- Specifies the maximum disk utilization of a database. This is ideal for "pay for performance" use cases and should not be used to achieve fairness between workloads.  
`flashcachesize`- Specifies a fixed allocation in the flash cache reserved for the database.  
> ![resource profile](https://goodwaysit.github.io/en/assets/images/database/profile.JPG#pic_left)

#### Resource management at the PDB level  
There are three levels of PDB resource planning in the database, which are used to limit CPU and parallel queries.  
|Gold Silver Bronze Plan                    |Share            |ut limit            |parallel limit |
|:----                                      |:----            |:----               |:----          |
|GOLD                                       |8                |100                 |100            |
|SILVER                                     |4                |40                  |40             |
|BRONZE                                     |2                |20                  |20             |

#### CPU control at CDB and PDB level  
```bash
CPU control at CDB and PDB level can also be achieved by modifying cpu_count.
```
#### IO control at PDB level  
```bash
PDB level IO is dynamically controlled using parameters:
* MAX_IOPS
* MAX_MBPS
Memory resource control at PDB level  
```

## Summary of recommendations
*	In order to avoid the redundant background process problems caused by small and independent databases, it is recommended to integrate some scattered small databases through the CDB architecture. Whether the core database is NON-CDB or CDB, it is recommended to use a dedicated database.
*	Improve the 19C standard installation guide, involving different platforms, RAC, Alone and single instance scenarios
*	The 19C CDB environmental parameter baseline is further improved. Combined with stress testing and PDB resource isolation, it is necessary to test from multiple angles.
*	For the 12.2 database version, the RU is too old; it is recommended to upgrade to avoid a large number of known bugs and do a good job of testing before upgrading.
*	SQL audit continues to advance to avoid performance risks caused by SQL.
*	Improve related monitoring, object level, such as core table fragmentation rate, index fragmentation rate, index splitting, etc.; SQL level, such as TOP SQL, hard parsing, hard parsing if the execution plan has changed; memory pool, such as Shared Pool, Buffer Cache.
*	Configure Service. When a single node can carry the business, use Service to run the business on a single node to avoid some problems of waiting for GC when running batches.
*	The 19C operation and maintenance manual is improved, especially for PDB scenarios.

> ⭐️ **Tip:** If you have any questions, send an email to leo.wang@goodways.co.jp



---
<center>&copy;2025 GOODWAYS Inc. All rights reserved.</center>
