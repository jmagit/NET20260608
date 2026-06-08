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


-- Creación de la estructura de la tabla con Always Encrypted nativo
CREATE TABLE HumanResources.EmpleadosConfidencial (
    EmpleadoID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    
    -- Columna con cifrado determinista para búsquedas de igualdad
    NumeroSeguroSocial NVARCHAR(11) 
        COLLATE Latin1_General_BIN2 -- Obligatorio colación binaria para Always Encrypted
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [MiCEK_Segura], 
            ENCRYPTION_TYPE = Deterministic, 
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NOT NULL,
        
    -- Columna con cifrado aleatorio para máxima protección sin búsquedas directas
    SalarioMensual DECIMAL(18,2) 
        ENCRYPTED WITH (
            COLUMN_ENCRYPTION_KEY = [MiCEK_Segura], 
            ENCRYPTION_TYPE = Randomized, 
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        ) NOT NULL
);

-- SEGURIDAD DE NIVEL DE FILA (RLS) 

USE DEMOS;

-- Paso A: Creación de la tabla de negocio
CREATE TABLE dbo.Notificaciones	(
	id INT NOT NULL IDENTITY (1, 1) CONSTRAINT PK_Notificaciones PRIMARY KEY CLUSTERED (id),
	mensaje NVARCHAR(250) NOT NULL,
    remitente NVARCHAR(250) MASKED WITH (FUNCTION = 'email()') NOT NULL,
	leido BIT NOT NULL CONSTRAINT DF_Notificaciones_leido DEFAULT 0,
	propietario NVARCHAR(128) NOT NULL CONSTRAINT DF_Notificaciones_propietario DEFAULT SYSTEM_USER,
	version TIMESTAMP NOT NULL
	) ON [PRIMARY]
GO
-- Paso B: Creación del esquema de seguridad y la función de predicado en línea
CREATE SCHEMA Security;
GO
CREATE FUNCTION Security.tvf_FiltroCosultarNotificaciones(@usuario AS NVARCHAR(128)) RETURNS TABLE
WITH SCHEMABINDING -- Si el usuario que consulta es el dueño de la fila o base de datos (dbo)
AS RETURN SELECT 1 AS resultado WHERE @usuario = USER_NAME() OR USER_NAME() = 'dbo';
GO
CREATE FUNCTION Security.tvf_FiltroCambiaNotificaciones(@usuario AS NVARCHAR(128)) RETURNS TABLE
WITH SCHEMABINDING -- Solo el dueño de la fila
AS RETURN SELECT 1 AS resultado WHERE @usuario = USER_NAME();
GO
-- Paso C: Creación de la directiva de seguridad que activa RLS
CREATE SECURITY POLICY Security.RowFilterNotificaciones
ADD FILTER PREDICATE Security.tvf_FiltroCosultarNotificaciones(propietario) ON dbo.Notificaciones,
ADD BLOCK PREDICATE Security.tvf_FiltroCambiaNotificaciones(propietario) ON dbo.Notificaciones AFTER INSERT
WITH (STATE = ON);
GO
INSERT INTO dbo.Notificaciones(mensaje,remitente)
     VALUES ('Hola','demo@example.com')
INSERT INTO dbo.Notificaciones(mensaje,remitente,propietario)
     VALUES ('Hola','adm@example.com','demo')
INSERT INTO dbo.Notificaciones(mensaje,remitente)
     VALUES ('¿que tal?','demo@example.com')
UPDATE dbo.Notificaciones
SET leido = 1
    , propietario = 'demo'
WHERE id = 1
EXECUTE AS USER = 'demo';
GO
SELECT USER_NAME(), * FROM Notificaciones;
GO
REVERT
GO
SELECT USER_NAME(), * FROM Notificaciones;

-- Error-Based Side-Channel

SELECT * FROM [HumanResources].[EmployeePayHistory]
SELECT 1 FROM HumanResources.EmployeePayHistory
WHERE BusinessEntityID = 1 AND 1 / (Rate - 125.5) = 0


-- ENMASCARAMIENTO DINÁMICO DE DATOS

-- Creación de la tabla con máscaras de datos integradas
DROP TABLE IF EXISTS dbo.Enmascarados
CREATE TABLE dbo.Enmascarados (
    ClienteID INT IDENTITY(1,1) PRIMARY KEY,
    -- Enmascaramiento por defecto para el nombre completo
    NombreCompleto NVARCHAR(150) MASKED WITH (FUNCTION = 'default()') NOT NULL,
    -- Enmascaramiento de correo electrónico
    CorreoElectronico NVARCHAR(100) MASKED WITH (FUNCTION = 'email()') NOT NULL,
    -- Enmascaramiento parcial para la tarjeta de crédito (Muestra solo los últimos 4 dígitos)
    TarjetaCredito VARCHAR(19) MASKED WITH (FUNCTION = 'partial(4, "-XXXX-XXXX-", 4)') NOT NULL,
    -- Enmascaramiento aleatorio para la puntuación de riesgo crediticio
    ScoreRiesgo INT MASKED WITH (FUNCTION = 'random(1, 10)') NOT NULL,
    -- Enmascaramiento por defecto para la fecha, siempre: 1900-01-01 00:00:00.0000000
    FechaPorDedecto DATETIME2 MASKED WITH (FUNCTION = 'default()') NOT NULL,
    -- Enmascaramiento solo el año
    [FechaCumpleaños] DATETIME2 MASKED WITH (FUNCTION = 'datetime("Y")') NOT NULL
);
GO
-- Datos de ejemplo
INSERT INTO dbo.Enmascarados
VALUES ('Carlos Mendoza', 'carlos.mendoza@telecom.com', '4532-7788-9900-1122', 750, GETDATE(), GETDATE());
GO

SELECT USER_NAME(), * FROM Enmascarados;
-- Enmascarado por defecto
EXECUTE AS USER = 'demo';
GO
SELECT USER_NAME(), * FROM Enmascarados;
GO
REVERT
SELECT USER_NAME(), * FROM Enmascarados;
GO
-- Desenmascararle la tabla (texto claro)
GRANT UNMASK ON [dbo].[Enmascarados] TO [demo]
GO
EXECUTE AS USER = 'demo';
GO
SELECT USER_NAME(), * FROM Enmascarados;
GO
REVERT
-- Quitar el permiso (texto enmascarado)
REVOKE UNMASK ON [dbo].[Enmascarados] TO [demo]

