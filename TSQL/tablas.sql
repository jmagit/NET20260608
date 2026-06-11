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

DECLARE @previusVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION() - 2;
SELECT *
FROM CHANGETABLE(CHANGES Sales.SalesOrderHeader, @previusVersion) ct

DECLARE @previusVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION() - 2;
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
WHERE SalesOrderID = 75126

DELETE Sales.SalesOrderHeader WHERE SalesOrderID = 75128

USE [AdventureWorks2025]
GO

/****** Object:  UserDefinedFunction [dbo].[ufnSalesOrderHeaderChanges]    Script Date: 02/06/2026 21:44:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Javier
-- Description:	Control de Cambios
-- =============================================
ALTER FUNCTION [dbo].[ufnSalesOrderHeaderChanges] (@previusVersion BIGINT)
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
SELECT * FROM ufnSalesOrderHeaderChanges (13)
GO

-- cleanup
ALTER TABLE Sales.SalesOrderHeader DISABLE CHANGE_TRACKING;
GO
ALTER DATABASE AdventureWorks2025 SET CHANGE_TRACKING = OFF;
GO

