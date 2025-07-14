---
layout: post
title: "Best Practices and Recommendations for RAC databases with SGA size over 100GB"
excerpt: "The goal of this note is to provide best practices and recommendations to users of Oracle Real Application Clusters (RAC) databases using very large SGA (e.g. 100GB) per instance (note that RAC assumes homogeneously sized SGAs across the cluster). This document is compiled and maintained based on Oracle’s experience with its global RAC customer base."
date: 2025-07-14 15:00:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/Best-Practices-and-Recommendations-for-RAC-databases-with-SGA-size-over-100GB.jpg
---

## APPLIES TO
- Oracle Database Cloud Exadata Service - Version N/A and later
- Oracle Database Cloud Service - Version N/A and later
- Oracle Database - Enterprise Edition - Version 11.2.0.3 and later
- Oracle Database Backup Service - Version N/A and later
- Oracle Database Cloud Schema Service - Version N/A and later
*Information in this document applies to any platform.*

---

## PURPOSE
The goal of this note is to provide best practices and recommendations to users of Oracle Real Application Clusters (RAC) databases using very large SGA (e.g. 100GB) per instance (note that RAC assumes homogeneously sized SGAs across the cluster). This document is compiled and maintained based on Oracle’s experience with its global RAC customer base.

This is not meant to replace or supplant the Oracle Documentation set, but rather, it is meant as a supplement to the same. It is imperative that the Oracle Documentation be read, understood, and referenced to provide answers to any questions that may not be clearly addressed by this note.

All recommendations should be carefully reviewed by your own operations group and should only be implemented if the potential gain as measured against the associated risk warrants implementation. Risk assessments can only be made with a detailed knowledge of the system, application, and business environment.

As every customer environment is unique, the success of any Oracle Database implementation, including implementations of Oracle RAC, is predicated on a successful test environment. Oracle Support has identified 100 GB as a baseline for large SGA’s that would benefit from the recommendations provided in this note. However, this is just a baseline, and it is possible for similar(but smaller) SGA’s to benefit from these recommendations. It is thus imperative that any recommendations from this note are thoroughly tested and validated using a testing environment that is a replica of the target production environment before being implemented in the production environment to ensure that there is no negative impact associated with the recommendations that are made.

---

## SCOPE
- This article applies to all new and existing RAC implementations.
- This is for RAC databases only as most of the parameters listed in here are for RAC Database only.

---

## DETAILS
Note that the recommendations presented in this note are a result of the experience from working on databases with SGA of 1 TB and 2.6 TB. However, the databases with SGA of 100GB and 300GB also benefited from the recommendations.

Also, some recommendation is removed for 18.1 and above, so check if the recommendation is applicable to your database.

> **Note:**
> ORAchk 18.2 and above can be used to validate the proper settings for Large SGA Databases (those documented in this MOS Document). Though the check is available within ORAchk 18.2, it is always recommended to use the latest version of ORAchk which is available via [Document 1268927.2](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=1268927.2) to ensure you are receiving the most up-to-date information.
> Download latest AHF. Refer to [Autonomous Health Framework (AHF) - Including TFA and ORAchk/EXAchk Document 2550798.1](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=2550798.1)

---

### **init.ora parameters:**
a. **`_lm_sync_timeout`** to `1200`
   *Valid only for databases 12.2 and lower*
   Prevents timeouts during reconfiguration and DRM. Static parameter; rolling restart supported.

b. **`shared_pool_size`** to **15% or larger** of total SGA
   *Dynamic parameter*
   Example: For 1TB SGA, set shared pool ≥150GB.

c. **`_gc_policy_minimum`** to `15000`
   *Dynamic parameter*
   **Note:**
   - Not needed if DRM is disabled (`_gc_policy_time=0`).
   - Disable DRM via dynamic parameter `_lm_drm_disable` (not `_gc_policy_time`).
   - Default=15000 in 23c, 19c DBRU JUL '23, and 19c ADB (Bug 34729755).

d. **`_lm_tickets`** to `5000`
   *Valid only for databases 12.2 and lower*
   Default=1000; static parameter. Rolling restart supported when increasing; cold restart may be needed when decreasing.

e. **`gcs_server_processes`** to **twice the default LMS processes**
   *Valid only for databases 12.2 and lower*
   *Static parameter; rolling restart supported*
   **Requirements:**
   - Default LMS count = f(CPU/cores) (see Oracle Database Reference Guide).
   - Total LMS processes across all DBs on server **must be < total CPU/cores** (See [Doc 558185.1](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=558185.1)).
   *Fix included in 12.2.0.1 JUL 2018 RU+.*

f. **`TARGET_PDBS`** to **planned number of PDBs in CDB**
   *Valid for 12.2+*
   *(Exclude seed and root)*
   Default values with large `sga_target` cause performance/eviction issues (See [Doc 2644243.1](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=2644243.1)).

---

### **HugePages/Large Pages:**
- **Critical for Linux** with large SGA.
- **Recommended for all platforms** where possible.

---

### **Recommended Patches:**
**11.2.0.3+:**
Apply 11.2.0.3.5 DB PSU or higher.

**11.2.0.4 Bug Fixes:**
- BUG 12747740 - RAC PERF: NODE JOIN RECONFIGURATION (PCMREPLAY) DOES NOT SCALE WITH MORE LMS'S
- BUG 14193240 - LMS SIGNALED ORA-600[KGHLKREM1] DURING BEEHIVE LOAD
- BUG 16392068 - MSGQ: LMSO HITS ORA-600 [KJBMPOCR:DSB]
- BUG 17232014 - INITIAL ALLOCATION FOR KJBR6KJBL ARE TOO LOW W/ LARGE CACHES DUE TO UB4 OVERFLOW
- BUG 17257445 - RAC PERF: DRM OPTIMIZATION (BUG 14558880) SHOULD ALSO WORK FOR RECONFIGURATION
- BUG 17314971 - RAC PERF: RM/PT LATCH REDUCTION FOR RCFG (17257445) SHOULD BE ENABLED FOR SYNC7

**SGA >4TB (Linux):**
- BUG 18780342 - LINUX SUPPORT FOR > 4TB SGA

---

## REFERENCES
- [NOTE:558185.1 - LMS and Real Time Priority in Oracle RAC 10g and 11g](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=558185.1)
- [NOTE:1392248.1 - Auto-Adjustment of LMS Process Priority in Oracle RAC with 11.2.0.3 and later](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=1392248.1)
- [NOTE:2550798.1 - Autonomous Health Framework (AHF) - Including TFA and ORAchk/EXAchk](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=2550798.1)
- [NOTE:2644243.1 - Performance Issues when using PDBs with Oracle RAC 19c and 18c](https://support.oracle.com/epmos/faces/DocumentDisplay?_adf.ctrl-state=riz393vca_119&id=2644243.1)
