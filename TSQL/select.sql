-- Expresión de tabla común (CTE)
WITH Trimestres AS (
SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, SUM([TotalDue]) total
FROM [Sales].[SalesOrderHeader]
GROUP BY DATEPART(YEAR, [ShipDate]), DATEPART(QUARTER, [ShipDate]) 
)
SELECT *
FROM Trimestres

-- Clausulas PIVOT, UNPIVOT
SELECT AÑO, [1] T1, [2] T2, [3] T3, [4] T4
FROM  (SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, [TotalDue] total
FROM [Sales].[SalesOrderHeader]) s 
    PIVOT(
        SUM(total) FOR trimestre IN ([1], [2], [3], [4])
    ) p
ORDER BY AÑO

SELECT *
FROM  (SELECT [SalesOrderID], [SubTotal] S, [TaxAmt] T FROM [Sales].[SalesOrderHeader]) s 
    UNPIVOT(
        Cantidad FOR Tipo IN (S, T)
    ) p

-- Clausulas ROLLUP, CUBE, GROUPING SETS
SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, DATEPART(MONTH, [ShipDate]) MES, SUM([TotalDue]) total
FROM [Sales].[SalesOrderHeader]
GROUP BY DATEPART(YEAR, [ShipDate]), DATEPART(QUARTER, [ShipDate]), DATEPART(MONTH, [ShipDate]) 

SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, DATEPART(MONTH, [ShipDate]) MES, COUNT(1) pedidos, FORMAT(SUM([TotalDue]), 'C', 'es-es') total
FROM [Sales].[SalesOrderHeader]
GROUP BY ROLLUP (DATEPART(YEAR, [ShipDate]), DATEPART(QUARTER, [ShipDate]), DATEPART(MONTH, [ShipDate]))

SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, DATEPART(MONTH, [ShipDate]) MES, COUNT(1) pedidos, FORMAT(SUM([TotalDue]), 'C', 'es-es') total
FROM [Sales].[SalesOrderHeader]
GROUP BY CUBE (DATEPART(YEAR, [ShipDate]), DATEPART(QUARTER, [ShipDate]), DATEPART(MONTH, [ShipDate]))

SELECT DATEPART(YEAR, [ShipDate]) año, DATEPART(QUARTER, [ShipDate]) trimestre, DATEPART(MONTH, [ShipDate]) MES, COUNT(1) pedidos, FORMAT(SUM([TotalDue]), 'C', 'es-es') total
FROM [Sales].[SalesOrderHeader]
GROUP BY GROUPING SETS (DATEPART(YEAR, [ShipDate]), DATEPART(QUARTER, [ShipDate]), DATEPART(MONTH, [ShipDate]), ())

-- Clausula WINDOW
SELECT SalesOrderID AS OrderNumber, ProductID, OrderQty AS Qty,
       SUM(OrderQty) OVER ordenada AS Total,
       AVG(OrderQty) OVER particionada AS Avg,
       rank() OVER (ordenada PARTITION BY ProductID) AS Ranking
FROM Sales.SalesOrderDetail
WHERE SalesOrderID IN (43659, 43664) AND ProductID LIKE '71%'
WINDOW ordenada AS (ORDER BY SalesOrderID, ProductID),
       particionada AS (ordenada PARTITION BY SalesOrderID);

-- Clausulas OFFSET/FETCH
DECLARE @Page AS TINYINT = 0, @Rows AS TINYINT = 5

SELECT BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre
FROM Person.Person
ORDER BY nombre ASC OFFSET @Page * @Rows ROWS FETCH NEXT @Rows ROWS ONLY;

SELECT @Page = @Page + 1
SELECT BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre
FROM Person.Person
ORDER BY nombre ASC OFFSET @Page * @Rows ROWS FETCH NEXT @Rows ROWS ONLY;

SELECT @Page = @Page + 1
SELECT BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre
FROM Person.Person
ORDER BY nombre ASC OFFSET @Page * @Rows ROWS FETCH NEXT @Rows ROWS ONLY;

-- Subconsultas

SELECT DISTINCT pp.LastName,
                pp.FirstName
FROM Person.Person AS pp
     INNER JOIN HumanResources.Employee AS e
         ON e.BusinessEntityID = pp.BusinessEntityID
WHERE pp.BusinessEntityID IN (
    SELECT SalesPersonID
    FROM Sales.SalesOrderHeader
    WHERE SalesOrderID IN (
        SELECT SalesOrderID
        FROM Sales.SalesOrderDetail
        WHERE ProductID IN (
            SELECT ProductID
            FROM Production.Product AS p
            WHERE ProductNumber = 'BK-M68B-42')));

-- Búsqueda de texto completo

SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled');

CREATE FULLTEXT CATALOG production_catalog;

CREATE FULLTEXT INDEX ON Production.ProductDescription (Description) 
KEY INDEX PK_ProductDescription_ProductDescriptionID 
ON production_catalog;

SELECT * 
FROM [Production].[ProductDescription]
WHERE FREETEXT([Description], 'aluminium')


-- Transacciones

--ALTER DATABASE AdventureWorks2016_EXT 
--SET READ_COMMITTED_SNAPSHOT ON;

ALTER DATABASE AdventureWorks2025
SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON );
GO
SELECT name AS Caracteristica, desired_state_desc AS EstadoConfigurado,
    actual_state_desc AS EstadoReal, reason_desc AS RazonEstado
FROM sys.database_automatic_tuning_options


