---
layout: post
title: "Oracle Production Environment Database Change Specification"
excerpt: "All production changes must follow the auditable, rollbackable, traceable three principles. After script execution, logs must be automatically emailed to the DBA team."
date: 2025-08-12 10:00:00 +0800
categories: [Oracle, Database]
tags: [Rollback Plan Design, Specification, oracle]
image: /assets/images/posts/Oracle-Production-Environment-Database-ChangeSpecification.jpg
---

## I. Change Process Specification  
### Prerequisites  

All changes require approval through the Work Order System (with design documentation attached)  
Executor must hold DBA authorization certification  
Change window: Non-peak business hours (e.g., 23:00-5:00)  
Script naming convention  
[Project Number]_[Object Type]_[Function]_[Date].sql  
Example: PROJ123_TBL_CreateOrderTbl_20230811.sql  

## II. Object Creation Specification  
### 1. Users and Tablespaces  
```sql
-- User creation (must bind default tablespace)
CREATE USER ops_user IDENTIFIED BY "S3cureP@ss#2023"
  DEFAULT TABLESPACE ops_data
  QUOTA UNLIMITED ON ops_data
  ACCOUNT UNLOCK;

-- Tablespace creation (must specify bigfile mode)
CREATE BIGFILE TABLESPACE ops_data
  DATAFILE '+DATA' SIZE 10G AUTOEXTEND ON NEXT 1G;
```
### 2. Tables and Indexes  
```sql
-- Table creation example (must include comments and storage parameters)
CREATE TABLE order_details (
  order_id   NUMBER(12)   PRIMARY KEY,
  product_id VARCHAR2(20) NOT NULL,
  amount     NUMBER(16,2) DEFAULT 0
) TABLESPACE ops_data
  PCTFREE 10 PCTUSED 80
  COMPRESS FOR OLTP;  -- Enable advanced compression

COMMENT ON TABLE order_details IS 'Order details table';
COMMENT ON COLUMN order_details.order_id IS 'Unique order ID';

-- Index naming convention: IDX_[Table Abbreviation]_[Column Name]
CREATE INDEX IDX_ORDETAILS_PRODID ON order_details(product_id)
  TABLESPACE ops_index
  PARALLEL 4 NOLOGGING;  -- Accelerate creation with parallelism
```

### 3. Views and Sequences  
```sql
-- Views must include OR REPLACE and FORCE options
CREATE OR REPLACE FORCE VIEW v_active_orders AS
SELECT /*+ INDEX(o IDX_ORD_STATUS) */
       order_id, product_id
FROM orders o
WHERE status = 'ACTIVE'
WITH READ ONLY;  -- Enforce read-only

-- Sequence must specify NOCACHE to prevent gaps
CREATE SEQUENCE seq_order_id
  START WITH 1000000
  INCREMENT BY 1
  NOCACHE NOCYCLE;
CACHE+NOORDER: This is the recommended configuration for RAC environments. When the order attribute is not specified, RAC defaults to this configuration with a default cache value of 20. For frequently used sequences, adjust cache to 1000~2000.
```

## III. Script Coding Specification  
Requirement	Example/Description  
Character Set	Must be AL32UTF8  
File Encoding	UNIX format, UTF-8 without BOM  
Transaction Control	DML must explicitly COMMIT/ROLLBACK  
Bind Variables	Hard-coded values prohibited (prevent SQL injection)  

Correct DML Example:  

```sql
BEGIN
  UPDATE accounts SET balance = balance - :amt WHERE id = :acc_id;
  -- Must include exception handling
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/
COMMIT;
```

## IV. Rollback Plan Design  
### 1. DDL Rollback (Structural Changes)
```sql
-- Original operation: Add column
ALTER TABLE orders ADD (discount NUMBER(5,2));

-- Rollback script (must be pre-generated)
ALTER TABLE orders DROP COLUMN discount;
```

### 2. DML Rollback (Data Changes)
```sql
-- Original operation: Data correction
UPDATE employees SET salary = salary * 1.1
WHERE dept_id = 'IT';

-- Rollback plan (using Flashback Query)
UPDATE employees e
SET e.salary = (
  SELECT salary
  FROM employees AS OF TIMESTAMP SYSDATE - 1/24  -- 1 hour ago
  WHERE employee_id = e.employee_id
)
WHERE dept_id = 'IT';
```

### 3. Object Deletion Rollback  
```sql
-- Pre-deletion backup (standard operation)
CREATE TABLE orders_bak_20230811 AS
SELECT * FROM orders;

-- Rollback command
RENAME orders_bak_20230811 TO orders;
```

## V. Emergency Handling  
### Accidental Data Deletion Recovery  
```sql
-- Use Flashback Table (requires row movement enabled)
ALTER TABLE orders ENABLE ROW MOVEMENT;
FLASHBACK TABLE orders TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '15' MINUTE);
```

### Performance Rollback Plan  
If performance degrades after index change:  
```sql
-- Rapid index rollback
DROP INDEX new_index_name FORCE;
CREATE INDEX old_index_name ... NOLOGGING PARALLEL 8;  -- Rebuild with parallelism
```

## VI. Version Control Requirements  
Project directory structure:  
├── scripts  
│ ├── deploy # Deployment scripts  
│ ├── rollback # Corresponding rollback scripts  
│ └── logs # Execution logs (with timestamps)  
└── docs  
└── ER_diagram.pdf # Design documentation  
Key principle: All production changes must follow the "auditable, rollbackable, traceable" three principles. After script execution, logs must be automatically emailed to the DBA team.  
