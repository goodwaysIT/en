---
layout: post
title: "How to change the host name from uppercase to lowercase in RAC environment"
excerpt: "opatch lsinventory shows one node in uppercase (incorrect one) and the other node in lowercase (correct one) "
date: 2025-07-24 15:00:00 +0800
categories: [Oracle, Database]
tags: [uppercase hostname, oracle]
image: /assets/images/posts/How-to-change-the-host-name-from-uppercase-to-lowercase.jpg
---

## Goal
1. opatch lsinventory shows one node in uppercase (incorrect one) and the other node in lowercase (correct one)
$ opatch lsinventory  

```
Oracle Grid Infrastructure 11g                                       11.2.0.4.0
There are 1 product(s) installed in this Oracle Home.
There are no Interim patches installed in this Oracle Home.

Rac system comprising of multiple nodes
Local node = rac1
Remote node = RAC2                   <<<<< Uppercase, incorrect one.
```

2. From the central inventory, it shows an uppercase hostname.
$ cat /u01/app/oraInventory/ContentsXML/inventory.xml

```
...

<HOME NAME="Ora11g_gridinfrahome1" LOC="/apps/oracle/product/11.2.0.4.GRD" TYPE="O" IDX="1" CRS="true">
  <NODE_LIST>
     <NODE NAME="rac1"/>
     <NODE NAME="RAC2"/>                           <<<<< Upper-case, incorrect one.
  </NODE_LIST>
</HOME>

...

```

## Solution
To change the hostname from uppercase to lowercase for a particular ORACLE_HOME:
1. Run the following command on each node to rectify the uppercase host name in the inventory, as the software owner:
```
$ $ORACLE_HOME/oui/bin/runInstaller -updateNodeList ORACLE_HOME="/apps/oracle/product/11.2.0.4.GRD" "CLUSTER_NODES={rac1,rac2}"   -silent -local
```

2. Verify the changes by repeating the command "opatch lsinventory" and "cat oraInventory/ContentsXML/inventory.xml"
