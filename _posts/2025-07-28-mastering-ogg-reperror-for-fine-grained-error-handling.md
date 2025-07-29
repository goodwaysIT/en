---
layout: post
title: "Don't Let Replicat Abend Easily: Achieving Fine-Grained Error Handling with REPERROR"
excerpt: "Say goodbye to the nightmare of frequent Replicat ABENDs. This article provides an in-depth explanation of the OGG REPERROR parameter, teaching you how to break free from the 'all-or-nothing' dilemma. By using DISCARD and TRANSACTION options, you can build a resilient, auditable, and fine-grained error handling strategy, achieving the perfect balance between high system availability and data consistency."
date: 2025-07-28 18:02:00 +0800
categories: [Oracle GoldenGate, Error Handling]
tags: [ogg, replicat, reperror, error handling, discard, abend]
author: Shane
image: /assets/images/posts/ogg-reperror-banner.svg
---

During the data synchronization process, the OGG Replicat process often terminates abnormally (ABENDs) due to various database errors (such as ORA-00001 unique constraint violations). This not only interrupts data synchronization, leading to accumulated latency, but can also impact business continuity. At this moment, you probably have only two choices in mind: either manually handle the conflicting data on the target and restart the process, or simply add a line `REPERROR (DEFAULT, IGNORE)` to the parameter file to "turn a blind eye," and then pray that no important data is lost as a result.

This is the "all-or-nothing" dilemma that countless OGG operations engineers have faced. We seem to be forced to choose between two evils: "system unavailable" and "data unreliable."

But that's not the case. Today, I want to introduce you to the "third way" of OGG error handling, a Swiss Army knife that can transform you from a reactive firefighter into a proactive system architect—the `REPERROR` parameter. After reading this article, you will learn how to build a resilient and auditable error handling system that allows your Replicat to handle "minor issues" gracefully while promptly alerting you to "major problems," achieving truly elegant operation.

### 1. The Root of the Dilemma: The "Fragility" of Default Behavior

First, we need to understand that Replicat's default behavior is actually a "safety-first" design. It is very "honest"; whenever it encounters a problem it cannot solve, its first reaction is to stop (ABEND) and report the problem to you. The intention behind this design is good, as it ensures that no unexpected data issues are quietly swept under the rug.

But in complex production environments, many errors are predictable and even "benign." For example:
*   **ORA-00001 (unique constraint violated)**: This might happen if the target end re-inserts some data after it was mistakenly deleted during data archiving or cleanup.
*   **ORA-01403 (no data found)**: In a bidirectional synchronization setup, if a record is deleted on side A and this deletion is synchronized to side B, but at the same time, side B also manually deletes the same record. Then, when the deletion operation from A reaches B, it will report ORA-01403 because it cannot find the data to delete.

For these errors, halting the entire synchronization link is clearly "making a mountain out of a molehill" and not worth the cost.

**Error Handling Flow Diagram**
![Replicat Error Handling Flow]({{ '/assets/images/ogg/ogg-reperror-error-handling-flow.svg' | relative_url }})

### 2. `REPERROR`: From "One-Size-Fits-All" to "Precision Strike"

The power of the `REPERROR` parameter lies in its ability to let you define **specific handling actions** based on **specific error codes**. Let's look at some of its core uses.

#### `IGNORE` vs `DISCARD`: To Keep a "Record" or Not?

These are the most basic and most important options for `REPERROR`.

*   **`IGNORE`**: This is the "crudest" way of handling things. It tells Replicat: "When you see this error, just pretend it didn't happen, skip this operation, and move on."
    *   **Advantage**: Simple and direct.
    *   **Fatal Flaw**: **Data is lost silently**. You have no logs or records to track which operations were ignored. This is the beginning of a data reconciliation nightmare, and I strongly recommend **avoiding the use of `IGNORE` in production environments**.

*   **`DISCARD`**: This is the "gold standard" I recommend. It tells Replicat: "When you see this error, skip this operation too, but please be sure to log the complete information of this operation—including error details, SQL statements, transaction information, etc.—verbatim into the **Discard File**."
    *   **Advantage**: It ensures the continuous operation of the process while providing **complete audit tracking**. You can periodically check the discard file, analyze the discarded operations, and perform manual repairs, thereby ensuring eventual data consistency.

#### Configuring the Discard File

To use `DISCARD`, you must first define the location and rules for the discard file in your Replicat parameter file.

```ini
-- Replicat parameter file (rep_main.prm)
REPLICAT rep_main
USERIDALIAS ogg_tgt_alias DOMAIN OracleGoldenGate

-- Define the discard file; the process name and sequence number will be appended automatically.
-- PURGEONDAYS 7 means retain discard files for 7 days, then clean up automatically.
-- MEGABYTES 100 means each discard file can be a maximum of 100MB.
DISCARDFILE ./dirrpt/rep_main.dsc, APPEND, PURGEONDAYS 7, MEGABYTES 100

-- This is our error handling strategy
-- When an ORA-00001 error is encountered, perform a DISCARD operation.
REPERROR (ORA-00001, DISCARD)

-- MAP statement
MAP sales.*, TARGET sales.*;
```
Once configured, when Replicat encounters an `ORA-00001` error, it will no longer ABEND. Instead, it will generate a `.dsc` file in the `./dirrpt/` directory with content similar to this:
```
Oracle GoldenGate Delivery for Oracle process started, group REP_MAIN...
...
2023-10-27 16:30:15  WARNING OGG-01154  Oracle GoldenGate Delivery for Oracle, rep_main.prm:  SQL error 1 mapping SALES.ORDERS to SALES.ORDERS.
OCI Error ORA-00001: unique constraint (SALES.PK_ORDERS) violated
...
-- The full SQL statement that caused the error will be listed here
INSERT INTO "SALES"."ORDERS" ("ORDER_ID", "CUSTOMER_ID", "ORDER_DATE", "AMOUNT")
VALUES (1001, 205, TO_DATE('2023-10-27 16:30:00', 'YYYY-MM-DD HH24:MI:SS'), 599.99);
```
With this file, you have all the evidence you need to trace and fix the problem.

### 3. Building an Intelligent "Tiered Error Strategy"

The true power of `REPERROR` is that you can define a multi-layered, fine-grained error handling strategy, just like an experienced doctor writing a prescription.

*   **For "minor issues" (predictable, benign errors), log them and move on.**
*   **For "medium problems" (which might indicate data inconsistency), terminate the current transaction, but the process does not exit.**
*   **For "serious illnesses" (unknown or severe errors), have the process ABEND immediately to attract human attention.**

We can achieve this by stacking `REPERROR` rules. Replicat will match the rules from top to bottom, and once a match is found, it executes the corresponding action.

**A Production-Grade `REPERROR` Configuration Example:**
```ini
-- Replicat parameter file (rep_prod.prm)
REPLICAT rep_prod
USERIDALIAS ogg_tgt_alias DOMAIN OracleGoldenGate
DISCARDFILE ./dirrpt/rep_prod.dsc, APPEND, PURGEONDAYS 14, MEGABYTES 200

-- === Fine-Grained Error Handling Strategy ===

-- 1. For unique key conflicts (ORA-00001), log to the discard file and continue.
REPERROR (ORA-00001, DISCARD)

-- 2. For "row not found for update/delete" (ORA-01403), this may indicate data inconsistency.
--    We choose TRANSACTION-level handling: discard all operations in the current transaction,
--    write the entire transaction to the discard file, and then start processing from the next transaction.
--    This is more elegant than ABEND because it does not interrupt the entire service.
REPERROR (ORA-01403, TRANSACTION)

-- 3. For all other unspecified database errors (DEFAULT),
--    we want the process to ABEND immediately to get the DBA's attention, preventing unknown issues from being hidden.
--    This is the final safety net.
REPERROR (DEFAULT, ABEND)

MAP fin.*, TARGET fin.*;
```
This configuration reflects the idea of tiered handling:
*   **`DISCARD`**: Operation-level handling, affects only a single DML.
*   **`TRANSACTION`**: Transaction-level handling, affects all DMLs in the current transaction.
*   **`ABEND`**: Process-level handling, interrupts the entire service.

### Conclusion: From "Firefighting" to "Fire Prevention"

By skillfully using `REPERROR`, we have completely changed the way we interact with Replicat errors.

| Handling Method | Pros | Cons | Applicable Scenarios |
| :--- | :--- | :--- | :--- |
| **Default (ABEND)** | Safe, problems are not ignored | Poor system availability, requires frequent manual intervention | Critical, unknown errors |
| **`IGNORE`** | Process does not interrupt | **Data black hole, unauditable** | **Strongly not recommended for production** |
| **`DISCARD`** | Process does not interrupt, **fully auditable** | Requires periodic checking of the discard file | Predictable, acceptable single-point errors |
| **`TRANSACTION`**| Isolates the problematic transaction, process does not interrupt | Discards data for the entire transaction | Errors where a logical problem is suspected |

Next time your Replicat hangs due to a common error, don't just reflexively `SKIPTRANSACTION` or crudely `IGNORE`. Take a moment to think about the nature of the error, and then tailor a `REPERROR` rule for it.

This is not just about solving a technical problem; it's a shift in your mindset as a data professional—from a reactive "firefighter" to a proactive "fire prevention system designer." 