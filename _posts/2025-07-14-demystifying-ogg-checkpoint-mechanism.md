---
layout: post
title: 'Demystifying the OGG Checkpoint Mechanism: From CPE/CPR/CPT Files to Breakpoint Resume Principles'
excerpt: 'A comprehensive analysis of the OGG Checkpoint mechanism, including its file structure, breakpoint resume principles, and operational best practices.'
date: 2025-07-14 13:57:00 +0800
categories: [Oracle GoldenGate, Data Replication]
tags: [ogg, checkpoint, cpe, cpr, cpt, breakpoint resume, data consistency]
author: Shane
---

"If my OGG Extract process crashes at 3 AM, what should I do?"

This is a question I receive almost every time during customer training. My answer is always straightforward: "Do nothing, just `START` it." This confidence is not unfounded—it stems from a deep understanding of the cornerstone of Oracle GoldenGate's high reliability: the Checkpoint mechanism.

Almost all OGG users know it can "resume from breakpoint" after exceptions, but what exactly is this "breakpoint"? Where does it exist? When a large transaction containing tens of thousands of records is interrupted halfway through processing, how does OGG ensure that after restart, it neither repeats nor misses, but precisely continues?

This "black box" understanding of internal mechanisms is often the root cause of users' unease. Today, I will thoroughly dissect the Checkpoint mechanism, showing you how it builds an indestructible data protection system through several small files. After reading this article, you will be able to trust OGG from the bottom of your heart and make safer operational decisions.

# 1. The "Three Musketeers" of Checkpoint: CPE, CPR, and CPT Files

To understand Checkpoint, we must first recognize the three core files responsible for recording it. They are typically located in the `dirchk` subdirectory of the OGG installation directory, named after the process name, with `.cpe`, `.cpr`, and `.cpt` as extensions.

*   **`.cpe` (Extract Checkpoint File)**: **The Extract process's exclusive "navigation log"**.
    *   **Purpose**: It records the position of the **last data record** that Extract has successfully processed and written to the Trail File. This position information is very precise—for Oracle sources, it records the sequence number and RBA (Relative Byte Address) of the Redo log file; for other databases, it records the corresponding log sequence number (such as PostgreSQL's LSN).
    *   **Operation**: Extract updates the `.cpe` file every time it successfully writes a complete transaction to the Trail File. When the Extract process restarts, it first reads this file, finds the "navigation coordinates" recorded last time, and then tells the database: "Please give me new log information from the position after this coordinate."

*   **`.cpr` (Replicat Checkpoint File)**: **The Replicat process's "work ledger"**.
    *   **Purpose**: This is Replicat's checkpoint file, recording the position of the last transaction it has read from the Trail File and **successfully applied to the target database**.
    *   **Operation**: Replicat reads data from the Trail File and, after successfully `COMMIT`ting a transaction on the target side, updates the `.cpr` file, recording the position of this transaction in the Trail File. If Replicat crashes, after restart it reads the `.cpr` file and knows from which position in the Trail File it should start reading again, thus avoiding reapplying already committed transactions.

*   **`.cpt` (Checkpoint Table)**: **The "buffer" for transaction status**. (Note: This usually refers to Replicat's checkpoint table, but may also refer to transaction status files in the file system).
    *   **Purpose**: This mechanism is the **essence** of achieving "no repetition, no omission." For those **long transactions** that span multiple Trail Files or contain massive operations, Replicat periodically persists the **internal processing progress** of the current transaction (such as how many records have been applied) and other status information to this "buffer" during processing.
    *   **Operation**: Imagine a large transaction containing 10,000 `INSERT` statements. Replicat crashes when applying the 5,000th record. Without `.cpt`, after restart it can only reapply from the beginning of this transaction, causing 5,000 duplicate records. But with `.cpt`, Replicat will first check this buffer after restart, discovering "oh, I've already processed half of this large transaction," so it will directly start applying from the 5,001st record, thus achieving **precise breakpoint resume within transactions**.

**Checkpoint Mechanism Workflow Diagram**
![Checkpoint Mechanism Workflow]({{ '/assets/images/ogg/ogg-checkpoint-mechanism-workflow.svg' | relative_url }})

# 2. Code Practice: Observing and Operating Checkpoints

Theory is dry, so let's use commands in GGSCI to see firsthand how Checkpoint works.

## Viewing Checkpoint Information

Using the `INFO` command, we can clearly see the checkpoint information recorded by each process.

**Viewing Extract's Checkpoint:**
```sh
-- Execute in GGSCI
INFO EXTRACT extora, DETAIL
```
You'll see output similar to the following, which is exactly the information read from the `.cpe` file:
```
EXTRACT    EXTORA    Last Started 2025-06-19 12:29   Status RUNNING
Checkpoint Lag       00:00:00 (updated 00:00:07 ago)
Process ID           4467
Log Read Checkpoint  Oracle Integrated Redo Logs
                     2025-07-09 10:20:11
                     SCN 0.10607098 (10607098)

```
Here, `SCN 0.10607098` is Extract's "navigation coordinate."

**Viewing Replicat's Checkpoint:**
```sh
-- Execute in GGSCI
INFO REPLICAT repmysql, DETAIL
```
The output will show from which position (RBA) in which Trail File Replicat starts reading, and this information comes from the `.cpr` file.
```
REPLICAT   REPMYSQL  Last Started 2025-06-19 13:37   Status RUNNING
Checkpoint Lag       00:00:00 (updated 00:00:02 ago)
Process ID           4673
Log Read Checkpoint  File ./dirdat/my000000000
                     2025-06-19 12:30:11.979107  RBA 4539575

```

## Manual Checkpoint Operations (High Risk, Use with Caution!)

In certain special operational scenarios (such as after data initialization), we may need to manually set the starting position of a process. At this time, you are operating on the Checkpoint files.

```sh
-- Warning: This is a dangerous operation that will skip all previous data!
-- Force Extract to start extracting from the current latest Redo log
ALTER EXTRACT extora, BEGIN NOW

-- Force Replicat to start reading from the specified Trail File
ALTER REPLICAT repmysql, EXTTRAIL ./dirdat/my, EXTSEQNO 1, EXTRBA 0
```
When executing these commands, OGG will **rewrite** the corresponding `.cpe` or `.cpr` file in the background, setting the new starting position as the "official record." This is why **operational risks stem from ignorance of Checkpoint**. If you don't understand the consequences of this operation, you may easily cause data loss or duplication.

# 3. Principle-Based Operational Guidance: Golden Rules for Safe Operations

After understanding the Checkpoint mechanism, we can summarize several golden rules to guide our daily operations.

1.  **Trust the process, not manual copying**: Never try to "recover" or "migrate" an OGG process by manually copying the `dirchk` directory. Checkpoint files contain a large amount of environment-related information, and direct copying will almost certainly cause problems. The correct approach is to use OGG's standard processes (such as `ALTER` commands) to manage process positions.

2.  **Chain integrity**: Checkpoint is transmitted along the `Extract -> Pump -> Replicat` chain. The Checkpoint of downstream processes (positions consumed by Replicat) will notify upstream processes (Pump and Extract) in reverse, telling them which Trail Files are "safe to clean." This is the principle of the `USECHECKPOINTS` parameter in the `PURGEOLDEXTRACTS` command. Therefore, when troubleshooting problems, always treat the data chain as a whole.

3.  **"Think twice before acting" for reset operations**: Before executing any commands like `ALTER ... BEGIN ...` or `ALTER ... EXTSEQNO ...`, ask yourself three questions:
    *   Do I clearly know which data will be skipped by this operation?
    *   Does the target data state already match the new starting point I want to set?
    *   Do I have a rollback plan?
    Deep understanding of Checkpoint is the foundation for confidently answering these three questions.

# Summary

Today, we thoroughly dissected the core of OGG's high reliability—the Checkpoint mechanism. It is not a single "point," but a system of precise collaboration between multiple files and processes.

Let's review its core concepts:

| File/Mechanism | Role | Problem Solved |
| :--- | :--- | :--- |
| **`.cpe` file** | Extract's navigation log | Records the precise position of **log reading**, ensuring Extract doesn't reread or miss reads after restart. |
| **`.cpr` file** | Replicat's work ledger | Records the position of **applied transactions** in the Trail File, preventing Replicat from reapplying after restart. |
| **`.cpt` mechanism** | Buffer for long transactions | Records the processing progress **within large transactions**, achieving transaction-level precise breakpoint resume, which is the essence of "no repetition, no omission." |

This system transforms OGG processes from simple "read-write" programs into "intelligent agents" with powerful memory and recovery capabilities. It is precisely this ability to accurately record and recover state that enables OGG to steadfastly fulfill its mission of data synchronization even under various exceptional circumstances.

Now, when someone asks you "what to do if the OGG process crashes," you can not only confidently tell them "just start it," but also clearly explain the powerful technical principles behind it.