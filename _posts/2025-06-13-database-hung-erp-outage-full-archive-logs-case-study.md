---
layout: post
title: "\"Database Hung\": A Case Study of a Critical ERP Outage Caused by Full Archive Logs"
excerpt: "A detailed case study of a critical ERP system outage triggered by full Oracle archive logs. This post walks through the emergency response, analyzes the impact, and outlines crucial preventative measures focusing on monitoring, robust backup strategies, and proactive capacity planning to avoid similar database disasters."
date: 2025-06-13 10:00:00 +0800
categories: [Oracle, Database Administration, Incident Management, Case Study]
tags: [oracle, database hung, archive log full, ORA-15041, ORA-00257, ERP outage, RAC, ASM, RMAN, database monitoring, backup strategy, capacity planning, incident response, critical system]
# image: /assets/images/posts/your-image-here.jpg
---

# **An Unsettling Night**

Late one night, our support team received an urgent call from a client. Their core ERP system was completely inaccessible, bringing all business operations to a halt. For a 24/7 system like this, every minute of downtime translates to tangible business losses.

Team members responded immediately. A preliminary check showed that the application servers themselves had normal load, but their logs were filled with database connection timeouts and rejection errors. All signs pointed to the backend Oracle RAC database.

We attempted to connect to the database via a bastion host. Connection requests from regular business users were simply left hanging, but a login with DBA privileges succeeded instantly:

```bash
sqlplus / as sysdba
```

This phenomenon, where privileged users can connect while regular users are blocked, is a classic signal that the database has entered a restricted state. Wasting no time, we immediately checked the database's "EKG"—the `alert` log. At the tail end of the log on one of the RAC nodes, we found the heart-stopping error message:

```log
Tue May 06 02:15:10 2025
Errors in file /u01/app/oracle/diag/rdbms/orcl/ORCL1/trace/ORCL1_arc2_23456.trc:
ORA-19504: failed to create file "+ARCH/orcl/archivelog/2025_05_06/thread_2_seq_12345.285.1167890123"
ORA-17502: ksfdcre:4 Failed to create file +ARCH/orcl/archivelog/2025_05_06/thread_2_seq_12345.285.1167890123
ORA-15041: diskgroup "ARCH" space exhausted
...
Tue May 06 02:18:20 2025
ARC0: Archival stopped, error all standby destinations.
...
Tue May 06 02:20:00 2025
All archiving processes stopped. Archiver error. Connect internal only, until freed.
...
Tue May 06 02:21:00 2025
ORA-00257: archiver error. Connect internal only, until freed.
```

`ORA-15041: diskgroup "ARCH" space exhausted` and `ORA-00257`! The combination of these two error codes made the root cause crystal clear: **the `+ARCH` ASM disk group, used for storing archive logs, was 100% full. This caused the archiver process to stop, and to protect data integrity, the database automatically suspended itself, refusing all new transaction requests.**

We immediately queried the ASM disk group usage:

```sql
-- Execute as sysasm or a sysdba user with sufficient privileges
SELECT
    name,
    total_mb,
    free_mb,
    ROUND((1 - free_mb / total_mb) * 100, 2) AS "PCT_USED"
FROM
    v$asm_diskgroup
WHERE
    name = 'ARCH';

NAME                             TOTAL_MB    FREE_MB   PCT_USED
------------------------------ ---------- ---------- ----------
ARCH                             512000     128     99.98

```

The 500GB `+ARCH` disk group was almost completely full, with only a few dozen megabytes of trivial space remaining.

But why did it fill up? We have daily RMAN backup and cleanup scripts. By inspecting the RMAN logs on the backup server, we found the culprit: **the target NFS storage for backups had been unexpectedly unmounted two days prior due to network instability, and our backup script was flawed—it failed to trigger any alerts upon failure.** This created a one-way street of accumulation: for the past 48 hours, archive logs were being generated but never cleared, eventually overwhelming the valuable ASM space.

# **Emergency Response: Surgical Cleanup on ASM**

The situation was critical. We had to free up space in the `+ARCH` disk group immediately. In an ASM environment, using OS commands to delete files is strictly forbidden. We had to use RMAN, Oracle's own "housekeeper," to perform a safe and graceful cleanup.

With the NFS backup target unavailable, we couldn't perform a new backup. The immediate priority was to delete some of the already archived—but not yet backed up—logs to restore service. This required a careful trade-off: **deleting these logs meant that if a physical database failure occurred at that moment, this data would be lost.** After communicating the risks and getting approval from the client (a crucial step), we decided to delete archive logs from before the NFS failure (older than two days), as they had already been successfully backed up to a tape library at an earlier time.

The recovery steps were as follows:

*   **Connect to RMAN:**

```bash
rman target /
```

*   **Perform a Precise Cleanup:**

We used the `DELETE` command with a timestamp to precisely remove all archive logs generated before the NFS failure (i.e., older than two days). This was a relatively safe operation as it didn't touch the critical, un-backed-up logs from the last two days.

```rman
RMAN> DELETE ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';
```

RMAN listed the archive log files it was about to delete and prompted for confirmation. After confirmation, it safely removed the files from the ASM disk group and updated the metadata in the control file accordingly.

After the command finished, we queried `v$asm_diskgroup` again, and the `PCT_USED` had dropped to around 75%. Almost simultaneously, new messages appeared in the `alert` log indicating that the archival process had resumed normally. A few minutes later, the application team confirmed that the ERP system was fully operational again. The midnight crisis, triggered by a "silent failure," was temporarily resolved.

# **The Impact of a Full Archive Destination: More Than Just a "Down Database"**

*   **Database Transaction Freeze:** All DML operations (INSERT, UPDATE, DELETE) are suspended, freezing the database's "heartbeat."
*   **Application-Wide Paralysis:** All applications dependent on the database crash due to connection failures.
*   **Business Disruption and Data Risk:** This leads to production halts, unprocessed orders, and stalled financial settlements. Failed nightly batches can cause data inconsistencies the next day.
*   **Potential for Data Loss:** If a media failure occurs, the most recent, un-backed-up archive logs are lost, leading to permanent data loss.

# **Post-Mortem and Prevention: How to Avoid a Recurrence**

Firefighting is reactive; our goal is to build a "fire prevention" system that is self-aware and self-protecting.

**1. Monitoring: The First Line of Defense**

*   **ASM Disk Group Capacity Monitoring:** This is paramount. Use tools like Zabbix or Prometheus with custom scripts to periodically query the `v$asm_diskgroup` view and set multi-level alerts on `PCT_USED`.
    *   **Warning:** Usage > 80%, notify the DBA team.
    *   **Critical:** Usage > 90%, trigger multi-channel alerts (phone, SMS) for immediate intervention.
*   **Backup Job Status Monitoring:** It's not enough to see if a script "ran"; we need to know if it "succeeded." Monitoring the `v$rman_backup_job_details` view provides precise status for every RMAN job.

```sql
-- Query for failed RMAN jobs in the last 24 hours
SELECT
    session_key,
    status,
    to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') as start_time,
    to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') as end_time,
    input_bytes_display,
    output_bytes_display
FROM
    v$rman_backup_job_details
WHERE
    start_time > SYSDATE - 1
    AND status != 'COMPLETED';
```

If this query returns any record with a `FAILED` status, it should immediately trigger a high-priority alert.

**2. Hardening the Backup Script**

We don't need a new script, but we must "harden" the existing one. A robust backup script must have:

*   **Explicit Error-Catching:** After executing an RMAN command, the script must check its return code or log output. In a shell script, this can be done by `grep`-ing the log for "ORA-" or "RMAN-" errors.
*   **Immediate "Call for Help" on Failure:** When a failure is detected, the script must not exit silently. It must immediately push a notification to the operations team via an alerting API, email, or SMS.
*   **Use of Non-Zero Exit Codes:** A failed script should exit with a non-zero status code (e.g., `exit 1`). This allows higher-level schedulers (like `cron` or a professional workload automation tool) to detect the failure and take further action, such as retrying or escalating the alert.
*   **"Heartbeat" Notifications:** Not just failures, but successes should also generate a log or notification. If the team doesn't receive a "success" message at the expected time, they can infer that something is wrong (e.g., the script is hung or the server is down).

**3. Capacity Planning: Maintaining a Buffer**

*   **Estimate Log Generation Rate:** Analyze the archive log generation rate during peak business periods.
*   **Reserve Safety Margin:** The `+ARCH` disk group size should be large enough to hold the accumulated logs from at least **2-3 consecutive failed backup cycles**, plus an additional 20% buffer.
*   **Leverage the FRA (Fast Recovery Area):** Even on ASM, the archive destination should be configured within the FRA. The FRA's automatic space management can, when space is tight, automatically delete the oldest backups and archive logs that are eligible for deletion according to the retention policy. This is the last line of defense against a sudden space exhaustion.

# **Conclusion**

This late-night incident was a profound lesson. It teaches us that **in an automated system, a "silent failure" is far more dangerous than a crashing error.** For database operations, our value isn't just in crisis-time heroics, but in building a robust system of comprehensive monitoring, resilient automation, and forward-thinking capacity planning to prevent crises from ever occurring. After all, the most successful emergency response is the one that never has to be initiated.
