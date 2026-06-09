-- v2016

-- Separar etiquetas y saber cuál es la primera
SELECT value, ordinal
FROM STRING_SPLIT('Rojo,Verde,Azul', ',', 1);

SELECT ProductId, Name, Color, value, ordinal
FROM Production.Product INNER JOIN STRING_SPLIT('Red,Green,Blue',',', 1)
    ON value = Color;

SELECT DISTINCT Color 
FROM Production.Product
WHERE Color <> 'Silver';

SELECT DISTINCT Color 
FROM Production.Product
WHERE Color IS DISTINCT FROM 'Silver';

-- Comprimir / Descomprimir
ALTER TABLE Person.Person ADD
	PhoneNumbersGZip VARBINARY(MAX) NULL
GO
UPDATE Person.Person
SET PhoneNumbersGZip = COMPRESS(PhoneNumbers)

SELECT TOP 10 PhoneNumbers, PhoneNumbersGZip, CAST(DECOMPRESS(PhoneNumbersGZip) AS NVARCHAR(MAX)) unzip
FROM Person.Person
GO
ALTER TABLE Person.Person DROP
	COLUMN IF EXISTS PhoneNumbersGZip
GO


-- v2017

-- Listar todos los colores disponibles para cada subcategoría de producto.
SELECT ProductSubcategoryID, 
       STRING_AGG(Color, ', ') WITHIN GROUP (ORDER BY Color ASC) AS ColoresDisponibles
FROM Production.Product
WHERE Color IS NOT NULL
GROUP BY ProductSubcategoryID;

-- Crear una dirección completa sin preocuparse por campos vacíos.
SELECT CONCAT_WS(', ', AddressLine1, AddressLine2, City, PostalCode) AS DireccionCompleta
FROM Person.Address;

-- Limpiar formatos de números de teléfono en Person.PersonPhone.
SELECT PhoneNumber, TRANSLATE(PhoneNumber, '()-', '   ') AS TelefonoLimpio, -- Cambia todos esos por espacios
       FirstName, TRANSLATE(FirstName, 'áéíóúüñ', 'aeiouun') AS SinTildes
FROM Person.Person p INNER JOIN Person.PersonPhone t 
    ON p.BusinessEntityID = t.BusinessEntityID
WHERE REGEXP_LIKE(FirstName, '[áéíóúüñ]')



SELECT TRIM(' Hola '), -- Devuelve 'Hola'
    TRIM('0' FROM '00012300'), -- Devuelve '123'
    TRIM(LEADING '0' FROM '00012300'), -- Devuelve '12300'
    TRIM(TRAILING '0' FROM '00012300') -- Devuelve '000123'

-- v2019

-- Conteo rápido de clientes únicos en una tabla de auditoría gigante.
SELECT APPROX_COUNT_DISTINCT(CustomerID) FROM Sales.SalesOrderHeader;

SELECT COUNT(DISTINCT CustomerID) FROM Sales.SalesOrderHeader
SELECT COUNT(1) FROM Sales.SalesOrderHeader

-- Encontrar los percentiles de los precios de los productos.
SELECT DISTINCT ProductSubcategoryID,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ListPrice) OVER (PARTITION BY ProductSubcategoryID) AS P50,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY ListPrice) OVER (PARTITION BY ProductSubcategoryID) AS P90,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ListPrice) OVER (PARTITION BY ProductSubcategoryID) AS P95,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ListPrice) OVER (PARTITION BY ProductSubcategoryID) AS P99
FROM Production.Product;


-- v2022

-- Buscar registros donde el color haya cambiado, incluso si antes era NULL.
SELECT ProductID, Color 
FROM Production.Product
WHERE Color IS DISTINCT FROM 'Silver';

SELECT ProductID, Color 
FROM Production.Product
WHERE Color <> 'Silver';

-- Supongamos que recibes una lista de IDs de productos como string.
DECLARE @Lista NVARCHAR(MAX) = '707,708,711';
SELECT value AS ProductID, ordinal 
FROM STRING_SPLIT(@Lista, ',', 1) -- El '1' habilita la columna ordinal

-- Comparar fechas de pedido, vencimiento y envío para encontrar la primera y la más tardía.
SELECT SalesOrderID, OrderDate, DueDate, ShipDate,
       LEAST(OrderDate, DueDate, ShipDate) AS PrimerEvento,
       GREATEST(OrderDate, DueDate, ShipDate) AS UltimoEvento
FROM Sales.SalesOrderHeader;

-- Agrupar ventas por el primer día del mes.
SELECT DATETRUNC(month, OrderDate) AS MesVenta, 
       SUM(TotalDue) AS VentasTotales
FROM Sales.SalesOrderHeader
GROUP BY DATETRUNC(month, OrderDate)
ORDER BY MesVenta;

-- Generar la lista de los días del mes para un left join con todos los días
SELECT value AS Dia 
FROM GENERATE_SERIES(1, 31)

SELECT value, año, mes, dia, total
FROM GENERATE_SERIES(1, 31) s LEFT OUTER JOIN (
    SELECT DATETRUNC(DAY, [ShipDate]) fecha, DATEPART(YEAR, DATETRUNC(DAY, [ShipDate])) año, DATEPART(MONTH, DATETRUNC(DAY, [ShipDate])) mes, DATEPART(DAY, DATETRUNC(DAY, [ShipDate])) dia, SUM([TotalDue]) total
    FROM [Sales].[SalesOrderHeader]
    WHERE DATETRUNC(MONTH, [ShipDate]) = '2023-02-01'
    GROUP BY DATETRUNC(DAY, [ShipDate])
    ) p ON s.value = p.dia
ORDER BY value

-- SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled');

-- EXPRESIONES REGULARES

-- Buscar empleados con correos que no cumplen un formato estándar
SELECT EmailAddress
FROM Person.EmailAddress
WHERE NOT REGEXP_LIKE(EmailAddress, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')

-- Extraer solo el dominio de un correo electrónico.
SELECT EmailAddress,
    REGEXP_SUBSTR(EmailAddress, '@[A-Za-z0-9.-]+\.[A-Za-z]{2,}') AS Dominio
FROM Person.EmailAddress

-- Limpiar teléfonos en AdventureWorks dejando solo los dígitos
SELECT 
    PhoneNumber,
    REGEXP_REPLACE(PhoneNumber, '\D', '') AS SoloNumeros
FROM Person.PersonPhone

-- Encontrar dónde empieza el primer número en una dirección para separar el nombre de la calle.
SELECT AddressLine1,
    REGEXP_INSTR(AddressLine1, '\d+') AS PosicionPrimerNumero
FROM Person.Address

-- Saber cuántas palabras tiene una descripción de producto (contando espacios o secuencias de letras).
SELECT Name, REGEXP_COUNT(Name, '\w+') AS NumeroDePalabras
FROM Production.Product

-- Descompone el ProductNumber en sus dos grupos.
SELECT TOP 10 ProductNumber, m.*
FROM Production.Product CROSS APPLY REGEXP_MATCHES(ProductNumber, '^([A-Z]{2})-([0-9]{4})$') m

-- Divide la dirección que tiene múltiples delimitadores.
SELECT TOP 100 AddressLine1, value
FROM Person.Address OUTER APPLY REGEXP_SPLIT_TO_TABLE(AddressLine1, '[;,-.]+')

-- Cortar el nombre de un producto desde el primer guion hasta el final de forma dinámica.
SELECT 
    Name,
    SUBSTRING(Name, REGEXP_INSTR(Name, '-') + 1, LEN(Name)) AS ModeloPostGuion
FROM Production.Product
WHERE Name LIKE '%-%';
