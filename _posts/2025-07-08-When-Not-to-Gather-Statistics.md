---
layout: post
title: "When Not to Gather Statistics"
excerpt: "Although the optimizer needs accurate statistics to select an optimal plan, there are scenarios where gathering statistics can be difficult, too costly, or cannot be accomplished in a timely manner and an alternative strategy is required."
date: 2025-07-08 15:00:00 +0800
categories: [Oracle, Database]
tags: [Database maintenance, Database deployment,Database optimization, oracle]
image: /assets/images/posts/When-Not-to-Gather-Statistics.jpg
---
 
Although the optimizer needs accurate statistics to select an optimal plan, there are scenarios where gathering statistics can be difficult, too costly, or cannot be accomplished in a timely manner and an alternative strategy is required.  

### Volatile Tables  
A volatile table is one where the volume of data changes dramatically over time. For example, an orders queue table, which at the start of the day the table is empty. As the day progresses and orders are placed the table begins to fill up. Once each order is processed it is deleted from the tables, so by the end of the day the table is empty again.
If you relied on the automatic statistics gather job to maintain statistics on such tables then the statistics would always show the table was empty because it was empty over night when the job ran. However, during the course of the day the table may have hundreds of thousands of rows in it.  
In such cases it is better to gather a representative set of statistics for the table during the day when the table is populated and then lock them. Locking the statistics will prevent the automated statistics gathering task from over writing them. Alternatively, you could rely on dynamic sampling to gather statistics on these tables. The optimizer uses dynamic sampling during the compilation of a SQL statement to gather basic statistics on the tables before optimizing the statement. Although the statistics gathered by dynamic sampling are not as high a quality or as complete as the statistics gathered using the DBMS_STATS package, they should be good enough in most cases.   

### Global Temporary Tables   
Global temporary tables are often used to store intermediate results in an application context. A global temporary table shares its definition system-wide with all users with appropriate privileges, but the data content is always session-private.  No physical storage is allocated unless data is inserted into the table. A global temporary table can be transaction specific (delete rows on commit) or session-specific (preserves rows on commit).  

### Gathering statistics  
on transaction specific tables leads to the truncation of the table. In contrast, it is possible to gather statistics on a global temporary table (that persist rows) but in previous releases its wasn’t always a good idea as all sessions using the GTT had to share a single set of statistics so a lot of systems relied on dynamic statistics.  
However, in Oracle Database 18c, it is possible to have a separate set of statistics for every session using a GTT.  
Statistics sharing on a GTT is controlled using a new DBMS_STATS preference GLOBAL_TEMP_TABLE_STATS.  
By default the preference is set to SESSION, meaning each session accessing the GTT will have its own set of statistics. The optimizer will try to use session statistics first but if session statistics do not exist, then optimizer will use shared statistics.  

***Changing the default behavior of not sharing statistics on a GTT to forcing statistics sharing:***
```SQL
SQL> --Create Global Temporary Table
SQL> Create Global Temporary table TG (col1 number);
Table created.
SQL> --get table preference for TG
SQL> select dbms_stats.get_prefs('GLOBAL_TEMP_STATS','SH','TG') from dual;
DBMS_STATS.GET_PREFS('GLOBAL_TEMP_TABLE_STATS','SH','TG')
------------------------------------------------------------------------------------
SESSION

SQL> --Change table preference for TG to SHARED
SQL> BEGIN
  2        dbms_stats.set_table_prefs('SH','TG','GLOBAL_TEMP_TABLE_STATS','SHARED');
  3      END;
  4      /
PL/SQL procedure successfully completed.

SQL> -- get table preference for TG
SQL> select dbms_stats.get_prefs('GLOBAL_TEMP_STATS','SH','TG') from dual;
DBMS_STATS.GET_PREFS('GLOBAL_TEMP_TABLE_STATS','SH','TG')
------------------------------------------------------------------------------------
SHARED
```

If you have upgraded from Oracle Database 11g and if database applications have not been modified to take advantage of SESSION statistics for GTTs, you may want to keep GTT behavior consistent with the pre-upgrade environment by setting the DBMS_STATS preference GLOBAL_TEMP_TABLE_STATS to SHARED (at least until applications have been updated).  
When populating a GTT (that persists rows on commit) using a direct path operation, session level statistics will be automatically created due to online statistics gathering, which will remove the necessity to run additional statistics gathering command and will not impact the statistics used by any other session.  

***Populating a GTT using a direct path operation results in session level statistics being automatically gathered:***
```sql
SQL> Create global temporary Table SALES2(
          PROD_ID	NUMBER(6),
          CUST_ID	NUMBER,
          TIME_ID	DATE,
          CHANNEL_ID	CHAR(1),
          PROMO_ID	NUMBER(6),
          QUANTITY_SOLD NUMBER(3),
          AMOUNT_SOLD   NUMBER(10,2));
Table created.
SQL>
SQL> insert /*+ APPEND */ into sales2 select * from sales;
254720 rows created.
SQL> commit;
Commit complete.
SQL>
SQL> Select column_name,num_distinct,num_nulls
          From user_tab_col_statistics Where table_name='SALES2';
COLUMN_NAME              NUM_DISTINCT  NUM_NULLS
-------------------------     -----------------  --------------
PROD_ID                        766                    0
CUST_ID                        630                    0
TIME_ID                        620                    0
CHANNEL_ID                       5                    0
PROMO_ID                       116                    0
QUANTITY_SOLD                  44                     0
AMOUNT_SOLD                    583                    0
```

### Intermediate Work Tables  
Intermediate work tables are typically seen as part of an ELT process or a complex transaction. These tables are written to only once, read once, and then truncated or deleted. In such cases the cost of gathering statistics outweighs the benefit, since the statistics will be used just once. Instead dynamic sampling should be used in these cases. It is recommended you lock statistics on intermediate work tables that are persistent to prevent the
automated statistics gathering task from attempting to gather statistics on them.  
