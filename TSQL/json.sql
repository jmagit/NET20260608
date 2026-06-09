/* Limpieza de ejecuciones anteriores
DROP INDEX IF EXISTS IX_Person_JSON ON Person.Person
GO
DROP FUNCTION IF EXISTS dbo.ufnToRawJsonArray
GO
ALTER TABLE Person.Person DROP
	CONSTRAINT IF EXISTS [Phone numbers must be formatted as JSON array],
	COLUMN IF EXISTS PhoneNumbers,
	CONSTRAINT IF EXISTS [Email addresses must be formatted as JSON array],
	COLUMN IF EXISTS EmailAddresses
	COLUMN IF EXISTS Phone
GO
*/

--- Creación de columnas JSON
ALTER TABLE Person.Person ADD
	PhoneNumbers nvarchar(MAX) NULL
		CONSTRAINT [Phone numbers must be formatted as JSON array]
		CHECK (ISJSON(PhoneNumbers, ARRAY)>0),
	EmailAddresses nvarchar(MAX) NULL
		CONSTRAINT [Email addresses must be formatted as JSON array]
		CHECK (ISJSON(EmailAddresses, ARRAY)>0)
GO
CREATE FUNCTION
dbo.ufnToRawJsonArray(@json nvarchar(max), @key nvarchar(400)) returns nvarchar(max)
as begin
	return replace(replace(@json, FORMATMESSAGE('{"%s":', @key),''), '}','')
end
GO
SELECT TOP 10 Person.PersonPhone.PhoneNumber number, Person.PhoneNumberType.Name AS [type]
FROM  Person.PersonPhone
	INNER JOIN Person.PhoneNumberType ON Person.PersonPhone.PhoneNumberTypeID = Person.PhoneNumberType.PhoneNumberTypeID
FOR JSON PATH
GO
UPDATE Person.Person
SET PhoneNumbers = (SELECT Person.PersonPhone.PhoneNumber number, Person.PhoneNumberType.Name AS [type]
					FROM  Person.PersonPhone
						INNER JOIN Person.PhoneNumberType ON Person.PersonPhone.PhoneNumberTypeID = Person.PhoneNumberType.PhoneNumberTypeID
					WHERE Person.Person.BusinessEntityID = Person.PersonPhone.BusinessEntityID
					FOR JSON PATH),
    EmailAddresses = dbo.ufnToRawJsonArray(
					(SELECT Person.EmailAddress.EmailAddress
						FROM Person.EmailAddress
						WHERE Person.Person.BusinessEntityID = Person.EmailAddress.BusinessEntityID
						FOR JSON PATH)
					, 'EmailAddress')
GO
SELECT TOP 10 *
FROM Person.Person
GO

-- JSON PATH
SELECT TOP 10
    BusinessEntityID AS [ID],
    FirstName AS [Info.Nombre],
    LastName AS 'Info.Apellidos'
FROM Person.Person
FOR JSON PATH, ROOT('Usuarios');
GO
-- Extracción de valores
SELECT TOP 10 BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre
FROM Person.Person
WHERE JSON_PATH_EXISTS(PhoneNumbers, '$[*].type') > 0
GO
SELECT TOP 10 BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre, 
	JSON_VALUE(PhoneNumbers, '$[0].type') + ': ' + JSON_VALUE(PhoneNumbers, '$[0].number') telefono
FROM Person.Person
GO
SELECT TOP 10 BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre, 
	JSON_QUERY(PhoneNumbers, '$[0]') telefono
FROM Person.Person
GO

-- Crear objetos JSON
SELECT TOP 10 JSON_OBJECT(
	'numero': p.PhoneNumber, 
	'tipo': t.Name
	) as telefono
FROM  Person.PersonPhone p
	INNER JOIN Person.PhoneNumberType t ON 
		p.PhoneNumberTypeID = t.PhoneNumberTypeID
GO
SELECT TOP 10 BusinessEntityID, JSON_OBJECTAGG(t.Name: p.PhoneNumber) as numero
FROM  Person.PersonPhone p
	INNER JOIN Person.PhoneNumberType t ON 
		p.PhoneNumberTypeID = t.PhoneNumberTypeID
GROUP BY p.BusinessEntityID;
GO

-- Crear arrays JSON
SELECT TOP 10 FirstName AS nombre, 
	JSON_ARRAYAGG(JSON_OBJECT(
	'id': BusinessEntityID, 'apellidos': LastName
	)) ids
FROM Person.Person
GROUP BY FirstName
GO

-- OPENJSON
DECLARE @json NVARCHAR(MAX) = '[{"Id":1, "Cant":10, "PVP": 10}, {"Id":2, "Cant":5, "PVP": 2}, {"Id":3, "Cant":1, "PVP": 15}]';

SELECT id, cantidad, precio, cantidad * precio total
FROM OPENJSON(@json) WITH (
    Id INT '$.Id',
    Cantidad INT '$.Cant',
    Precio SMALLMONEY '$.PVP'
);
GO
SELECT TOP 10 BusinessEntityID AS id, FirstName + ' ' + LastName AS nombre, tipo, numero telefono
FROM Person.Person p /* OUTER */ CROSS APPLY OPENJSON(p.PhoneNumbers) WITH (
    numero NVARCHAR(25) '$.number',
    tipo NVARCHAR(50) '$.type'
);
GO
UPDATE Person.Person
SET PhoneNumbers = null
WHERE BusinessEntityID = 10
GO

-- Cambiar valores de JSON
SELECT PhoneNumbers FROM Person.Person WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, '$[0].type', 'Home')
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, '$[0].type', UPPER(JSON_VALUE(PhoneNumbers, '$[0].type')))
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, '$[0].ext', '0')
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, '$[0].ext', null)
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(JSON_MODIFY(PhoneNumbers, '$[0].tipo', JSON_VALUE(PhoneNumbers, '$[0].type')), '$[0].type', null)
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(JSON_MODIFY(PhoneNumbers, '$[0].type', 'Home'), '$[0].number', '555 666 777')
WHERE BusinessEntityID = 3
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, 'append $', JSON_OBJECT('Number':'666-555-0175','type':'Cell'))
WHERE BusinessEntityID = 1
GO
UPDATE Person.Person
SET PhoneNumbers = JSON_MODIFY(PhoneNumbers, '$[1]', null)
WHERE BusinessEntityID = 1
GO

SELECT TOP 10 PhoneNumbers
FROM Person.Person

SELECT TOP 10 *
FROM Person.Person

-- Columnas calculadas e indices
ALTER TABLE Person.Person ADD
	Phone  AS JSON_VALUE(PhoneNumbers, '$[0].number') -- PERSISTED 
GO
CREATE NONCLUSTERED INDEX IX_Person_JSON 
	ON Person.Person(Phone) 
GO
SELECT TOP 10 Phone FROM Person.Person
SELECT PhoneNumbers FROM Person.Person WHERE Phone LIKE '612%'


-- Consulta típica en AdventureWorks2022 para extraer detalles variables
SELECT 
    p.ProductID,
    p.ProductNumber,
    p.Name AS Producto,
    p.ListPrice AS Precio,
    pm.Name AS Modelo,
    pmx.CultureID,
    pd.Description AS DescripcionTecnica
FROM Production.Product p
INNER JOIN Production.ProductModel pm ON p.ProductModelID = pm.ProductModelID
INNER JOIN Production.ProductModelProductDescriptionCulture pmx ON pm.ProductModelID = pmx.ProductModelID
INNER JOIN Production.ProductDescription pd ON pmx.ProductDescriptionID = pd.ProductDescriptionID
--WHERE pmx.CultureID = 'en'
order by p.ProductID,p.ProductNumber

-- 1. Creación de la tabla híbrida basada en texto plano estructurado
CREATE TABLE Production.ProductSpecs (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductNumber NVARCHAR(25) NOT NULL UNIQUE,
    Name NVARCHAR(50) NOT NULL,
    ListPrice DECIMAL(18,2) NOT NULL,
    
    -- Almacenamiento tradicional en texto claro
    SpecsJson NVARCHAR(MAX) NULL,
    -- Extraer el ProductModel del documento JSON a una columna virtual persistida en disco
    ProductModel AS CAST(JSON_VALUE(SpecsJson, '$.name') AS NVARCHAR(50)) PERSISTED,

    -- Restricción de Integridad (Garantiza que solo entren strings con formato JSON válido)
    CONSTRAINT CK_ProductSpecs_ValidJSON 
    CHECK (ISJSON(SpecsJson) > 0)
);
GO

-- 2. Crear un índice sobre la columna computada
CREATE NONCLUSTERED INDEX IX_ProductSpecs_ProductModel
ON Production.ProductSpecs (ProductModel)
INCLUDE (ProductNumber, Name, ListPrice);
GO

-- 3. Traspasar datos
SET IDENTITY_INSERT Production.ProductSpecs ON
INSERT INTO Production.ProductSpecs(ProductID,ProductNumber,Name,ListPrice,SpecsJson)
SELECT p.ProductID, p.ProductNumber, p.Name, p.ListPrice,
    TRIM('[]' FROM (
        SELECT name, (SELECT TRIM(pmx.CultureID) cultureId, pd.Description AS text
            FROM Production.ProductModelProductDescriptionCulture pmx 
                INNER JOIN Production.ProductDescription pd ON pmx.ProductDescriptionID = pd.ProductDescriptionID
            WHERE pm.ProductModelID = pmx.ProductModelID
            FOR JSON PATH 
            ) description
        FROM Production.ProductModel pm
        WHERE pm.ProductModelID = p.ProductModelID
        FOR JSON PATH
     )) AS SpecsJson
FROM Production.Product p
SET IDENTITY_INSERT Production.ProductSpecs OFF

SELECT * FROM Production.ProductSpecs where ProductModel is not null

delete FROM Production.ProductSpecs;

DROP INDEX IF EXISTS Production.ProductSpecs.IX_ProductSpecs_ProductModel
DROP TABLE IF EXISTS Production.ProductSpecs

--
DROP TABLE IF EXISTS Person.Details
GO
CREATE TABLE Person.Details (
    BusinessEntityID INT PRIMARY KEY,
    Details NVARCHAR(MAX) NULL,
    CONSTRAINT CK_Details_ValidJSON 
    CHECK (ISJSON(Details) > 0)
);
GO

INSERT INTO Person.Details
SELECT id, '{ "ContactType": ' + IIF(ContactType IS NULL, 'null', '"' + ContactType + '"') + 
    ', "Addresses": ' + ISNULL(Addresses, 'null') +
    ', "PhoneNumbers": ' + ISNULL(PhoneNumbers, 'null') +
    ', "EmailAddresses": ' + ISNULL(EmailAddresses, 'null') + ' }' Details
FROM (
SELECT p.BusinessEntityID id, (SELECT MAX(ct.Name)
        FROM Person.BusinessEntityContact AS c INNER JOIN
             Person.ContactType AS ct ON c.ContactTypeID = ct.ContactTypeID
	    WHERE c.BusinessEntityID = p.BusinessEntityID
    ) ContactType,
    (
        SELECT t.Name AS Type, a.AddressLine1, a.AddressLine2, a.City, a.PostalCode, sp.Name AS StateProvince
        FROM Person.BusinessEntityAddress AS b LEFT JOIN
             Person.AddressType AS t ON b.AddressTypeID = t.AddressTypeID LEFT JOIN
             Person.Address AS a ON b.AddressID = a.AddressID LEFT JOIN
             Person.StateProvince AS sp ON a.StateProvinceID = sp.StateProvinceID
        WHERE b.BusinessEntityID = p.BusinessEntityID
        FOR JSON PATH
    ) Addresses,
    (
        SELECT pnt.Name AS Type, pn.PhoneNumber as Number
        FROM Person.PersonPhone AS pn LEFT OUTER JOIN
             Person.PhoneNumberType AS pnt ON pn.PhoneNumberTypeID = pnt.PhoneNumberTypeID
        WHERE pn.BusinessEntityID = p.BusinessEntityID
        FOR JSON PATH
    ) PhoneNumbers,
    dbo.ufnToRawJsonArray(
	    (SELECT ea.EmailAddress
		    FROM Person.EmailAddress ea
		    WHERE ea.BusinessEntityID = p.BusinessEntityID
		    FOR JSON PATH)
	    , 'EmailAddress') EmailAddresses
FROM [Person].[BusinessEntity] p
) f

SELECT TOP 10 *
FROM Person.Details

SELECT JSON_VALUE(Details, '$.ContactType') ContactType, JSON_QUERY(Details, '$.Addresses') Addresses
FROM Person.Details
WHERE JSON_VALUE(Details, '$.ContactType') IS NOT NULL
--WHERE JSON_QUERY(Details, '$.Addresses[1]') IS NOT NULL

SELECT BusinessEntityID, COUNT(1)
FROM Person.Details OUTER APPLY OPENJSON(Details, '$.Addresses') d
GROUP BY BusinessEntityID
HAVING COUNT(1) > 1




