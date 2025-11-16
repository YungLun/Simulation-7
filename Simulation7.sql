USE AdventureWorks2019;
GO

--Task 1 ¡V Audit Structure Enhancement
ALTER TABLE Reporting.ExecutionLog
ADD ExecutedBy      NVARCHAR(128) NULL,
    HostName        NVARCHAR(128) NULL,
    DurationMS      INT           NULL,
    ParameterValues NVARCHAR(MAX) NULL;
GO



--Task 2 ¡V Secure DSL Implementation
CREATE OR ALTER PROCEDURE Reporting.DynamicSalesSummarySecure
(
    @Territory   NVARCHAR(50) = NULL,
    @SalesPerson NVARCHAR(100) = NULL,
    @Category    NVARCHAR(50) = NULL,
    @StartDate   DATE = NULL,
    @EndDate     DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- Variable Declarations
    ---------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX) = N'';
    DECLARE @ParamDef NVARCHAR(MAX);
    DECLARE @StartTime DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @EndTime DATETIME2(3);
    DECLARE @DurationMS INT;
    DECLARE @ParameterValues NVARCHAR(MAX) = N'';

    BEGIN TRY
        ---------------------------------------------------------
        -- Basic Input Validation (Full version in Task 4)
        ---------------------------------------------------------
        IF @Territory   LIKE '%;%' OR
           @SalesPerson LIKE '%;%' OR
           @Category    LIKE '%;%' 
        BEGIN
            THROW 51000, 'Invalid characters detected in input parameters.', 1;
        END

        ---------------------------------------------------------
        -- Construct Base Query
        ---------------------------------------------------------
        SET @SQL = N'
            SELECT 
                sp.BusinessEntityID,
                p.FirstName + '' '' + p.LastName AS SalesPerson,
                st.Name AS Territory,
                pc.Name AS Category,
                soh.OrderDate,
                soh.TotalDue
            FROM Sales.SalesOrderHeader soh
            INNER JOIN Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
            INNER JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
            INNER JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
            INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
            INNER JOIN Production.Product pr ON sod.ProductID = pr.ProductID
            INNER JOIN Production.ProductSubcategory psc ON pr.ProductSubcategoryID = psc.ProductSubcategoryID
            INNER JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
            WHERE 1 = 1
        ';

        ---------------------------------------------------------
        -- Dynamic Filters (Parameterized and Safe)
        ---------------------------------------------------------
        IF @Territory IS NOT NULL
            SET @SQL += N' AND st.Name = @Territory';

        IF @SalesPerson IS NOT NULL
            SET @SQL += N' AND p.LastName = @SalesPerson';

        IF @Category IS NOT NULL
            SET @SQL += N' AND pc.Name = @Category';

        IF @StartDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate >= @StartDate';

        IF @EndDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate <= @EndDate';

        ---------------------------------------------------------
        -- Parameter Definitions for sp_executesql
        ---------------------------------------------------------
        SET @ParamDef = N'
            @Territory NVARCHAR(50),
            @SalesPerson NVARCHAR(100),
            @Category NVARCHAR(50),
            @StartDate DATE,
            @EndDate DATE
        ';

        ---------------------------------------------------------
        -- Combine Parameter Values for Logging
        ---------------------------------------------------------
        SET @ParameterValues =
            'Territory=' + ISNULL(@Territory, 'NULL') + '; ' +
            'SalesPerson=' + ISNULL(@SalesPerson, 'NULL') + '; ' +
            'Category=' + ISNULL(@Category, 'NULL') + '; ' +
            'StartDate=' + ISNULL(CONVERT(NVARCHAR(20), @StartDate), 'NULL') + '; ' +
            'EndDate=' + ISNULL(CONVERT(NVARCHAR(20), @EndDate), 'NULL');

        ---------------------------------------------------------
        -- Execute Parameterized Dynamic SQL
        ---------------------------------------------------------
        EXEC sp_executesql
            @SQL,
            @ParamDef,
            @Territory,
            @SalesPerson,
            @Category,
            @StartDate,
            @EndDate;

        ---------------------------------------------------------
        -- Execute Parameterized Dynamic SQL
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        ---------------------------------------------------------
        -- Insert Success Log
        ---------------------------------------------------------
        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummarySecure',
            @SQL,
            SYSUTCDATETIME(),
            NULL,
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );
    END TRY
    BEGIN CATCH
        ---------------------------------------------------------
        -- Insert Failure Log
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummarySecure',
            @SQL,
            SYSUTCDATETIME(),
            ERROR_MESSAGE(),
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );

        THROW;
    END CATCH
END
GO





--Task 3 ¡V Vulnerable DSL Simulation
USE AdventureWorks2019;
GO

CREATE OR ALTER PROCEDURE Reporting.DynamicSalesSummaryVulnerable
(
    @Territory   NVARCHAR(50) = NULL,
    @SalesPerson NVARCHAR(100) = NULL,
    @Category    NVARCHAR(50) = NULL,
    @StartDate   NVARCHAR(20) = NULL,   -- Using NVARCHAR to make injection easier
    @EndDate     NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- Variable Declarations
    ---------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX) = N'';
    DECLARE @StartTime DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @EndTime DATETIME2(3);
    DECLARE @DurationMS INT;
    DECLARE @ParameterValues NVARCHAR(MAX) = N'';

    BEGIN TRY
        ---------------------------------------------------------
        -- Construct SQL by string concatenation (UNSAFE!)
        ---------------------------------------------------------
        SET @SQL = N'
            SELECT 
                sp.BusinessEntityID,
                p.FirstName + '' '' + p.LastName AS SalesPerson,
                st.Name AS Territory,
                pc.Name AS Category,
                soh.OrderDate,
                soh.TotalDue
            FROM Sales.SalesOrderHeader soh
            INNER JOIN Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
            INNER JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
            INNER JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
            INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
            INNER JOIN Production.Product pr ON sod.ProductID = pr.ProductID
            INNER JOIN Production.ProductSubcategory psc ON pr.ProductSubcategoryID = psc.ProductSubcategoryID
            INNER JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
            WHERE 1 = 1 ';

        ---------------------------------------------------------
        -- UNSAFE CONDITION APPENDING
        ---------------------------------------------------------
        IF @Territory IS NOT NULL
            SET @SQL += N' AND st.Name = ''' + @Territory + '''';

        IF @SalesPerson IS NOT NULL
            SET @SQL += N' AND p.LastName = ''' + @SalesPerson + '''';

        IF @Category IS NOT NULL
            SET @SQL += N' AND pc.Name = ''' + @Category + '''';

        IF @StartDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate >= ''' + @StartDate + '''';

        IF @EndDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate <= ''' + @EndDate + '''';

        ---------------------------------------------------------
        -- Combine parameter values (for logging)
        ---------------------------------------------------------
        SET @ParameterValues =
            'Territory=' + ISNULL(@Territory, 'NULL') + '; ' +
            'SalesPerson=' + ISNULL(@SalesPerson, 'NULL') + '; ' +
            'Category=' + ISNULL(@Category, 'NULL') + '; ' +
            'StartDate=' + ISNULL(@StartDate, 'NULL') + '; ' +
            'EndDate=' + ISNULL(@EndDate, 'NULL');

        ---------------------------------------------------------
        -- Execute UNSAFE SQL
        ---------------------------------------------------------
        EXEC(@SQL);

        ---------------------------------------------------------
        -- Execution Time Calculation
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        ---------------------------------------------------------
        -- Insert Log (Success)
        ---------------------------------------------------------
        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummaryVulnerable',
            @SQL,
            SYSUTCDATETIME(),
            NULL,
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );
    END TRY
    BEGIN CATCH
        ---------------------------------------------------------
        -- Insert Log (Failure)
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummaryVulnerable',
            @SQL,
            SYSUTCDATETIME(),
            ERROR_MESSAGE(),
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );

        THROW;
    END CATCH
END
GO


--test
EXEC Reporting.DynamicSalesSummaryVulnerable
    @Territory = ''' OR 1=1 --';

SELECT TOP 10 *
FROM Reporting.ExecutionLog
ORDER BY LogID DESC;




--Task 4 ¡V Input Validation and Rejection Handling
USE AdventureWorks2019;
GO

CREATE OR ALTER PROCEDURE Reporting.DynamicSalesSummarySecure
(
    @Territory   NVARCHAR(50) = NULL,
    @SalesPerson NVARCHAR(100) = NULL,
    @Category    NVARCHAR(50) = NULL,
    @StartDate   DATE = NULL,
    @EndDate     DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- Variable Declarations
    ---------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX) = N'';
    DECLARE @ParamDef NVARCHAR(MAX);
    DECLARE @StartTime DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @EndTime DATETIME2(3);
    DECLARE @DurationMS INT;
    DECLARE @ParameterValues NVARCHAR(MAX) = N'';

    ---------------------------------------------------------
    -- Input Validation for SQL Injection (Task 4)
    ---------------------------------------------------------
    DECLARE @InputAll NVARCHAR(MAX) =
        ISNULL(@Territory, '') + ' ' +
        ISNULL(@SalesPerson, '') + ' ' +
        ISNULL(@Category, '') + ' ' +
        ISNULL(CONVERT(NVARCHAR(20), @StartDate), '') + ' ' +
        ISNULL(CONVERT(NVARCHAR(20), @EndDate), '');

    IF @InputAll LIKE '%;--%' OR
       @InputAll LIKE '%DROP%' OR
       @InputAll LIKE '%INSERT%' OR
       @InputAll LIKE '%EXEC%' 
    BEGIN
        -----------------------------------------------------
        -- Log Rejected Input
        -----------------------------------------------------
        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummarySecure',
            NULL,
            SYSUTCDATETIME(),
            'RejectedInput: Suspicious keywords detected.',
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            0,
            @InputAll
        );

        -- Return Safe Error Message
        THROW 51001, 'Input rejected due to security policy.', 1;
    END

    BEGIN TRY
        ---------------------------------------------------------
        -- Base Query
        ---------------------------------------------------------
        SET @SQL = N'
            SELECT 
                sp.BusinessEntityID,
                p.FirstName + '' '' + p.LastName AS SalesPerson,
                st.Name AS Territory,
                pc.Name AS Category,
                soh.OrderDate,
                soh.TotalDue
            FROM Sales.SalesOrderHeader soh
            INNER JOIN Sales.SalesPerson sp ON soh.SalesPersonID = sp.BusinessEntityID
            INNER JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
            INNER JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
            INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
            INNER JOIN Production.Product pr ON sod.ProductID = pr.ProductID
            INNER JOIN Production.ProductSubcategory psc ON pr.ProductSubcategoryID = psc.ProductSubcategoryID
            INNER JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
            WHERE 1 = 1
        ';

        ---------------------------------------------------------
        -- Parameterized Filters (Safe)
        ---------------------------------------------------------
        IF @Territory IS NOT NULL
            SET @SQL += N' AND st.Name = @Territory';

        IF @SalesPerson IS NOT NULL
            SET @SQL += N' AND p.LastName = @SalesPerson';

        IF @Category IS NOT NULL
            SET @SQL += N' AND pc.Name = @Category';

        IF @StartDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate >= @StartDate';

        IF @EndDate IS NOT NULL
            SET @SQL += N' AND soh.OrderDate <= @EndDate';

        ---------------------------------------------------------
        -- Parameter Definition
        ---------------------------------------------------------
        SET @ParamDef = N'
            @Territory NVARCHAR(50),
            @SalesPerson NVARCHAR(100),
            @Category NVARCHAR(50),
            @StartDate DATE,
            @EndDate DATE';

        ---------------------------------------------------------
        -- Build ParameterValues for Log
        ---------------------------------------------------------
        SET @ParameterValues =
            'Territory=' + ISNULL(@Territory, 'NULL') + '; ' +
            'SalesPerson=' + ISNULL(@SalesPerson, 'NULL') + '; ' +
            'Category=' + ISNULL(@Category, 'NULL') + '; ' +
            'StartDate=' + ISNULL(CONVERT(NVARCHAR(20), @StartDate), 'NULL') + '; ' +
            'EndDate=' + ISNULL(CONVERT(NVARCHAR(20), @EndDate), 'NULL');

        ---------------------------------------------------------
        -- Execute Safe Parameterized SQL
        ---------------------------------------------------------
        EXEC sp_executesql
            @SQL,
            @ParamDef,
            @Territory,
            @SalesPerson,
            @Category,
            @StartDate,
            @EndDate;

        ---------------------------------------------------------
        -- Successful Execution Log
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummarySecure',
            @SQL,
            SYSUTCDATETIME(),
            NULL,
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );
    END TRY
    BEGIN CATCH
        ---------------------------------------------------------
        -- Error Log
        ---------------------------------------------------------
        SET @EndTime = SYSUTCDATETIME();
        SET @DurationMS = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

        INSERT INTO Reporting.ExecutionLog
        (
            ProcedureName,
            ExecutedSQL,
            ExecutionDate,
            ErrorMessage,
            ExecutedBy,
            HostName,
            DurationMS,
            ParameterValues
        )
        VALUES
        (
            'Reporting.DynamicSalesSummarySecure',
            @SQL,
            SYSUTCDATETIME(),
            ERROR_MESSAGE(),
            ORIGINAL_LOGIN(),
            HOST_NAME(),
            @DurationMS,
            @ParameterValues
        );

        THROW;
    END CATCH
END
GO

--test
EXEC Reporting.DynamicSalesSummarySecure
    @Territory = 'Northwest; DROP TABLE Sales.SalesOrderHeader --';


SELECT TOP 10 *
FROM Reporting.ExecutionLog
ORDER BY LogID DESC;



--Task 5 ¡V DSL Audit and Performance Reporting
USE AdventureWorks2019;
GO

CREATE OR ALTER VIEW Reporting.DSLAuditSummary
AS
SELECT
    ProcedureName,
    COUNT(*) AS ExecutionCount,                          
    AVG(DurationMS) AS AvgDurationMS,                    
    SUM(CASE WHEN ErrorMessage IS NULL 
             THEN 1 ELSE 0 END) AS SuccessCount,         
    SUM(CASE WHEN ErrorMessage IS NOT NULL 
             THEN 1 ELSE 0 END) AS FailureCount,         
    SUM(CASE WHEN ErrorMessage LIKE 'RejectedInput%' 
             THEN 1 ELSE 0 END) AS RejectedInputCount    
FROM Reporting.ExecutionLog
GROUP BY ProcedureName;
GO


--Audit Summary View
SELECT *
FROM Reporting.DSLAuditSummary;

--test
EXEC Reporting.DynamicSalesSummarySecure
    @Territory = 'Northwest',
    @Category = 'Bikes';

EXEC Reporting.DynamicSalesSummaryVulnerable
    @Territory = 'Northwest',
    @Category = 'Bikes';

SELECT TOP 10 *
FROM Reporting.ExecutionLog
ORDER BY LogID DESC;



