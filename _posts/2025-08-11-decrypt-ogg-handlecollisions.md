---
layout: post
title: "Demystifying OGG `HANDLECOLLISIONS`: A Deep Dive from Firefighting to Data Consistency"
excerpt: "Learn how to correctly use Oracle GoldenGate's HANDLECOLLISIONS parameter. This article provides a detailed explanation of its mechanics, risks, use cases, and best practices to help you avoid data inconsistency pitfalls."
date: 2025-08-11 17:35:00 +0800
categories: [Oracle GoldenGate, Data Consistency]
tags: [ogg, handlecollisions, reperror, data conflict, data consistency, replicat]
author: Shane
image: /assets/images/posts/oracle_goldengate_handlecollisions_flowchart.svg
---

If there's one parameter in GoldenGate that DBAs and data engineers have a love-hate relationship with, `HANDLECOLLISIONS` is undoubtedly at the top of the list. Picture a typical "3 AM alert" scenario: a production Replicat process abends due to an `ORA-00001: unique constraint violated` error, data synchronization halts, and business operations are at risk. In this moment, the seemingly simple `HANDLECOLLISIONS` parameter can bring the process back to life, but the cost might be far greater than you imagine.

This article will take you deep into its working principles, analyze its pros and cons in various scenarios, and provide you with a clear decision-making framework. After reading, you will be able to confidently decide when to use it for "firefighting" and when to stay away, choosing better alternatives to ensure your data consistency.

## 1. The Root of Conflicts: Why Does My Replicat Keep Crashing?

Before configuring `HANDLECOLLISIONS`, we must, like a doctor, first diagnose the "illness." A Replicat abend is just a symptom; behind it lies a real data conflict. In the context of OGG, conflicts are mainly divided into three categories:

*   **INSERT Conflict**: Replicat attempts to insert a row into a target table, but a row with the same primary or unique key already exists. This typically causes the database to throw an `ORA-00001` (Oracle) or similar unique constraint error.
*   **UPDATE Conflict**: Replicat attempts to update a row, but it cannot find the row in the target table based on the primary key.
*   **DELETE Conflict**: Replicat attempts to delete a row, but similarly, it cannot find the row in the target table.

In Oracle, the latter two situations usually result in an `ORA-01403: no data found` error, causing the Replicat to abend.

So, where do these conflicts come from? Based on my project experience, the root causes are usually one of the following:

1.  **A "Gap" Between Initial Load and Incremental Sync**: This is the most common reason. After you perform an initial load using tools like expdp/impdp, RMAN, or OGG, and then start Extract/Replicat for incremental synchronization, if the starting point (CSN/LSN) of the incremental capture does not perfectly align with the data snapshot point of the initial load, the data within this "gap" or "overlap" will cause conflicts.
2.  **The Target Is Not "Clean"**: The target database is not a pure, read-only replica. Other applications, batch jobs, or even manual operations by a DBA are inserting, modifying, or deleting data on the target, breaking the mirror image relationship between the source and target.
3.  **Bi-Directional or Active-Active Replication**: In an Active-Active architecture, conflicts are an expected part of the design. Sides A and B might simultaneously insert data with the same primary key. When these operations are replicated to the opposite side, an INSERT conflict is inevitable.
4.  **Non-Logged Operations on the Source**: For example, executing an operation with the `NOLOGGING` or `UNRECOVERABLE` option in Oracle, or using the `TRUNCATE TABLE` command (although OGG can support `TRUNCATE`, improper configuration can still cause issues). These operations might not be fully captured by the Extract process, leading to a state mismatch between the source and target.

Understanding these root causes makes it clear that simply telling Replicat to "ignore" these errors does not solve the underlying problem.

## 2. The Double-Edged Sword of `HANDLECOLLISIONS`: How It Fights Fires and Plants Landmines

Now, let's unveil the mystery of `HANDLECOLLISIONS`. When you add it to your Replicat parameter file, it changes the default behavior for handling the conflicts mentioned above.

**How It Works (The "Firefighting")**

The logic of `HANDLECOLLISIONS` is very direct, almost "brute-force":

*   **On an INSERT Conflict** (record already exists on target): It no longer abends the process. Instead, it **forcibly converts the `INSERT` operation into an `UPDATE` operation**. It uses all the column values from the record in the Trail file to overwrite the existing record with the same primary key in the target table.
*   **On an UPDATE or DELETE Conflict** (record does not exist on target): It also does not abend. Instead, it **silently ignores (discards) the `UPDATE` or `DELETE` operation** and proceeds to the next record without a trace.

**Key Takeaway**: The sole purpose of `HANDLECOLLISIONS` is to **ensure the continuity of the Replicat process, not to guarantee absolute data consistency**. It bypasses errors using a strategy of "overwrite" and "ignore" to keep the data flowing.

**The Potential Risks (The "Landmines")**

The risks of this mechanism are obvious. Consider this scenario:

1.  Source: `UPDATE table SET status='A' WHERE id=1;`
2.  Target: For some reason, the record with id=1 was accidentally deleted.
3.  When Replicat applies this update, it encounters a "no data found" conflict.
4.  If `HANDLECOLLISIONS` is enabled, this `UPDATE` operation will be **silently discarded**.
5.  The result: The record with id=1 has `status` 'A' on the source, but the record does not exist at all on the target. **Data inconsistency is born, and no OGG report will ever tell you about this "ignore" event.**

`HANDLECOLLISIONS` is like a powerful painkiller. It can quickly relieve the pain of a process abend, but it also masks the deep-seated illness of data inconsistency, allowing silent data drift to accumulate until it explodes during a business reconciliation.

## 3. In Practice: Using `HANDLECOLLISIONS` Correctly

Despite the risks, `HANDLECOLLISIONS` can still be an effective tool in specific scenarios. Here's how to configure it in OGG 19c/21c.

**Syntax and Examples**

`HANDLECOLLISIONS` can be configured at two levels: global and table-specific. **My strong recommendation is to always prioritize table-level configuration to minimize the scope of impact.**

**Incorrect Example: Global Configuration (Not Recommended)**

```prm
-- rep01.prm
-- This is not a recommended configuration as it applies to all tables, posing a high risk.
REPLICAT rep01
USERIDALIAS ogg_tgt DOMAIN OracleGoldenGate
HANDLECOLLISIONS
MAP sales.customers, TARGET sales.customers;
MAP sales.orders, TARGET sales.orders;
MAP hr.employees, TARGET hr.employees;
```

**Correct Example: Table-Level Configuration (Recommended)**

Let's say we only want to handle conflicts for the `sales.orders` table because we know there might be data discrepancies during its initialization phase.

```prm
-- rep01.prm
-- This is a safer configuration, isolating the risk to a known table.
REPLICAT rep01
USERIDALIAS ogg_tgt DOMAIN OracleGoldenGate

-- Enable conflict handling for the orders table
MAP sales.orders, TARGET sales.orders, HANDLECOLLISIONS;

-- Other tables are not enabled; any conflict will cause an abend, allowing us to detect issues promptly.
MAP sales.customers, TARGET sales.customers;
MAP hr.employees, TARGET hr.employees;
```

By adding `, HANDLECOLLISIONS` to the `MAP` statement, we precisely limit its scope to the `sales.orders` table. For the `customers` and `employees` tables, any conflict will still cause a normal abend, which is exactly what we want—to expose unknown problems.

**Diagram: The `HANDLECOLLISIONS` Workflow**

![Oracle GoldenGate Handlecollisions Flow Chart]({{ '/assets/images/ogg/oracle-goldengate-handlecollisions-flowchart.svg' | relative_url }})

## 4. Decision Guide: When to Use `HANDLECOLLISIONS` vs. Better Alternatives

Now for the most critical part: should I actually use it?

**Reasonable Use Cases for `HANDLECOLLISIONS`**

1.  **Temporary "Firefighter"**: When a production Replicat abends unexpectedly, the business impact is significant, and you cannot identify and fix the data issue in a short time. You can temporarily add `HANDLECOLLISIONS` to get the process running, **but you must**:
    *   Enable it only for the problematic table.
    *   Immediately create a ticket to have a DBA or data engineer investigate the root cause.
    *   **Remove the parameter** as soon as the problem is resolved.

2.  **One-Time Data Synchronization or Migration**: During a data migration or when setting up a new disaster recovery database, if you know there are minor discrepancies between source and target and the business requirement is to treat the source as the absolute truth, you can use `HANDLECOLLISIONS` for a forced overwrite to quickly align the data. It should be considered for removal after synchronization stabilizes.

3.  **Bi-Directional/Active-Active Architecture**: This is the most legitimate use case for `HANDLECOLLISIONS`. In an Active-Active environment, conflicts are expected behavior. Even so, `HANDLECOLLISIONS` is just one part of a Conflict Detection and Resolution (CDR) mechanism. It usually needs to be combined with other parameters like `GETAPPLOPS`, `USEMAX`, or custom conflict resolution logic to ensure "last update wins" or to implement more complex business rules, rather than simply overwriting.

**A Better Alternative: Precise Control with `REPERROR`**

In the vast majority of uni-directional replication scenarios, if I need to ignore specific, known, and acceptable errors, I much prefer using the `REPERROR` parameter.

`REPERROR` allows you to define specific actions (like `ABEND`, `DISCARD`, `RETRY`) for specific database error codes.

**`HANDLECOLLISIONS` vs. `REPERROR`**

| Feature      | `HANDLECOLLISIONS`                                        | `REPERROR`                                           |
| :----------- | :-------------------------------------------------------- | :--------------------------------------------------- |
| **Granularity**| Coarse-grained, handles a fixed set of conflict types.    | Fine-grained, can target any database error code.    |
| **Behavior**   | Fixed: "Insert to Update," "Ignore Update/Delete."      | Customizable actions (`DISCARD`, `ABEND`, `RETRY`).  |
| **Transparency**| Behavior is implicit and easy to overlook.                | Error handling rules are explicit in the param file. |
| **My Advice**  | Use only for the specific scenarios mentioned above.       | **The preferred error handling solution for production uni-directional sync.** |

**`REPERROR` Configuration Example**

Suppose we only want to ignore INSERT failures due to primary key conflicts (`ORA-00001`), but for "no data found" errors (`ORA-01403`), we still want the process to abend for investigation.

```prm
-- rep01.prm
-- Using REPERROR for precise control
REPLICAT rep01
USERIDALIAS ogg_tgt DOMAIN OracleGoldenGate

-- On an ORA-00001 error, log the operation to the discard file and continue
REPERROR (1, DISCARD)

-- On an ORA-01403 error, the default behavior (Abend) is still performed
-- (because no rule is defined for 1403)

MAP sales.orders, TARGET sales.orders;
```

This configuration is much safer than `HANDLECOLLISIONS`. It does not convert an `INSERT` to an `UPDATE`, avoiding unintentional data overwrites. At the same time, it logs all discarded operations to the discard file, allowing you to review what happened later.

## Conclusion

`HANDLECOLLISIONS` is a powerful tool, but with great power comes great risk. Finally, here is a decision checklist for you, instead of a hollow "in conclusion."

*   **Are you in a temporary firefighting situation?** -> **Use it**, but only on the problem table, and plan to remove it ASAP.
*   **Are you doing a one-time data alignment where the source is king?** -> **Consider it**, and remove it after completion.
*   **Are you configuring a bi-directional/active-active setup?** -> **Use it**, but as part of a complete CDR strategy, not as the sole solution.
*   **Are you in a standard uni-directional replication environment?** -> **Don't use it!** Prefer `REPERROR` for handling specific, known errors.
*   **You don't know why it's failing and just want the process to run?** -> **Absolutely do not use it!** This is masking the problem. Diagnose the root cause first.

Remember, the core of data synchronization is **consistency** and **reliability**. Any shortcut that sacrifices these for the sake of a seemingly "continuously running" process will ultimately cost you more.