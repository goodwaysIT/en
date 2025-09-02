---
layout: post
title: "ORACLE ASMCA Command Failed To Access On AIX 7.2"
excerpt: "Based on the information provided, I confirmed that an unhandled exception error message occurred when executing the asmca command on the AIX operating system. This issue is specific to the AIX environment and has been investigated in BUG 34585151, which is believed to be related to IBM JVM settings."
date: 2025-09-02 15:00:00 +0800
categories: [Oracle, Database, RAC]
tags: [error_value=00000000, Can not use asmca, asmca failed to access oracle, rac, oracle]
image: /assets/images/posts/asmca-failed-to-access-oracle-database-on-aix.jpg
---

## Symptoms  
On : 19.17.0.0.0 version, IBM AIX on POWER Systems (64-bit)  

asmca failed to access
```
ERROR
-----------------------
unhandled exception
Type=segmentation error vmstate=0x00040000
J9Generic_signal_number=00000018 signal_name=000000b error_value=00000000 signal_code=00000033
.....
-----stack backtrace----
sdbgrfbibf_io_block_file
...

JVMDUMP039I Processing dump event "gpf", detail "" xxxxxx
JVMDUMP032I JVM requested System dump using xxxxxx

STEPS
-----------------------
Run asmca

BUSINESS IMPACT
-----------------------
Can not use asmca
```

## Cause
Based on the information provided, I confirmed that an unhandled exception error message occurred when executing the asmca command on the AIX operating system.  
This issue is specific to the AIX environment and has been investigated in BUG 34585151, which is believed to be related to IBM JVM settings.  
According the bug:  
This depends on the settings of IBM JVM. The stack size for OS Threads is 256K by default, but it is too small for the thread connecting using JDBC OCIDriver. As a result, the JVM crashes if connect error occurs repeatedly.  

## Solution  
### 1.Backup the asmca binary file:  
```
cp <GI_HOME>/bin/asmca <GI_HOME>/bin/asmca.bkp  
```

### 2.Manually modify asmca file and comment the last line of the file and add a new one as follow:  
```
vi <GI_HOME>/bin/asmca  
### exec $JRE_DIR/bin/java $JRE_OPTIONS -classpath $CLASSPATH oracle.sysman.assistants.usmca.Usmca $ARGUMENTS ◄◄◄ This line was commented.  
exec $JRE_DIR/bin/java -Xss4m -Xmso1m $JRE_OPTIONS -classpath $CLASSPATH oracle.sysman.assistants.usmca.Usmca $ARGUMENTS ◄◄◄ Add this line  
```
or  
```
vi <GI_HOME>/bin/asmca  
### JRE_OPTIONS="${JRE_OPTIONS} -Dsun.java2d.font.DisableAlgorithmicStyles=true -DDISPLAY=$DISPLAY -DIGNORE_PREREQS=$IGNORE_PREREQS -DJDBC_PROTOCOL=thin -mx128m $DEBUG_STRING"  
◄◄◄ Commented the line above and replace it with the following line.  
JRE_OPTIONS="${JRE_OPTIONS} -Dsun.java2d.font.DisableAlgorithmicStyles=true -DDISPLAY=$DISPLAY -DIGNORE_PREREQS=$IGNORE_PREREQS -DJDBC_PROTOCOL=thin -Xss4m -mx128m $DEBUG_STRING"  
```

### 3.Run `asmca` again.  

## REFERENCE INFORMATION  
BUG 34585151 - AIX64-19.17 : ROOT.SH FAILED ON FIRST NODE, UNHANDLED EXCEPTION, CLSRSC-612: FAILED TO CREATE BACKUP DISK GROUP
