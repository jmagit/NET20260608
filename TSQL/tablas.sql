-- COMPRESIÓN DE DATOS

EXEC sp_estimate_data_compression_savings 
	@schema_name = 'Person', @object_name = 'Person', 
	@index_id = NULL, @partition_number = NULL, @data_compression = 'PAGE';

EXEC sp_estimate_data_compression_savings 
	@schema_name = 'Person', @object_name = 'Person', 
	@index_id = NULL, @partition_number = NULL, @data_compression = 'ROW';

-- Activar Read Committed Snapshot (RCSI)

ALTER DATABASE AdventureWorks2022 SET READ_COMMITTED_SNAPSHOT ON;

SELECT name, is_read_committed_snapshot_on   -- 1 si está activado
FROM sys.databases 
WHERE name = 'AdventureWorks2022';

-- VERSIÓN DE LA FILA (ROWVERSION)
ALTER TABLE [Person].[Details] DROP COLUMN IF EXISTS [version]
GO
ALTER TABLE [Person].[Details] ADD version ROWVERSION
GO
SELECT TOP 10 * FROM [Person].[Details]
GO

DECLARE @last TIMESTAMP
SELECT @last = max(version) FROM [Person].[Details]

UPDATE [Person].[Details]
SET Details = JSON_MODIFY(Details, '$.ContactType', 'None')
WHERE BusinessEntityID < 10

SELECT *, @last FROM [Person].[Details] WHERE version > @last

GO

-- SEGUIMIENTO DE CAMBIOS (CHANGE TRACKING - CT)

ALTER DATABASE AdventureWorks2025
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO

ALTER TABLE Sales.SalesOrderHeader
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

-- Tablas con Change Tracking activado
SELECT OBJECT_NAME(object_id) AS Tabla, is_track_columns_updated_on
FROM sys.change_tracking_tables;

SELECT TOP 10 * FROM Sales.SalesOrderHeader ORDER BY SalesOrderID

UPDATE Sales.SalesOrderHeader 
SET CreditCardApprovalCode = UPPER(CreditCardApprovalCode), 
    TaxAmt = TaxAmt -- * 0.91
--WHERE SalesOrderID < 43661
WHERE SalesOrderID in (43660, 43666) 

SELECT CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('Sales.SalesOrderHeader')) Primera, 
    CHANGE_TRACKING_CURRENT_VERSION() Ultima,
    COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'SalesOrderID', 'ColumnId') SalesOrderID,
    COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'CreditCardApprovalCode', 'ColumnId') CreditCardApprovalCode,
    COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'TaxAmt', 'ColumnId') TaxAmt,
    COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'TotalDue', 'ColumnId') TotalDue

DECLARE @previusVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION() - 1;
SELECT *
FROM CHANGETABLE(CHANGES Sales.SalesOrderHeader, @previusVersion) ct

DECLARE @previusVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION() - 1;
SELECT 
    CT.SalesOrderID, 
    CT.SYS_CHANGE_OPERATION, -- I (Insert), U (Update), D (Delete)
    CT.SYS_CHANGE_COLUMNS,   -- Binario que indica qué columnas cambiaron
    CHANGE_TRACKING_IS_COLUMN_IN_MASK(COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'SalesOrderID', 'ColumnId'), SYS_CHANGE_COLUMNS) AS CambiaSalesOrderID,
    CHANGE_TRACKING_IS_COLUMN_IN_MASK(COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'CreditCardApprovalCode', 'ColumnId'), SYS_CHANGE_COLUMNS) AS CambiaCreditCardApprovalCode,
    CHANGE_TRACKING_IS_COLUMN_IN_MASK(COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'TaxAmt', 'ColumnId'), SYS_CHANGE_COLUMNS) AS CambiaTaxAmt,
    CHANGE_TRACKING_IS_COLUMN_IN_MASK(COLUMNPROPERTY(OBJECT_ID('Sales.SalesOrderHeader'), 'TotalDue', 'ColumnId'), SYS_CHANGE_COLUMNS) AS CambioTotalDue,
    S.CreditCardApprovalCode -- Unimos con la tabla real para traer el dato actual
FROM CHANGETABLE(CHANGES Sales.SalesOrderHeader, @previusVersion) AS CT
    LEFT JOIN Sales.SalesOrderHeader AS S ON CT.SalesOrderID = S.SalesOrderID;

-- puedes implementar una estrategia de Caché Distribuida muy eficiente.
DECLARE @previusVersion BIGINT = CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('Sales.SalesOrderHeader')) -- CHANGE_TRACKING_CURRENT_VERSION() - 1;
SELECT CT.SYS_CHANGE_OPERATION Tipo, CT.SYS_CHANGE_COLUMNS Columnas, s.*
FROM CHANGETABLE(CHANGES Sales.SalesOrderHeader, @previusVersion) AS CT
    LEFT JOIN Sales.SalesOrderHeader AS S ON CT.SalesOrderID = S.SalesOrderID
WHERE CT.SYS_CHANGE_OPERATION <> 'D'

INSERT INTO [Sales].[SalesOrderHeader](
    RevisionNumber, OrderDate, DueDate, ShipDate, Status, OnlineOrderFlag, PurchaseOrderNumber, 
    AccountNumber, CustomerID, SalesPersonID, TerritoryID, BillToAddressID, ShipToAddressID, ShipMethodID, CreditCardID, 
    CreditCardApprovalCode, CurrencyRateID, SubTotal, TaxAmt, Freight, Comment)
SELECT RevisionNumber, OrderDate, DueDate, ShipDate, Status, OnlineOrderFlag, PurchaseOrderNumber, 
    AccountNumber, CustomerID, SalesPersonID, TerritoryID, BillToAddressID, ShipToAddressID, ShipMethodID, CreditCardID, 
    CreditCardApprovalCode, CurrencyRateID, SubTotal, TaxAmt, Freight, Comment 
FROM [Sales].[SalesOrderHeader] WHERE [SalesOrderID] = 75000

UPDATE Sales.SalesOrderHeader 
SET ModifiedDate = GETDATE()
WHERE SalesOrderID = 75125

DELETE Sales.SalesOrderHeader WHERE SalesOrderID = 75125

USE [AdventureWorks2025]
GO

CREATE OR ALTER FUNCTION [dbo].[ufnSalesOrderHeaderChanges] (@previusVersion BIGINT)
RETURNS TABLE AS RETURN (
    SELECT CT.SYS_CHANGE_VERSION CT_Version, CT.SYS_CHANGE_OPERATION CT_Operation, CT.SYS_CHANGE_COLUMNS CT_Columns, 
        ISNULL(s.SalesOrderID, ct.SalesOrderID) SalesOrderID, RevisionNumber, OrderDate, DueDate, ShipDate, Status, 
        OnlineOrderFlag, SalesOrderNumber, PurchaseOrderNumber, AccountNumber, CustomerID, SalesPersonID, TerritoryID, 
        BillToAddressID, ShipToAddressID, ShipMethodID, CreditCardID, CreditCardApprovalCode, CurrencyRateID, SubTotal, 
        TaxAmt, Freight, TotalDue, Comment, rowguid, ModifiedDate
    FROM CHANGETABLE(CHANGES Sales.SalesOrderHeader, @previusVersion) AS CT
        LEFT JOIN Sales.SalesOrderHeader AS S ON CT.SalesOrderID = S.SalesOrderID
)
GO
DECLARE @previusVersion BIGINT = CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('Sales.SalesOrderHeader')) -- CHANGE_TRACKING_CURRENT_VERSION() - 1;
SELECT * FROM ufnSalesOrderHeaderChanges(@previusVersion)
GO

-- cleanup
ALTER TABLE Sales.SalesOrderHeader DISABLE CHANGE_TRACKING;
GO
ALTER DATABASE AdventureWorks2025 SET CHANGE_TRACKING = OFF;
GO

-- CAPTURA DE DATOS CAMBIADOS (CDC)

EXEC sys.sp_cdc_enable_db;
GO
SELECT name, is_cdc_enabled FROM sys.databases;
GO

EXEC sys.sp_cdc_enable_table
    @source_schema = N'Person',
    @source_name   = N'Person',
    @role_name     = NULL, -- Si pones un rol, solo esos usuarios verán los cambios
    @supports_net_changes = 1; -- Permite ver el resultado neto (solo el último estado)
GO
SELECT name, is_tracked_by_cdc FROM sys.tables WHERE is_tracked_by_cdc = 1;

SELECT * FROM cdc.Person_Person_CT
SELECT TOP 10 * FROM Person.Person

-- generar cambios
UPDATE Person.Person 
SET FirstName = UPPER(FirstName), 
    LastName = UPPER(LastName)
WHERE BusinessEntityID < 3
UPDATE Person.Person 
SET FirstName = UPPER(SUBSTRING(FirstName,1,1)) + LOWER(SUBSTRING(FirstName,2)), 
    LastName = UPPER(SUBSTRING(LastName,1,1)) + LOWER(SUBSTRING(LastName,2))
WHERE BusinessEntityID < 3

UPDATE Person.Person 
SET MiddleName = UPPER(MiddleName)
WHERE BusinessEntityID = 5
UPDATE Person.Person 
SET MiddleName = LOWER(MiddleName)
WHERE BusinessEntityID = 5

-- Consulta de cambios
DECLARE @begin_time DATETIME = GETDATE() - 1; -- Desde hace 24 horas
DECLARE @end_time DATETIME = GETDATE();
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('smallest greater than or equal', @begin_time);
DECLARE @to_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('largest less than or equal', @end_time);

SELECT 
    [__$operation],   -- 1=Delete, 2=Insert, 3=Before Update, 4=After Update
    [__$update_mask], -- Indica qué columnas cambiaron
    BusinessEntityID, FirstName, MiddleName, LastName
FROM cdc.fn_cdc_get_all_changes_Person_Person(@from_lsn, @to_lsn, 'all');

-- Consulta de cambios netos
DECLARE @begin_time DATETIME = GETDATE() - 1; -- Desde hace 24 horas
DECLARE @end_time DATETIME = GETDATE();
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('smallest greater than or equal', @begin_time);
DECLARE @to_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('largest less than or equal', @end_time);

SELECT 
    [__$operation],   -- 1=Delete, 2=Insert, 3=Before Update, 4=After Update
    [__$update_mask], -- Indica qué columnas cambiaron
    BusinessEntityID, FirstName, MiddleName, LastName
FROM cdc.fn_cdc_get_net_changes_Person_Person(@from_lsn, @to_lsn, 'all');

-- consumos del CDC
SELECT 
    s.name AS Esquema,
    t.name AS Tabla,
    p.rows AS NumeroDeFilas,
    (SUM(a.total_pages) * 8) / 1024 AS MB_Usados
FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.indexes i ON t.object_id = i.object_id
    JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE s.name = 'cdc'
GROUP BY s.name, t.name, p.rows;

-- auditar al usuario de los cambios
DECLARE @begin_time DATETIME = GETDATE() - 1; -- Desde hace 24 horas
DECLARE @end_time DATETIME = GETDATE();
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('smallest greater than or equal', @begin_time);
DECLARE @to_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('largest less than or equal', @end_time);

SELECT 
    c.[__$operation],
    c.BusinessEntityID,
    l.[Transaction SID],
    l.[Current LSN],
    SUSER_SNAME(l.[Transaction SID]) AS UsuarioQueCambio -- Traduce el SID a Nombre
FROM cdc.fn_cdc_get_all_changes_Person_Person(@from_lsn, @to_lsn, 'all') c
    CROSS APPLY fn_dblog(NULL, NULL) l
WHERE l.[Transaction SID] is not null

-- En una tabla
EXEC sys.sp_cdc_disable_table
    @source_schema = N'Person',
    @source_name   = N'Person',
    @capture_instance = N'Person_Person';

-- En toda la base de datos
EXEC sys.sp_cdc_disable_db;
GO


-- TABLAS TEMPORALES SYSTEM-VERSIONED

SELECT TOP 10 min(ModifiedDate) FROM Person.Person

ALTER TABLE Person.Person ADD
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START --HIDDEN
        CONSTRAINT DF_Person_ValidFrom DEFAULT CONVERT (DATETIME2, '2015-04-15'),
        --CONSTRAINT DF_Person_ValidFrom DEFAULT SYSUTCDATETIME(),
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END --HIDDEN
        CONSTRAINT DF_Person_ValidTo DEFAULT CONVERT (DATETIME2, '9999-12-31 23:59:59.9999999'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
ALTER TABLE Person.Person
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Person.PersonHistory));
GO

--CREATE SCHEMA History;
--GO
--ALTER TABLE Person.Person
--    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = History.PersonHistory));

ALTER TABLE Person.Person SET (SYSTEM_VERSIONING = OFF);
SET IDENTITY_INSERT Person.Person ON;
UPDATE Person.Person SET ValidFrom = ModifiedDate
SET IDENTITY_INSERT Person.Person OFF;
ALTER TABLE Person.Person SET (SYSTEM_VERSIONING = ON);

SELECT GETDATE()
SELECT TOP 10 * FROM Person.Person
SELECT TOP 10 * FROM Person.PersonHistory
SELECT TOP 10 * FROM Person.Person FOR SYSTEM_TIME ALL
SELECT TOP 10 * FROM Person.Person FOR SYSTEM_TIME AS OF '2015-05-05 00:00:00';
SELECT TOP 10 * FROM Person.Person FOR SYSTEM_TIME AS OF '2023-01-01 00:00:00';
SELECT TOP 10 * FROM Person.Person FOR SYSTEM_TIME BETWEEN '2015-01-01' AND '2026-05-15 10:16:03.740'
SELECT FirstName, ValidFrom
FROM Person.Person FOR SYSTEM_TIME BETWEEN '2015-01-01' AND '2026-06-30 10:16:03.740'
WHERE BusinessEntityID = 1
ORDER BY ValidFrom

-- generar cambios
UPDATE Person.Person 
SET FirstName = UPPER(FirstName), LastName = UPPER(LastName) WHERE BusinessEntityID < 3
UPDATE Person.Person 
SET FirstName = UPPER(SUBSTRING(FirstName,1,1)) + LOWER(SUBSTRING(FirstName,2)), 
    LastName = UPPER(SUBSTRING(LastName,1,1)) + LOWER(SUBSTRING(LastName,2))
WHERE BusinessEntityID < 3

UPDATE Person.Person 
SET MiddleName = UPPER(MiddleName)
WHERE BusinessEntityID = 5
UPDATE Person.Person 
SET MiddleName = LOWER(MiddleName)
WHERE BusinessEntityID = 5

-- cleanup
-- 1. Desactivar el versionado
ALTER TABLE Person.Person SET (SYSTEM_VERSIONING = OFF);
GO
-- 2. Eliminar la definición de periodo (esto desvincula las tablas internamente)
ALTER TABLE Person.Person DROP PERIOD FOR SYSTEM_TIME;
GO
-- 3. Eliminar las columnas de tiempo (opcional, si quieres limpiar la tabla)
ALTER TABLE Person.Person DROP 
	CONSTRAINT IF EXISTS [DF_Person_ValidFrom],
	COLUMN IF EXISTS ValidFrom,
	CONSTRAINT IF EXISTS [DF_Person_ValidTo],
	COLUMN IF EXISTS ValidTo
GO
-- 4. Eliminar la tabla de historial (¡Cuidado! Perderás todos los datos históricos)
DROP TABLE Person.PersonHistory;
GO

EXEC sp_estimate_data_compression_savings 
    @schema_name = 'Person', 
    @object_name = 'Person', 
    @index_id = NULL, 
    @partition_number = NULL, 
    @data_compression = 'PAGE'; -- O 'ROW'
