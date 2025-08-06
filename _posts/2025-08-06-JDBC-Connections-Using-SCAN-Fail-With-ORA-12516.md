---
layout: post
title: "JDBC Connections Using SCAN Fail With ORA-12516"
excerpt: "Based on the scan listener logs and VIP listener logs, it is observed that the TNS-12516 errors started appearing on July 31st.The customer stated they did not make any changes.The TNS-12516 errors occur in the scan listener logs, while the VIP listener logs show no issues."
date: 2025-08-06 15:00:00 +0800
categories: [Oracle, Database]
tags: [TNS-12516, ORA-03137, JDBC Driver, SCAN Fail, oracle]
image: /assets/images/posts/JDBC-Connections-Using-SCAN-Fail-With-ORA-12516.jpg
---

## Symptoms  
On : 19.7.0.0.0 version, RDBMS  
listener_scan.log:  
```
2024-07-31T02:00:00.006290+08:00
31-JUL-2024 02:00:00 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.27)(PORT=47898)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
31-JUL-2024 02:00:00 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.27)(PORT=47900)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
2024-07-31T02:00:01.010650+08:00
31-JUL-2024 02:00:01 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.27)(PORT=47910)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
31-JUL-2024 02:00:01 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.27)(PORT=47912)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
....................

06-AUG-2024 04:06:37 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.31)(PORT=52314)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
06-AUG-2024 04:06:37 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.31)(PORT=52316)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
06-AUG-2024 04:06:37 * (CONNECT_DATA=(CID=(PROGRAM=JDBC Thin Client)(HOST=jdbc)(USER=ptdb))(SERVICE_NAME=ptdb)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.12.31)(PORT=52320)) * establish * ptdb * 12516
TNS-12516: TNS:listener could not find available handler with matching protocol stack
2024-08-06T04:06:38.265467+08:00

```

## Cause  
Based on the scan listener logs and VIP listener logs, it is observed that the TNS-12516 errors started appearing on July 31st.  
The customer stated they did not make any changes.  
The TNS-12516 errors occur in the scan listener logs, while the VIP listener logs show no issues.  
The errors are concentrated on the PDB: `ptdb`.  
The scan listener logs indicate that connections to other PDBs are normal.  
Occasionally, successful connections to PDB: `ptdb` are still observed in the scan listener logs.  
The primary application server IPs are: 192.168.12.27/31.  
Neither the database `PROCESS` nor `SESSION` parameters have reached their maximum limits.  
The customer uses a load balancer device between the application servers and database servers.  

The JDBC driver version is: 11.2.0.4.  
This version is relatively old and is known to cause issues such as *JDBC Connections Using SCAN Fail With ORA-12516 Or ORA-12520* (Doc ID 1555793.1).  

Additionally, the alert.log in your environment also contains errors like:  
`ORA-03137: malformed TTC packet from client rejected: [3146] [94] [] [] [] [] [] []`.  
This error is related to *ORA-03137: malformed TTC packet from client rejected: [3146] [94] [] [] [] [] [] [] While Using JDBC 12.2.0.1* (Doc ID 2519886.1).  
Upgrading the JDBC version is also required to resolve this issue.  

## Solution  
Upgrade the JDBC version to 19c or a later version.  

Ref:  
https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html  
Oracle Database 19c (19.24.0.0) JDBC Driver & UCP Downloads - Long Term Release <<<<<<<<<<<<<  

## References  
ORA-03137: malformed TTC packet from client rejected: [3146] [94] [] [] [] [] [] [] While Using JDBC 12.2.0.1 (Doc ID 2519886.1)  
JDBC Connections Using SCAN Fail With ORA-12516 Or ORA-12520 (Doc ID 1555793.1)  
