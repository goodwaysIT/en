---
layout: post
title: "Discussion on Application Architecture Technologies for ADG, OGG, and Data Warehouse Systems at Bank"
excerpt: "A survey on the application architecture technology, current status and disaster recovery requirements of a banking client's ADG, OGG and data warehouse system, a comparison between logical replication (OGG) and physical replication (ADG), and a summary of the advantages and disadvantages of OGG and ADG."
date: 2025-07-16 10:00:00 +0800
categories: [Oracle, Database]
tags: [Database Architecture, ADG, OGG, Disaster Recovery, Logical Replication, Physical Replication, oracle]
image: /assets/images/posts/Discussion-on-Application-Architecture-Technologies-for-ADG-OGG.jpg
---

## Current Situation and Disaster Recovery Requirements Investigation  

- Existing High Availability Solution  
  - Currently implemented dual-active between two computer rooms using VPLEX-based Extended RAC  

- Source Database Information  
  - Operating System: 64-bit AIX 7100  
  - Database: Oracle 12.1.0.2 Extended RAC  

- Disaster Recovery Site Requirements  
  - Achieve data disaster recovery for data protection  
  - Used for data extraction by other services  

- Disaster Recovery Environment Hardware and OS  
  - Based on existing resources, there is one one-eighth rack Exadata in both the production and standby computer rooms. Current database version is 11.2.0.3.  

- Disaster Recovery Synchronization Options Considered  
  - ADG  
  - OGG  

## Comparison of Logical Replication (OGG) and Physical Replication (ADG)  

- Scenarios Where OGG Excels  
   - Supports read-write on both sides  
   - Supports cross-platform (AIX and Linux)  
   - Supports cross-version (requires validation of supported versions)  

- Scenarios Where ADG Excels  
   - OGG only supports asynchronous mode, cannot achieve zero data loss; ADG supports zero data loss.  
   - ADG has block auto-repair functionality, OGG does not.  
   - OGG data validation is less strict than ADG.  
   - OGG has some data type limitations, e.g., the same ROWID may represent different records or even different objects on source and target.  
   - Large DML operations cause more significant delays in OGG.  
   - ADG configuration and maintenance are simpler.  
   - OGG source and target backups cannot be used interchangeably.  

## Summary of OGG and ADG  

- ADG is the preferred choice for data disaster recovery protection.  
- Can also be used for backups on the standby side, offloading read-only operations from the source to the standby.  
- Oracle strongly recommends deploying an ADG environment, which can be used both for data distribution to data warehouses and as a supplement to disaster recovery providing additional protection.  
- OGG is more suitable for cross-version, cross-platform scenarios requiring write operations on the disaster recovery end.  
- Architecturally, with the source environment being 64-bit AIX, direct replication via ADG to a target environment of 64-bit X86 Linux is not supported.  
- Additionally, the current Oracle database version on Exadata is 11.2.0.3, which is unsupported. It is recommended to upgrade to 12.1.0.2.  
