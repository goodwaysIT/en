---
layout: post
title: "Best Practices - How to Gather Statistics with Oracle Database"
excerpt: "This paper will discuss in detail, when and how to gather statistics for the most common scenarios seen in an Oracle Database."
date: 2025-06-16 17:51:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/How-to-Gather-Statistics-with-Oracle-Database.jpg
---

**Strategy**   
The preferred method for gathering statistics in Oracle is to use the automatic statistics gathering. If you already
have a well-established, manual statistics gathering procedure then you might prefer to use that instead. Whatever
method you choose to use, start by considering whether the default global preferences meet your needs. In most
cases they will, but if you want to change anything then you can do that with SET_GLOBAL_PREFS. Once you have
done that, you can override global defaults where necessary using the DBMS_STATS “set preference” procedures.  

For example, use SET_TABLE_PREFS on tables that require incremental statistics or a specific set of histograms.
In this way, you will have declared how statistics are to be gathered, and there will be no need to tailor parameters
for individual “gather stats” operations. You will be free to use default parameters for gather table/schema/database
stats and be confident that the statistics policy you have chosen will be followed. What’s more, you will be able to
switch freely between using auto and manual statistics gathering.  

This section covers how to implement this strategy.  

**Automatic Statistics Gathering**  
The Oracle database collects statistics for database objects that are missing statistics or have “stale” (out of date)
statistics. This is done by an automatic task that executes during a predefined maintenance window. Oracle
internally prioritizes the database objects that require statistics, so that those objects, which most need updated
statistics, are processed first.  

The automatic statistics-gathering job uses the DBMS_STATS.GATHER_DATABASE_STATS_JOB_PROC procedure,
which uses the same default parameter values as the other DBMS_STATS.GATHER_*_STATS procedures. The
defaults are sufficient in most cases. However, it is occasionally necessary to change the default value of one of the
statistics gathering parameters, which can be accomplished by using the DBMS_STATS.SET_*_PREF procedures.
Parameter values should be changed at the smallest scope possible, ideally on a per-object basis. For example, if
you want to change the staleness threshold for a specific table, so its statistics are considered stale when only 5% of
the rows in the table have changed rather than the default 10%, you can change the STALE_PERCENT table
preference for that one table using the DBMS_STATS.SET_TABLE_PREFS procedure. By changing the default value
at the smallest scope you limit the amount of non-default parameter values that need to be manually managed. For
example, here’s how you can change STALE_PRECENT to 5% on the SALES table:  
```sql
exec dbms_stats.set_table_prefs(user,'SALES','STALE_PERCENT','5')
```

To check what preferences have been set, you can use the DBMS_STATS.GET_PREFS function. It takes three arguments; the name of the parameter, the schema name, and the table name:  
```sql
select dbms_stats.get_prefs('STALE_PERCENT',user,'SALES') stale_percent from dual;

STALE_PERCENT
-------------
5
```

**Setting DBMS_STATS Preferences**  
As indicated above, it is possible to set DBMS_STATS preferences to target specific objects and schemas to modify
the behavior of auto statistics gathering where necessary. You can specify a particular non-default parameter value
for an individual DBMS_STATS.GATHER_*_STATS command, but the recommended approach is to override the
defaults where necessary using “targeted” DBMS_STATS.SET_*_PREFS procedures.  

A parameter override can be specified at a table, schema, database, or global level using one of the following
procedures (noting that AUTOSTATS_TARGET and CONCURRENT can only be modified at the global level):  
SET_TABLE_PREFS  
SET_SCHEMA_PREFS  
SET_DATABASE_PREFS  
SET_GLOBAL_PREFS  

Traditionally, the most commonly overridden preferences have been ESTIMATE_PERCENT (to control the
percentage of rows sampled) and METHOD_OPT (to control histogram creation), but estimate percent is now better
left at its default value for reasons covered later in this section.  

The SET_TABLE_PREFS procedure allows you to change the default values of the parameters used by the DBMS_STATS.GATHER_*_STATS procedures for the specified table only.  

The SET_SCHEMA_PREFS procedure allows you to change the default values of the parameters used by the DBMS_STATS.GATHER_*_STATS procedures for all of the existing tables in the specified schema. This procedure actually calls the SET_TABLE_PREFS procedure for each of the tables in the specified schema. Since it uses SET_TABLE_PREFS, calling this procedure will not affect any new objects created after it has been run. New objects will pick up the GLOBAL preference values for all parameters.  

The SET_DATABASE_PREFS procedure allows you to change the default values of the parameters used by the DBMS_STATS.GATHER_*_STATS procedures for all of the user-defined schemas in the database. This procedure actually calls the SET_TABLE_PREFS procedure for each table in each user-defined schema. Since it uses SET_TABLE_PREFS, this procedure will not affect any new objects created after it has been run. New objects will pick up the GLOBAL preference values for all parameters. It is also possible to include the Oracle owned schemas (sys, system, etc) by setting the ADD_SYS parameter to TRUE.  

The SET_GLOBAL_PREFS procedure allows you to change the default values of the parameters used by the `DBMS_STATS.GATHER_*_STATS` procedures for any object in the database that does not have an existing table preference.  All parameters default to the global setting unless there is a table preference set, or the parameter is explicitly set in the `GATHER_*_STATS` command. Changes made by this procedure will affect any new objects created after it has been run. New objects will pick up the GLOBAL_PREFS values for all parameters.  

The DBMS_STATS.GATHER_*_STATS procedures and the automated statistics gathering task obeys the following hierarchy for parameter values; parameter values explicitly set in the command overrule everything else. If the parameter has not been set in the command, we check for a table level preference. If there is no table preference set, we use the GLOBAL preference.  

DBMS_STATS.GATHER_*_STATS hierarchy for parameter values:  
`GATHER_%_STATS Paramete > Table Preference > Global Preference`  

**Oracle Database 12 Release 2 includes a new DBMS_STATS preference called**  
PREFERENCE_OVERRIDES_PARAMETER. The effect is shown below. When this preference is set to TRUE, it allows preference settings to override DBMS_STATS parameter values. For example, if the global preference ESTIMATE_PERCENT is set to DBMS_STATS.AUTO_SAMPLE_SIZE, it means that this best-practice setting will be used even if existing manual statistics gathering procedures use a different parameter setting (for example, a fixed percentage sample size such as 10%).  

Using DBMS_STATS preference PREFERENCE_OVERRIDES_PARAMETER:  
`Table Preference > Global Preference > GATHER_%_STATS Paramete`

**ESTIMATE_PERCENT**  
The ESTIMATE_PERCENT parameter determines the percentage of rows used to calculate the statistics.
The most accurate statistics are gathered when all rows in the table are processed (i.e. a 100% sample), often referred to as computed statistics.
Oracle Database 11g introduced a new sampling algorithm that is hash based and provides deterministic statistics. This new approach has an accuracy close to a 100% sample but with the cost of, at most, a 10% sample.  
The new algorithm is used when ESTIMATE_PERCENT is set to AUTO_SAMPLE_SIZE (the default) in any of the DBMS_STATS.GATHER_*_STATS procedures. Prior to Oracle Database 11g, DBAs often set the ESTIMATE_PRECENT parameter to a low value to ensure that the statistics would be gathered quickly.   However, without detailed testing, it is difficult to know which sample size to use to get accurate statistics.  
It is highly recommended that from Oracle Database 11g onwards that the default AUTO_SAMPLE_SIZE is used for ESTIMATE_PRECENT. This is especially important because the new Oracle Database 12c histogram types, HYBRID and Top-Frequency, can only be created if an auto sample size is used.  
Many systems still include old statistics gathering scripts that manually set estimate percent, so when upgrading to Oracle Database 12c Release 2, consider using the PREFERENCE_OVERRIDES_PARAMETER preference (see above) to enforce the use of auto sample size.

**METHOD_OPT**  
The METHOD_OPT parameter controls the creation of histograms1 during statistics collection. Histograms are a special type of column statistic created to provide more detailed information on the data distribution in a table column.  
The default and recommended value for METHOD_OPT is 'FOR ALL COLUMNS SIZE AUTO', which means that histograms will be created for columns that are likely to benefit from having 2them. A column is a candidate for a histogram if it is used in equality or range predicates such as WHERE col1= 'X' or WHERE col1 BETWEEN 'A' and 'B' and, in particular, if it has a skew in the distribution of column values. The optimizer knows which columns are used in query predicates because this information is tracked and stored in the dictionary table SYS.COL_USAGE$.  
Some DBAs prefer to tightly control when and what histograms are created. The recommended approach to achieve is to use SET_TABLE_PREFS to specify which histograms to create on a table-by-table basis.  
For example, here is how you can specify that SALES must have histograms on col1 and col2 only:  
```SQL
begin
dbms_stats.set_table_prefs(
user,
'SALES',
'method_opt',
'for all columns size 1 for columns size 254 col1 col2');
end;
/
```

It is possible to specify columns that must have histograms (col1 and col2) and, in addition, allow the optimizer to decide if additional histograms are useful:  
```sql
begin
dbms_stats.set_table_prefs(
user,
'SALES',
'method_opt',
'for all columns size auto for columns size 254 col1 col2');
end;
/
```

Histogram creation is disabled if METHOD_OPT is set to 'FOR ALL COLUMNS SIZE 1'. For example, you can change the DBMS_STATS global preference for METHOD_OPT so that histograms are not created by default:  
```sql  
begin
dbms_stats.set_global_prefs(
'method_opt',
'for all columns size 1');
end;
/
```

Unwanted histograms can be dropped without dropping all column statistics by using DBMS_STATS.DELETE_COLUMN_STATS and setting the col_stat_type to ‘HISTOGRAM’.

**Manual Statistics Collection**  
If you already have a well-established statistics gathering procedure or if for some other reason you want to disable automatic statistics gathering for your main application schema, consider leaving it on for the dictionary tables. You can do so by changing the value of AUTOSTATS_TARGET parameter to ORACLE instead of AUTO using DBMS_STATS.SET_GLOBAL_PREFS procedure.  
`exec dbms_stats.set_global_prefs('autostats_target','oracle')`  

To manually gather statistics you should use the PL/SQL DBMS_STATS package. The obsolete, ANALYZE command should not be used.  The package DBMS_STATS provides multiple DBMS_STATS.GATHER_*_STATS procedures to gather statistics on user schema objects as well as dictionary and fixed objects. Ideally you should let all of the parameters for these procedures default except for schema name and object name. The defaults and  adaptive parameter settings chosen by the Oracle are sufficient in most cases:  
`exec dbms_stats.gather_table_stats('sh','sales') `  

As mentioned above, if it does become necessary to change the default value of one of the statistics gathering parameters, using the DBMS_STATS.SET_*_PREF procedures to make the change at the smallest scope possible, ideally on a per-object bases.  

**Pending Statistics**  
When making changes to the default values of the parameter in the DBMS_STATS.GATHER_*_STATS procedures, it is highly recommended that you validate those changes before making the change in a production environment. If you don’t have a full scale test environment you should take advantage of pending statistics. With pending statistics, instead of going into the usual dictionary tables, the statistics are stored in pending tables so that
they can be enabled and tested in a controlled fashion before they are published and used system-wide. To activate pending statistics collection, you need to use one of the DBMS_STATS.SET_*_PREFS procedures to change value of the parameter PUBLISH from TRUE (default) to FALSE for the object(s) you wish to create pending statistics for.  
In the example below, pending statistics are enabled on the SALES table in the SH schema and then statistics are gathered on the SALES table:  
`exec dbms_stats.set_table_prefs('sh','sales','publish','false') `  

Gather statistics on the object(s) as normal:  
`exec dbms_stats.gather_table_stats('sh','sales') `

The statistics gathered for these objects can be displayed using the dictionary views called USER_*_PENDING_STATS.  
You can enable the usage of pending statistics by issuing an alter session command to set the initialization parameter OPTIMIZER_USE_PENDING_STATS to TRUE. After enabling pending statistics, any SQL workload run in this session will use the new non-published statistics. For tables accessed in the workload that do not have pending statistics the optimizer will use the current statistics in the standard data dictionary tables. Once you have validated the pending statistics, you can publish them using the procedure DBMS_STATS.PUBLISH_PENDING_STATS.  
`exec dbms_stats.publish_pending_stats('sh','sales')`  

---
***Source: https://www.oracle.com/docs/tech/database/technical-brief-bp-stats-gather-0218.pdf***
