---
layout: post
title: "Essential Oracle GoldenGate Configurations Across Different Oracle Database Versions"
excerpt: "A deep dive into the critical Oracle database configurations essential for successful Oracle GoldenGate (OGG) deployment across various versions (10g, 11g, 12c, 19c), drawing from over 8 years of real-world project experience to prevent common pitfalls and ensure data consistency."
date: 2025-06-05 16:00:00 +0800
categories: [Oracle, GoldenGate]
tags: [oracle, goldengate, database configuration, data replication, best practices, oracle 10g, oracle 11g, oracle 12c, oracle 19c, multitenant, pdb, cdb, supplemental logging, archivelog, force logging]
# image: /assets/images/posts/your-image-here.jpg # 您可以替换为相关图片路径
---

The powerful capabilities of Oracle GoldenGate (OGG) as a tool for heterogeneous data replication and real-time data integration are widely recognized in the industry. However, OGG's exceptional performance and data consistency are invariably built upon the correct configuration of the underlying Oracle database it relies on. With over 8 years of experience in OGG project implementation and operations, I have been deeply involved in multiple core systems utilizing Oracle 10g, 11g, 12c, and 19c database versions, such as off-site disaster recovery for a state-owned bank and business report extraction for a telecom operator. These project experiences have profoundly revealed that key configurations at the database level are the cornerstone of OGG project success, and the subtle differences between various database versions are often the culprits behind project delays or even failures. This article aims to leverage extensive practical experience to provide a detailed analysis of the critical configurations required when deploying OGG on these mainstream Oracle database versions, along with the underlying logic.

# 1 Core Configurations and Universal Principles

Regardless of how database versions evolve, the core objectives of OGG configuration at the database end remain constant: to ensure that the Extract process can accurately, efficiently, and continuously capture all transactional changes and guarantee data consistency. The following are core configuration items that span across versions and their critical roles for OGG:

1.  **ARCHIVELOG Mode**: The OGG Extract process captures data changes by reading the database's redo logs. If the database is not in ARCHIVELOG mode, old redo logs might be overwritten, preventing Extract from retrieving historical changes, leading to data loss or process interruption. This is fundamental for OGG's normal operation.
2.  **FORCE LOGGING Mode**: Ensures that all database operations (including those in NOLOGGING mode, like Direct Path Inserts) generate redo logs. This is crucial for guaranteeing the completeness of data captured by OGG.
3.  **Supplemental Logging**:
    *   **Minimal Supplemental Logging**: This is the minimum database-level requirement, ensuring that redo logs contain sufficient column information for OGG to uniquely identify modified rows, especially on tables without primary keys or unique indexes. It is vital for OGG log mining.
    *   **Primary Key/Unique Index Supplemental Logging**: OGG, by default, uses primary keys or unique indexes to locate and update rows in the target table. Enabling this ensures that when primary keys or unique indexes are changed, the redo logs include all primary key column values, maintaining key-based row localization.
    *   **ALL Column Supplemental Logging**: When a table lacks a primary key or unique index, or when CDC (Change Data Capture) scenarios require tracking changes to all columns, this option is the "panacea" for ensuring data consistency. It ensures redo logs contain both old and new values for all columns, even at the cost of some performance.
4.  **Database Parameters**:
    *   **`UNDO_RETENTION`**: During log mining, the OGG Extract process sometimes needs to access UNDO information from when the transaction occurred to construct a complete row image. If `UNDO_RETENTION` is set too low, UNDO information might be overwritten, preventing Extract from correctly parsing LCRs (Logical Change Records), leading to data inconsistency or Extract process interruption.
    *   **`ENABLE_GOLDENGATE_REPLICATION`**: This parameter is crucial for Integrated Capture mode in Oracle 11.2.0.3 and later. It informs the database that OGG's integrated capture process is running and allows the database to perform necessary optimizations and log management.
    *   **`STREAM_POOL_SIZE`**: This memory pool primarily supports OGG's Integrated Capture mode, including the LogMiner component. Proper configuration ensures that the Extract process has sufficient memory to handle transactions and LCRs, avoiding performance bottlenecks or process interruptions.
5.  **OGG User Privileges**: The Extract process requires specific database privileges to connect to the database, query the data dictionary, access redo logs, and manage supplemental logging. This ensures both security and functionality.
6.  **12c/19c PDB Specifics**: In a multitenant architecture, OGG configuration needs to differentiate between the CDB (Container Database) level and PDB (Pluggable Database) level. This directly affects whether OGG can correctly connect to and monitor specific business databases.

# 2 Practical Analysis of Key Database Configurations

## A. ARCHIVELOG Mode and FORCE LOGGING

ARCHIVELOG mode is fundamental for OGG to capture data changes. FORCE LOGGING mode ensures all database operations (including those using the NOLOGGING attribute) generate redo logs, preventing data loss.

**Operations in 10g/11g Environments**

*   **Check ARCHIVELOG Mode**: `SELECT LOG_MODE FROM V$DATABASE;`
*   **Set ARCHIVELOG Mode**:
```sql
SHUTDOWN IMMEDIATE;
-- For RAC environments, stop the database: srvctl stop database -d <databasename>
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```
    
* 10g/11g typically do not require explicit setting of `FORCE LOGGING` as their logging mechanisms usually cover all operations.

**Operations in 12c/19c Environments**:

*   **Set ARCHIVELOG Mode**: Same as 10g/11g, but executed in the CDB Root. PDBs will inherit the CDB's ARCHIVELOG mode.
*   **Set FORCE LOGGING**: Executed in the CDB Root, affecting all PDBs.
```sql
ALTER DATABASE FORCE LOGGING;
-- Verification
SELECT FORCE_LOGGING FROM V$DATABASE; -- Should be YES
```

## B. Supplemental Logging Configuration

Supplemental logging is key for the OGG Extract process to correctly parse LCRs (Logical Change Records) and locate target row records. It ensures that redo logs contain all column information required by OGG.

**Operations in 10g/11g Environments**:

*   **Enable Database-Level Minimal Supplemental Logging**:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
-- Verification
SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V$DATABASE; -- Should be YES
```
    
*   **Enable Primary Key/Unique Index Supplemental Logging**:

```sql
-- Database level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE INDEX) COLUMNS;
-- Verification
SELECT SUPPLEMENTAL_LOG_DATA_PK, SUPPLEMENTAL_LOG_DATA_UI FROM V$DATABASE; -- Should be YES, YES

-- Table level (Similar to ADD TRANDATA schema.table_name in GGSCI)
ALTER TABLE schema.table_name ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE INDEX) COLUMNS;
```

*   **Enable All Column Supplemental Logging for Specific Tables without PK/UI**: Recommended to execute `ADD TRANDATA schema.table_name ALLCOLS` in GGSCI. Under the hood, this automatically executes SQL commands similar to `ALTER TABLE schema.table_name ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;`.

**Operations in 12c/19c Environments**:

*   **CDB Level**: Only minimal supplemental logging needs to be enabled in the CDB Root.
```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

*   **PDB Level**: After connecting to the target PDB, execute PDB-level supplemental logging configuration.

```sql
ALTER SESSION SET CONTAINER = pdb_name;
-- Enable primary key/unique index supplemental logging (database or table level)
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE INDEX) COLUMNS;
ALTER TABLE schema.table_name ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE INDEX) COLUMNS;
-- For specific tables without PK/UI, enable all column supplemental logging via GGSCI command within the PDB
-- GGSCI: ADD TRANDATA schema.table_name ALLCOLS
-- GGSCI: ADD SCHEMATRANDATA schema ALLCOLS 
```

**Experience Sharing**:

In an OGG migration project for a **city commercial bank**, moving from an **11g core system** to an **11g disaster recovery system**, the team encountered a tricky issue. The OGG Extract process started normally, but after UPDATE operations on specific tables, the Replicat process reported errors like `OGG-00868 No unique key found` or `OGG-01403 No row found for LCR update operation`. Upon careful inspection, it was found that these problematic tables had no primary or unique keys. Although database-level minimal supplemental logging was enabled, `ALLCOLS` was not enabled for these keyless tables via `ADD TRANDATA`. Extract could only capture the RID (Row Identifier) in the logs, but without a unique business key, Replicat couldn't accurately match rows when they were moved or compressed on the target. The solution was to urgently execute the `ADD TRANDATA schema.table_name ALLCOLS` command for all tables without primary keys. After restarting Extract, the problem was immediately resolved.

**Lesson Learned**: For tables without primary/unique keys, even if database-level supplemental logging is enabled, it is imperative to separately enable all-column supplemental logging. This is the "bottom line" for ensuring data consistency.

## C. OGG Database User and Privileges

OGG processes require a specific database user identity to connect to the database and possess a series of privileges, such as querying the data dictionary and reading redo logs, to ensure smooth data capture and replication.

*   **Operations in 10g/11g Environments (Non-CDB)**:

```sql
CREATE USER ogguser IDENTIFIED BY ogguser_password;
GRANT CONNECT, RESOURCE, CREATE SESSION, ALTER SESSION TO ogguser;
GRANT SELECT ANY DICTIONARY TO ogguser;
GRANT SELECT ANY TABLE TO ogguser; -- In production, recommended to restrict to specific schemas or tables
GRANT ALTER ANY TABLE TO ogguser; -- If DDL replication is needed
GRANT SELECT ON DBA_CLUSTERS TO ogguser;
GRANT FLASHBACK ANY TABLE TO ogguser;
GRANT EXECUTE ON DBMS_FLASHBACK TO ogguser;
GRANT UNLIMITED TABLESPACE TO ogguser;
-- For 11.2.0.3 and later, it's highly recommended to use the DBMS_GOLDENGATE_AUTH package to simplify authorization:
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('OGGUSER', 'capture', grant_select_privileges=>true);
```

*   **Operations in 12c/19c Environments (CDB/PDB)**: OGG user privilege management in a multitenant architecture is more complex and depends on the OGG process's connection target and replication scope. Extract processes typically require CDB-level common users as they need to access the CDB's redo logs; Replicat processes more often use PDB-level local users.

**CDB Common User (Replicating all PDBs in a CDB)**: Create and grant privileges in the CDB Root. The username must be prefixed with `C##`.
```sql
CREATE USER C##ggadmin IDENTIFIED BY <password>
DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp CONTAINER=ALL;
GRANT CONNECT, RESOURCE TO C##ggadmin CONTAINER=ALL;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('C##ggadmin', 'capture', container=>'all');
-- Note: This user covers all PDBs via CONTAINER=ALL and must use the C## prefix.
```

**CDB Common User (Replicating only specific PDBs)**: Create in the CDB Root, but specify target PDBs during authorization.
```sql
CREATE USER C##ggadmin IDENTIFIED BY <password>
DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp; -- Note: No CONTAINER=ALL here
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('C##ggadmin', 'capture', container=>'<PDB_NAME>');
-- Note: Privileges are restricted to the specified PDB; CONTAINER=ALL cannot be used.
```

**PDB-Level Local User (For auxiliary operations, e.g., Replicat process)**: Used only for auxiliary operations (like sequence replication, heartbeat tables, Replicat connecting to a specific PDB). A local user needs to be created in each PDB.
```sql
ALTER SESSION SET CONTAINER = <PDB_NAME>;
CREATE USER ogguser_local IDENTIFIED BY ogguser_password;
GRANT CONNECT, RESOURCE, CREATE SESSION, ALTER SESSION TO ogguser_local;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('ogguser_local', 'capture', grant_select_privileges=>true); -- The 'capture' privilege here is a general template; Replicat might actually need 'apply' privileges.
-- For Replicat, the following privileges might be needed:
-- GRANT CREATE ANY TABLE, ALTER ANY TABLE, DROP ANY TABLE TO ogguser_local; (If Replicat needs DDL operations)
-- GRANT UNLIMITED TABLESPACE TO ogguser_local;
```

**Experience Sharing**:

*   In a **12c production environment** upgrade project for a **telecom operator**, the OGG Extract process was configured to connect to a specific PDB. However, after starting, it frequently reported `OGG-00664` (fatal error in database initialization) or `OGG-01031` (insufficient privileges). Initial checks revealed that the OGG user was a CDB common user (C##OGG) and had been granted most privileges in the CDB Root. The issue arose because when Extract actually connected to the PDB, it either didn't correctly recognize its context within the PDB, or it lacked access permissions to certain PDB internal views.
*   The solution was to re-evaluate the best practices for OGG users in CDB/PDB environments and adjust the creation and authorization methods based on the OGG process's connection target (CDB Root for Extract, specific PDB for Replicat/utility) and replication scope. Ensured the Extract process's CDB common user had `CONTAINER=ALL` privileges and correctly used `DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE`.

## D. Database Parameter Configuration

*   **`ENABLE_GOLDENGATE_REPLICATION`**
For Integrated Capture mode in Oracle 11.2.0.3 and later, this parameter must be set to TRUE. It enables the database to integrate with OGG, providing necessary log capture optimizations.
**All Version Operations**: Set in the CDB Root; typically affects all PDBs.
```sql
ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;
-- Verification
SHOW PARAMETER ENABLE_GOLDENGATE_REPLICATION;
```

*   **`STREAM_POOL_SIZE`**
The Stream Pool is a core memory area for OGG Integrated Capture mode, used to store LCRs, metadata, etc. Proper configuration ensures Extract runs efficiently and avoids memory shortages or performance bottlenecks.
**12c/19c Environment Operations**: Recommended to configure based on the number of Extract processes. A rule of thumb is to allocate at least 1GB of memory for one Integrated Extract process, and then add an extra 200MB-500MB as a buffer for each additional Extract process or based on actual load.
```sql
-- Set in CDB Root, affects all PDBs (if Extract connects to CDB)
ALTER SYSTEM SET STREAM_POOL_SIZE = 2G SCOPE=BOTH; -- Example, adjust based on actual needs
-- Verification
SHOW PARAMETER STREAM_POOL_SIZE;
```

*   **`UNDO_RETENTION`**
During log mining, the OGG Extract process might need to access a transaction's UNDO information to construct a complete row image. The `UNDO_RETENTION` parameter determines how long transaction information is retained in UNDO segments.
**All Version Operations**: Set to a sufficiently large value based on actual transaction volume and Extract lag. It's generally recommended to be at least 3600 seconds (1 hour). For long-running transactions or scenarios with significant Extract lag, a larger value might be necessary.
```sql
ALTER SYSTEM SET UNDO_RETENTION = 3600 SCOPE=BOTH; -- Example value
-- Verification
SHOW PARAMETER UNDO_RETENTION;
```

**Experience Sharing**:

When implementing an OGG real-time synchronization project from a **19c core transaction system** to a **19c data warehouse** for a **large insurance company**, Extract started normally after PDB configuration. However, after some time, for newly created PDBs, Replicat again experienced synchronization delays and even interruptions. Investigation revealed that, besides the new PDBs not having supplemental logging and OGG users configured according to standards, the original, smaller `STREAM_POOL_SIZE` had also become a bottleneck due to increased data and transaction volumes, causing Extract to develop log backlogs.

The solution was to strengthen project process management by making OGG database configuration a **mandatory checklist item after creating new PDBs**. Once a new PDB went live, the DBA team had to immediately execute OGG-related supplemental logging and user privilege scripts within it. Concurrently, based on actual operational data and monitoring, `STREAM_POOL_SIZE` was increased from 2G to 4G to accommodate higher transaction concurrency.

**Lesson Learned**: Although 19c is stable, OGG configuration in a multitenant environment is not a "set it and forget it" task. Any new PDB should be treated as an independent OGG source, requiring **separate completion of its internal OGG-related configurations**. Furthermore, performance parameters like `STREAM_POOL_SIZE` need dynamic adjustment and optimization based on actual load.

# 3 Version Compatibility and Upgrades

Compatibility between OGG versions and Oracle Database versions is crucial. Generally, higher OGG versions can support lower database versions, but not vice versa. For example, OGG 19c can connect to and extract data from Oracle 11g/12c/19c, but OGG 12c might not fully support new features in Oracle 19c. When upgrading database versions, it's essential to plan the OGG compatibility upgrade path in advance.

**Key Points for OGG Configuration Migration During Database Upgrades**:

1.  **Stop OGG Processes**: Before upgrading the database, stop all related Extract and Replicat processes.
2.  **Verify New Version Compatibility**: Confirm if the current OGG version is compatible with the target database version.
3.  **Re-validate Configuration**: After the database upgrade, even if configuration commands are the same, it's crucial to re-validate that all OGG-required database parameters (especially `ENABLE_GOLDENGATE_REPLICATION`, `STREAM_POOL_SIZE`), supplemental logging, and OGG user privileges are effective on the new database version. PDB configuration is particularly critical when upgrading from 11g to 12c/19c.
4.  **Initial Load**: For major upgrades, sometimes an initial load is considered to ensure complete data consistency.

# 4 Summary and Best Practices

The success of an OGG deployment hinges on a deep understanding and rigorous execution of key database configurations. As a seasoned OGG architect, I've distilled the following best practices and checklists from countless real-world experiences:

1.  **The "Six-in-One" Principle**: Always treat **ARCHIVELOG mode**, **FORCE LOGGING**, **minimal supplemental logging**, **primary key/unique index supplemental logging**, **all-column supplemental logging for tables without primary keys**, and **OGG user privileges** as an indivisible whole. None can be missing.
2.  **PDB Context First**: For Oracle 12c and later multitenant environments, ensure most OGG-related database configurations and local user authorizations are performed within the target PDB. Newly created PDBs must undergo independent OGG-related configuration.
3.  **`ENABLE_GOLDENGATE_REPLICATION` Must Be On**: For Integrated Capture, this parameter is fundamental. Ensure it's set to TRUE at the CDB or relevant PDB level.
4.  **Dynamic Adjustment of `STREAM_POOL_SIZE`**: Based on the number of Extract processes and actual transaction load, reasonably set `STREAM_POOL_SIZE` (recommended at least 1GB + 200MB per Extract process) and continuously monitor its usage in production for optimization.
5.  **Ensure Sufficient `UNDO_RETENTION`**: Set an adequate `UNDO_RETENTION` period based on transaction characteristics and OGG lag to prevent Extract interruptions due to lost UNDO information.
6.  **Standardized Scripts and Automation**: Develop and maintain a set of standardized OGG database configuration scripts. Run these scripts directly when deploying new environments or creating new PDBs to reduce human error.
7.  **Rigorous Pre-checks and Testing**: Before OGG goes live, in addition to basic connectivity tests, perform **data consistency validation** and **stress testing**. Simulate production environment transaction loads to ensure OGG can stably and efficiently capture and replicate data.
8.  **In-depth Error Log Analysis**: When encountering issues, don't just focus on OGG's own error messages. Delve deeper into database alert logs (alert.log) and database session trace files, as many OGG problems originate in the database.
9.  **Regular Health Checks**: Establish routine health check mechanisms for OGG and the database, including archive log space, supplemental logging status, Extract process lag, etc., to prevent problems before they occur.

OGG is a powerful tool, but it's not a "one-click deployment" silver bullet. Bridging the gap across different Oracle database versions requires a thorough understanding of the underlying mechanisms and meticulous execution of each configuration item, combined with practical project experience. Only then can OGG deliver its maximum value in enterprise core systems.
