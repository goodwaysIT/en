---
layout: post
title: "Oracle SQL Execution Plans: A Deep Dive from Estimation to Real-World Application"
excerpt: "Confusing estimated vs. actual execution plans often leads to failed tuning. This guide systematically breaks down the methods for obtaining Oracle SQL execution plans, from EXPLAIN PLAN to AWR, providing a clear framework for choosing the right tool for development, live troubleshooting, and historical analysis."
date: 2025-08-18 16:44:00 +0800
categories: [Oracle Database, Performance Tuning]
tags: [oracle, execution plan, sql tuning, performance tuning, dba, explain plan, dbms_xplan, v$sql, awr, tkprof, sql optimization]
author: Shane
image: /assets/images/posts/oracle_execution_plan_overview.svg
---


In the realm of database performance tuning, analyzing the SQL execution plan is a critical step in identifying and resolving performance bottlenecks. A common challenge, however, is that the execution plan obtained by a developer or DBA may not be the actual path the SQL takes in a production environment. Confusing the "estimated plan" with the "actual plan" often leads optimization efforts astray.

This article aims to systematically break down the various core methods for obtaining SQL execution plans in an Oracle database. From theoretical prediction in the development phase to real-time trajectory tracking in a live environment, we will deeply analyze the differences, applicable scenarios, and limitations of each method, providing a decision-making framework for selecting the most appropriate tool for different situations.

### I. Preparing the Environment (Oracle 19c)

To ensure the reproducibility of all examples, we first construct a standard test environment. A clear and consistent sandbox is fundamental for effective technical validation.

```sql
-- 1. Create a sample table under the tuser schema
CREATE TABLE t_users (
    id           NUMBER(10) NOT NULL,
    username     VARCHAR2(50) NOT NULL,
    status       VARCHAR2(10) DEFAULT 'ACTIVE' NOT NULL,
    created_date DATE NOT NULL
);

-- 2. Define primary key and a secondary index
ALTER TABLE t_users ADD CONSTRAINT pk_users PRIMARY KEY (id);
CREATE INDEX idx_users_status ON t_users(status);

-- 3. Populate with test data
BEGIN
    FOR i IN 1..100000 LOOP
        INSERT INTO t_users (id, username, created_date) 
        VALUES (i, 'user_' || i, SYSDATE - MOD(i, 365));
    END LOOP;
    -- Create data skew
    UPDATE t_users SET status = 'INACTIVE' WHERE MOD(id, 10) = 0;
    COMMIT;
END;
/

-- 4. Gather statistics (the basis for optimizer decisions)
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(ownname => 'TUSER', tabname => 'T_USERS');
END;
/
```
With the environment ready, we will now explore the techniques for obtaining execution plans in layers.

### II. The Basics: Theoretical Estimation in Development

During the SQL coding and initial review phases, the primary need is to quickly assess the theoretical execution path of the SQL, especially its index utilization, without consuming resources by actually running the query.

#### 1. `EXPLAIN PLAN`: The Optimizer's Static Sandbox

`EXPLAIN PLAN` is the most basic and quickest command to get an execution plan. It does not execute the SQL but merely requests the Cost-Based Optimizer (CBO) to generate an estimated execution plan based on existing object statistics.

This process can be compared to planning a driving route on a map: it provides an estimated optimal path based on known map information (table and index statistics) but cannot predict actual traffic conditions (system load, data caching).

**How to use:**
```sql
-- 1. Generate an execution plan for the target SQL
EXPLAIN PLAN FOR
SELECT * FROM t_users WHERE status = 'INACTIVE';

-- 2. Format and display the output from the plan table
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------
Plan hash value: 616708042

-----------------------------------------------------------------------------
| Id  | Operation         | Name    | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |         | 50000 |  1513K|   137   (1)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| T_USERS | 50000 |  1513K|   137   (1)| 00:00:01 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

PLAN_TABLE_OUTPUT
--------------------------------------------------------------------------------

   1 - filter("STATUS"='INACTIVE')

13 rows selected.
```

**Key Considerations:**
The results of `EXPLAIN PLAN` are valuable for reference but should not be considered definitive. A common pitfall is that the generated plan may differ from the actual plan due to session environment parameters (like NLS settings) being inconsistent with the production environment, leading to misjudgment. **Therefore, it is best suited for quick, preliminary structural checks of SQL.**

#### 2. `SET AUTOTRACE` (SQL*Plus): Integrated Execution and Analysis

In command-line environments like SQL*Plus, the `AUTOTRACE` command provides a convenient way to combine SQL execution with the display of its plan and statistics.

This method is equivalent to reviewing a trip report after actually driving the planned route, which includes key performance metrics like fuel consumption (logical reads) and distance traveled (physical reads).

**How to use:**
```sql
-- Display only the execution plan and statistics, not the query results
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS;

-- Run the target query
SELECT * FROM t_users WHERE id = 12345;

Execution Plan
----------------------------------------------------------
Plan hash value: 4006063161

----------------------------------------------------------------------------------------
| Id  | Operation                   | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |          |     1 |    31 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_USERS  |     1 |    31 |     2   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN         | PK_USERS |     1 |       |     1   (0)| 00:00:01 |
----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("ID"=12345)


Statistics
----------------------------------------------------------
          0  recursive calls
          0  db block gets
          3  consistent gets
          0  physical reads
          0  redo size
        668  bytes sent via SQL*Net to client
        389  bytes received via SQL*Net from client
          1  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed

-- Turn off AUTOTRACE
SET AUTOTRACE OFF;
```
The advantage of `AUTOTRACE` is that it provides actual runtime statistics, but its prerequisite is that **the SQL must complete its execution**. This method is not suitable for long-running SQL.

### III. Intermediate: Diagnosing the "Actual Path" on a Live System

When troubleshooting performance issues in a production environment, it is crucial to obtain the **current or most recent actual execution plan** of the SQL. This real execution information is stored in Oracle's Shared Pool.

#### `DBMS_XPLAN.DISPLAY_CURSOR`: The "Killer App" for Precise Diagnostics

`DBMS_XPLAN.DISPLAY_CURSOR` is the premier tool for diagnosing online SQL performance issues. It can extract the actual execution plan of a specific SQL from the Shared Pool, complete with precise runtime statistics (such as actual rows returned and actual execution time).

This is like retrieving data from a car's Event Data Recorder (EDR), which faithfully records every step of the SQL's execution, along with the actual output and time consumed for each step. A significant discrepancy between estimated rows (E-Rows) and actual rows (A-Rows) is often the key to identifying optimizer estimation errors and discovering performance problems.

**Steps:**

1.  **Find the `SQL_ID` of the target SQL**:

```sql
-- Find the SQL_ID from v$sql using a fragment of the SQL text
SELECT sql_id, child_number, sql_text 
FROM v$sql 
WHERE sql_text LIKE 'SELECT /* BAD_SQL */%';

SQL_ID        CHILD_NUMBER SQL_TEXT
------------- ------------ -------------------------------------------------------------------------
fanswvakttff4            0 SELECT /* BAD_SQL */ * FROM t_users WHERE TRIM(status) = 'INACTIVE'
fanswvakttff4            1 SELECT /* BAD_SQL */ * FROM t_users WHERE TRIM(status) = 'INACTIVE'

```

2.  **Extract and display the real execution plan**:

```sql
-- Assuming the found sql_id is 'fanswvakttff4'
-- The 'ALLSTATS LAST' parameter is used to get complete runtime statistics for the last execution
SQL> set line 300 pages 999 long 999999
SQL> SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('fanswvakttff4', null, 'ALLSTATS LAST'));

PLAN_TABLE_OUTPUT
----------------------------------------------------------------------------------
SQL_ID  fanswvakttff4, child number 0
-------------------------------------
SELECT /* BAD_SQL */ * FROM t_users WHERE TRIM(status) = 'INACTIVE'

Plan hash value: 616708042

----------------------------------------------
| Id  | Operation         | Name    | E-Rows |
----------------------------------------------
|   0 | SELECT STATEMENT  |         |        |
|*  1 |  TABLE ACCESS FULL| T_USERS |   1000 |
----------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter(TRIM("STATUS")='INACTIVE')

Note
-----
   - Warning: basic plan statistics not available. These are only collected when:
       * hint 'gather_plan_statistics' is used for the statement or
       * parameter 'statistics_level' is set to 'ALL', at session or system level

SQL_ID  fanswvakttff4, child number 1
-------------------------------------
SELECT /* BAD_SQL */ * FROM t_users WHERE TRIM(status) = 'INACTIVE'

Plan hash value: 616708042

----------------------------------------------
| Id  | Operation         | Name    | E-Rows |
----------------------------------------------
|   0 | SELECT STATEMENT  |         |        |
|*  1 |  TABLE ACCESS FULL| T_USERS |  10000 |
----------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter(TRIM("STATUS")='INACTIVE')

Note
-----
   - statistics feedback used for this statement
   - Warning: basic plan statistics not available. These are only collected when:
       * hint 'gather_plan_statistics' is used for the statement or
       * parameter 'statistics_level' is set to 'ALL', at session or system level


49 rows selected.

```

**Case Study: Full Table Scan Caused by Function on an Indexed Column**

Let's examine a typical scenario where an index is invalidated due to improper function usage.

```sql
-- Bad practice: Using a function on an indexed column prevents the CBO from using the index
SELECT /* BAD_SQL */ * FROM t_users WHERE TRIM(status) = 'INACTIVE';
```
By viewing its execution plan with `DISPLAY_CURSOR`, you will find that it performs a `TABLE ACCESS FULL`. Furthermore, there may be a large discrepancy between `A-Rows` (actual rows) and `E-Rows` (estimated rows).

```sql
-- Best practice: Ensure the indexed column in the predicate remains pristine
SELECT /* GOOD_SQL */ * FROM t_users WHERE status = 'INACTIVE';
```
The execution plan for the optimized SQL will correctly use an `INDEX RANGE SCAN`. By comparing the `A-Rows` and `A-Time` (actual time for each operation) of the two, the performance difference becomes obvious.

### IV. Advanced: Deep "Forensic" Analysis

For performance issues that are deeply hidden and complex, more low-level tools are required for a thorough diagnosis.

#### 1. SQL Trace (Event 10046) & TKPROF

SQL Trace is a powerful diagnostic mechanism that can record all database calls, wait events, CPU time, and other low-level activities within a SQL session, generating a trace (.trc) file. This is equivalent to installing a comprehensive, millisecond-level monitoring probe on the SQL's execution process.

Subsequently, the `TKPROF` utility is used to format and summarize the raw trace file, producing a highly readable performance analysis report that precisely reveals every detail of time consumption.

**When to use it:**
When a SQL's performance bottleneck is primarily manifested in wait events (e.g., `db file sequential read`, which represents physical I/O waits) rather than CPU consumption, SQL Trace is the ultimate arbiter. It clearly shows where the time was spent "waiting."

**Note:** Enabling SQL Trace incurs a certain performance overhead and should be used cautiously in production environments, typically as a "last resort" for solving difficult problems.

#### 2. AWR Reports & `DBMS_XPLAN.DISPLAY_AWR`

The Automatic Workload Repository (AWR) is Oracle's built-in performance data "black box," which periodically (every hour by default) snapshots key database performance metrics and high-load SQL.

When investigating historical performance issues (e.g., "the system was slow at 3 PM yesterday"), AWR reports provide invaluable data for retrospective analysis. By analyzing the "Top SQL" section of the report, one can identify the most resource-intensive SQL during the problematic period. Then, using the `DBMS_XPLAN.DISPLAY_AWR` function, the execution plan of that SQL at that specific point in time can be precisely extracted from the historical snapshot.

```sql
-- Retrieve a historical execution plan for a specific SQL_ID from AWR
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('fanswvakttff4'));
```
This method is particularly effective for analyzing "SQL performance is sometimes good, sometimes bad" issues, which are often caused by sudden execution plan changes (Plan Flips).

### Summary and Decision Guide

The choice of which tool to use for obtaining an execution plan depends on the specific scenario and analysis goal. Here is a concise decision-making flow:

*   **Scenario: SQL Development & Code Review**
    *   **Preferred Tool**: `EXPLAIN PLAN` or IDE-integrated tools.
    *   **Goal**: Quickly verify the correctness of syntax, access paths, and index usage strategies.

*   **Scenario: Real-time Slow Query Diagnosis on a Live System**
    *   **Preferred Tool**: `DBMS_XPLAN.DISPLAY_CURSOR`.
    *   **Goal**: Obtain the execution plan with actual runtime statistics to accurately pinpoint performance bottlenecks.

*   **Scenario: Analyzing Long-Running Batch Jobs**
    *   **Preferred Tool**: Real-Time SQL Monitoring (`V$SQL_MONITOR`).
    *   **Goal**: Dynamically track execution progress and identify the most time-consuming steps.

*   **Scenario: Post-mortem of Historical Performance Incidents**
    *   **Preferred Tool**: AWR reports combined with `DBMS_XPLAN.DISPLAY_AWR`.
    *   **Goal**: Analyze high-load historical SQL and its execution plan at the time of the issue.

*   **Scenario: In-depth Analysis of Complex Wait Event Issues**
    *   **Preferred Tool**: SQL Trace (10046) with TKPROF.
    *   **Goal**: Conduct a "forensic" analysis of the SQL execution process to quantify all waits and resource consumption.

Mastering the methods to obtain execution plans is the starting point for SQL optimization. A deeper level of skill lies in accurately interpreting the plan's content and understanding the optimizer's decision-making logic behind it.

