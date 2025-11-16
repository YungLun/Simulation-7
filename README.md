# Dynamic SQL Logic Execution and Security Simulation  
Course: SQL Server Development  
Database: AdventureWorks2019  
Student: Yung-Lun Lee

---

## 1. Overview

This project focuses on building and comparing secure and vulnerable Dynamic SQL in SQL Server.  
I created two stored procedures, added input validation, logging, and a summary view to help analyze the results.  
The main idea is to understand SQL injection, how to prevent it, and how different SQL execution methods affect performance.

---

## 2. What I Implemented

### 2.1 Secure Dynamic SQL Procedure

- Uses `sp_executesql`  
- Fully parameterized  
- TRY/CATCH error handling  
- Logs all executions  
- Rejects suspicious input such as `DROP`, `;--`, `INSERT`, or `EXEC`

Procedure name:

Reporting.DynamicSalesSummarySecure


### 2.2 Vulnerable Dynamic SQL Procedure

- Uses string concatenation  
- Executes with `EXEC(@SQL)`  
- No validation  
- Demonstrates how SQL injection happens  

Procedure name:

Reporting.DynamicSalesSummaryVulnerable


### 2.3 Input Validation

I added simple pattern checking.  
If any input contains suspicious substrings, the procedure:

1. Stops running  
2. Logs the attempt as `RejectedInput`  
3. Returns a safe error message  

### 2.4 Audit Summary View

This view summarizes:

- How many times each procedure was executed  
- Average runtime (DurationMS)  
- Success and failure counts  
- Rejected input attempts  

View name:

Reporting.DSLAuditSummary


---

## 3. How to Test

### Test 1 — Secure Procedure

```sql
EXEC Reporting.DynamicSalesSummarySecure
    @Territory = 'Northwest',
    @Category = 'Accessories';

Test 2 — Vulnerable Procedure
EXEC Reporting.DynamicSalesSummaryVulnerable
    @Territory = 'Northwest',
    @Category = 'Accessories';

Test 3 — SQL Injection Attempt (Should Be Rejected)
EXEC Reporting.DynamicSalesSummarySecure
    @Territory = 'Northwest; DROP TABLE Sales.SalesOrderHeader;--';

Test 4 — View the Audit Summary
SELECT * FROM Reporting.DSLAuditSummary;

4. Expected Results
The secure version runs safely and blocks injection
The vulnerable version accepts injected input (for demonstration only)
ExecutionLog table shows detailed logs
RejectedInput entries appear in the log
The summary view shows execution counts and performance differences

