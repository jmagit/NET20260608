using Curso.Models.Entities;
using Curso.Models.Infraestructure;
using Curso.Tools;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Options;
using System.Linq.Expressions;
using System.Text.Json;

namespace curso {
    internal class CursoApp {
        static async Task Main(string[] args) {
            //await ShowModel();
            //await Consultas();
            //await ConsultasDinamicas(predicado: o => o.BusinessEntityId <= 10, Orden: false);
            //await CargaNavegacion();
            //await Pagination();
            //await UsarJson();
            //await Vistas();
            //await FuncionesDefinidasPorUsuario();
            //await ConsultasSqlQuery();
            //await SystemVersioned();
            //await RowLevelSecurity();
            //await Enmasacaramiento();
            //await Modificar();
            //await Transaction();
            await Concurrencia();
        }

        static DbContextOptions<AWContext> AWOptionsNoTracking {
            get {
                return new DbContextOptionsBuilder<AWContext>()
                    .LogTo(Console.WriteLine, new[] { RelationalEventId.CommandExecuted })
                    .UseSqlServer(
                        "Data Source=localhost;Initial Catalog=AdventureWorks2025;User ID=profe;Password=curso;Encrypt=False",
                        o => o.UseCompatibilityLevel(160))
                    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking)
                    .Options;
            }
        }
        static DbContextOptions<AWContext> AWOptionsTracking {
            get {
                return new DbContextOptionsBuilder<AWContext>()
                    .LogTo(Console.WriteLine, new[] { RelationalEventId.CommandExecuted })
                    .UseSqlServer(
                        "Data Source=localhost;Initial Catalog=AdventureWorks2025;User ID=profe;Password=curso;Encrypt=False",
                        o => o.UseCompatibilityLevel(160))
                    .UseQueryTrackingBehavior(QueryTrackingBehavior.TrackAll)
                    .Options;
            }
        }

        static async Task Consultas() {
            var options = new DbContextOptionsBuilder<AWContext>()
                .UseSqlServer("Data Source=.;Initial Catalog=AdventureWorks2025;Persist Security Info=True;User ID=profe;Password=curso;Encrypt=False",
                o => o.UseCompatibilityLevel(160))
                .LogTo(Console.WriteLine, new[] { RelationalEventId.CommandExecuted })
                .Options;
            using(var context = new AWContext(options)) {
                (await context.People.AsNoTracking()
                    .Where(o => o.BusinessEntityId <= 10 && (o.FirstName + " " + o.LastName).Length > 1)
                    .OrderBy(o => o.FirstName)
                    .Select(o => o.FirstName + " " + o.LastName)
                    //.Select(o => $"{o.FirstName} {o.LastName}")
                    .ToListAsync()
                    )
                    .ForEach(Console.WriteLine);
                //.ForEach(o => Console.WriteLine($"Persona: {o.FirstName} {o.LastName}"));
            }
        }

        static async Task ConsultasDinamicas(bool Filtro = true, bool Orden = true, Expression<Func<Person, bool>>? predicado = null) {
            var options = new DbContextOptionsBuilder<AWContext>()
                .UseSqlServer("Data Source=.;Initial Catalog=AdventureWorks2025;Persist Security Info=True;User ID=profe;Password=curso;Encrypt=False",
                o => o.UseCompatibilityLevel(160))
                .LogTo(Console.WriteLine, new[] { RelationalEventId.CommandExecuted })
                .Options;
            using(var context = new AWContext(options)) {
                var query = context.People.AsNoTracking();
                if(predicado == null)
                    query = query.Take(5);
                else
                    query = query.Where(predicado);

                if(Filtro) {
                    query = query.Where(o => (o.FirstName + " " + o.LastName).Length > 1);
                }
                if(Orden) {
                    query = query.OrderBy(o => o.FirstName);
                }
                (await query.Select(o => o.FirstName + " " + o.LastName).ToListAsync()).ForEach(Console.WriteLine);
            }
        }

        //
        //  Mostrar modelo
        //
        static async Task ShowModel() {
            using(var context = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n Vista de depuración (en formato corto)  -----------------------------------------\n ");
                Console.WriteLine(context.Model.ToDebugString());
                Console.WriteLine("\n Vista de depuración (en formato largo)  -----------------------------------------\n ");
                Console.WriteLine(context.Model.ToDebugString(MetadataDebugStringOptions.LongDefault));
            }
        }

        //
        // Carga de propiedades
        //
        static async Task CargaNavegacion() {
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n Carga diligente ----------------------------------------------------------->");
                await dbContext.People
                    .Include(e => e.EmailAddressesNavigation)
                    .Include(e => e.BusinessEntityContacts).ThenInclude(e => e.ContactType)
                    .Where(e => e.BusinessEntityId <= 10)
                    .AsNoTracking().ToListAsync();
                Console.WriteLine("\n SplitQuery ----------------------------------------------------------->");
                await dbContext.People
                    .Include(e => e.EmailAddressesNavigation)
                    .Include(e => e.BusinessEntityContacts).ThenInclude(e => e.ContactType)
                    .Where(e => e.BusinessEntityId <= 10)
                    .AsSplitQuery()
                    .AsNoTracking().ToListAsync();
            }
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n Carga explícita ----------------------------------------------------------->");
                var result = await dbContext.People
                    .Where(e => e.BusinessEntityId <= 3)
                    .AsNoTracking().ToListAsync();
                Console.WriteLine("\n Carga navegación ----------------------------------------------------------->");
                result.ForEach(e => dbContext.Entry(e).Collection(c => c.EmailAddressesNavigation).Load());
                Console.WriteLine("\n Calcula navegación ----------------------------------------------------------->");
                result.ForEach(e => dbContext.Entry(e).Collection(c => c.EmailAddressesNavigation).Query().Count());
            }
        }

        //
        //  Pagination
        //
        static async Task Pagination() {
            var rows = 3;
            Console.WriteLine("\nPagination -----------------------------------------\n ");
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                for(int page = 0; page < 3; page++) {
                    Console.WriteLine($"\nPage {page + 1} -----------------------------------------\n ");
                    (await dbContext.People
                        .AsNoTracking() // <----------------------------
                        .Select(s => s.FirstName + " " + s.LastName)
                        //.Select(s => $"{s.FirstName} {s.LastName}")
                        .OrderBy(s => s)
                        .Skip(page * rows)
                        .Take(rows)
                        .ToListAsync())
                        .ForEach(Console.WriteLine);
                }
            }
        }

        //
        // Estructura híbrida con JSON
        //
        static async Task UsarJson() {
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                var details = await dbContext.Details.FindAsync(1);
                Console.WriteLine("\nDetails -----------------------------------------\n ");
                Console.WriteLine(details.Details.ToPrint());
                details.Details.Addresses.ForEach(a => Console.WriteLine(a.ToPrint()));
                details.Details.PhoneNumbers.ForEach(a => Console.WriteLine(a.ToPrint()));
                details.Details.EmailAddresses.ForEach(Console.WriteLine);
                // Console.WriteLine(JsonSerializer.Serialize(details));
                var pn = details.Details.PhoneNumbers[0];
                details.Details.PhoneNumbers[0] = new PhoneNumberJson() {
                    Type = pn.Type == pn.Type.ToLower() ? pn.Type.ToUpper() : pn.Type.ToLower(),
                    Number = pn.Number
                };
                details.Details.EmailAddresses.Add($"ken0{details.Details.EmailAddresses.Count + 1}@adventure-works.com");
                await dbContext.SaveChangesAsync();
            }
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\nUpdated -----------------------------------------\n ");
                Console.WriteLine(JsonSerializer.Serialize(await dbContext.Details.FindAsync(1)));
            }
        }

        //
        // No solo tablas
        //
        static async Task Vistas() {
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n Vistas ----------------------------------------------------------->");
                (await dbContext.VEmployees.AsNoTracking().Take(10).ToListAsync())
                    .ForEach(o => Console.WriteLine(o.ToPrint()));
            }
        }
        static async Task FuncionesDefinidasPorUsuario() {
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n SEGUIMIENTO DE CAMBIOS (CHANGE TRACKING - CT) ----------------------------------------------------------->");
                (await dbContext.ufnSalesOrderHeaderChanges(2).AsNoTracking().ToListAsync())
                    .ForEach(o => Console.WriteLine(o.ToPrint()));
            }
        }


        //
        // Consultas SQL 
        //
        record Persona(int id, string nombre, string apellidos);
        static async Task ConsultasSqlQuery() {
            using(var dbContext = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\nEscalar -----------------------------------------\n ");
                var ids = await dbContext.Database.SqlQuery<int>($"""
                SELECT BusinessEntityID FROM Person.Person
                """).ToListAsync();
                Console.WriteLine("\ncount: " + ids.Count);
                Console.WriteLine("\nDTOS -----------------------------------------\n ");
                var list = await dbContext.Database.SqlQuery<Persona>($"""
               SELECT TOP 10 BusinessEntityID AS id, FirstName AS Nombre, LastName AS Apellidos
                    FROM Person.Person
            """).ToListAsync();
                list.ForEach(Console.WriteLine);
                Console.WriteLine("\nFOR JSON -----------------------------------------\n ");
                var cad = await dbContext.Database.SqlQuery<string>($"""
                SELECT (
                    SELECT TOP 10
                        BusinessEntityID AS[ID],
                        FirstName AS[Info.Nombre],
                        LastName AS 'Info.Apellidos'
                    FROM Person.Person
                    FOR JSON PATH, ROOT('Usuarios')
                ) Value
            """).SingleAsync();
                Console.WriteLine("\njson:\n " + cad);

                var details = await dbContext.Details.FindAsync(1);
                Console.WriteLine(JsonSerializer.Serialize(details));
            }
        }

        //
        // Tablas temporales con control de versiones
        //
        static async Task SystemVersioned() {
            using(var context = new AWContext(AWOptionsNoTracking)) {
                Console.WriteLine("\n TemporalAll ----------------------------------------------------------->");
                (await context.People.TemporalAll().Where(p => p.BusinessEntityId == 1).ToListAsync())
                    .ForEach(o => Console.WriteLine($"\n Persona: {o.FirstName} {o.MiddleName} {o.LastName}"));
                Console.WriteLine("\n TemporalAsOf 2026-01-01 ----------------------------------------------->");
                (await context.People.TemporalAsOf(new DateTime(2026, 01, 01)).Where(p => p.BusinessEntityId == 1).ToListAsync())
                    .ForEach(o => Console.WriteLine($"\n Persona: {o.FirstName} {o.MiddleName} {o.LastName}"));
                Console.WriteLine("\n Actual ---------------------------------------------------------------->");
                (await context.People.Where(p => p.BusinessEntityId == 1).ToListAsync())
                    .ForEach(o => Console.WriteLine($"\n Persona: {o.FirstName} {o.MiddleName} {o.LastName}"));
            }
        }

        // 
        // SEGURIDAD
        //
        static async Task RowLevelSecurity() {
            var fn = async (String user, String password) => {
                var connectionString = $"Data Source=.;Initial Catalog=AdventureWorks2025;Persist Security Info=True;User ID={user};Password={password};Encrypt=False";
                var options = new DbContextOptionsBuilder<AWContext>()
                    .UseSqlServer(connectionString)
                    //.LogTo(Console.WriteLine, LogLevel.Information)
                    .LogTo(Console.WriteLine, new[] { RelationalEventId.CommandExecuted })
                    .EnableSensitiveDataLogging(true)
                    .Options;
                Console.WriteLine($"Usuario {user} -------------------");
                using(var dbContext = new AWContext(options)) {
                    //Console.WriteLine(dbContext.Model.ToDebugString());
                    (dbContext.Notificaciones.AsNoTracking()
                        .ToList())
                        .ForEach(item => Console.WriteLine(item.ToPrint()));
                }
                Console.WriteLine("-------------------");
            };
            await fn("demo", "demo");
            await fn("profe", "curso");
        }

        static async Task Enmasacaramiento() {
            var fn = async (String user, String password) => {
                var connectionString = $"Data Source=.;Initial Catalog=AdventureWorks2025;Persist Security Info=True;User ID={user};Password={password};Encrypt=False";
                var options = new DbContextOptionsBuilder<AWContext>()
                    .UseSqlServer(connectionString)
                    .Options;
                Console.WriteLine($"Usuario {user} -------------------");
                using(var dbContext = new AWContext(options)) {
                    (dbContext.Enmascarados.AsNoTracking()
                        .ToList())
                        .ForEach(item => Console.WriteLine(JsonSerializer.Serialize(item)));
                }
                Console.WriteLine("-------------------");
            };
            await fn("demo", "demo");
            await fn("profe", "curso");
        }

        // 
        // PERSISTENCIA
        //

        static async Task Modificar() {
            using(var dbContext = new AWContext(AWOptionsTracking)) {
                var person = await dbContext.People.FindAsync(1);
                try {
                    // 1	EM	0	NULL	KEN	J	SÁNCHEZ	NULL	0	NULL	<IndividualSurvey xmlns="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"><TotalPurchaseYTD>0</TotalPurchaseYTD></IndividualSurvey>	92C4279F-1207-48A3-8448-4636514EB7E2	2020-01-07 00:00:00.000	[{"number":"697-555-0142","tipo":"HOME"},null]	["ken0@adventure-works.com"]	697-555-0142	2026-06-15 14:18:22.0258965	9999-12-31 23:59:59.9999999
                    person.FirstName = "KEN";
                    person.MiddleName = "J";
                    person.LastName = "SÁNCHEZ";
                    person.LastName = "12345678Z";
                    person.Suffix = null;
                    person.EmailAddresses = "ken0adventure-works.com";
                    person.EmailAddresses = "ken0@adventure-works.com";
                    person.ModifiedDate = DateTime.Now;
                    if(person.IsInvalid()) {
                        Console.WriteLine("Validacion --------------------------------->");
                        person.Validate().ToList().ForEach(Console.WriteLine);
                    } else
                        await dbContext.SaveChangesAsync();
                } catch(DbUpdateConcurrencyException ex) {
                    Console.WriteLine(ex.Message);
                }
            }
        }

        static async Task Transaction() {
            using var dbContext = new AWContext(AWOptionsTracking);
            await using var transaction = await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Snapshot);
            try {
                (await dbContext.EmailAddresses.OrderBy(e => e.EmailAddressId).Take(5).ToListAsync())
                        .ForEach(e => e.EmailAddress1 = e.EmailAddress1.ToUpper());
                Console.WriteLine("\n-----------> SaveChangesAsync");
                await dbContext.SaveChangesAsync();
                Console.WriteLine("\n-----------> SaveChanges OK");
                dbContext.People.Remove(await dbContext.People.FindAsync(999));
                Console.WriteLine("\n-----------> SaveChangesAsync");
                await dbContext.SaveChangesAsync();
                await transaction.CommitAsync();
                Console.WriteLine("\n-----------> COMMIT");
            } catch(Exception ex) {
                Console.WriteLine("\n" + ex.ToString());
                await transaction.RollbackAsync();
                Console.WriteLine("\n-----------> ROLLBACK");
            }
        }

        static async Task Concurrencia() {
            using(var dbContext = new AWContext(AWOptionsTracking)) {
                try {
                    var notificacion = await dbContext.Notificaciones.FindAsync(1);
                    Console.WriteLine($"\nLEÍDO: {notificacion.ToPrint()}\n");
                    try {
                        await dbContext.Notificaciones.Where(e => e.Id == 1)
                            .ExecuteUpdateAsync(setters => setters
                                .SetProperty(b => b.Mensaje, "Hola")
                                .SetProperty(b => b.Leido, b => !b.Leido)
                            );
                        notificacion.Mensaje = notificacion.Mensaje + "x";
                        dbContext.SaveChanges();
                        Console.WriteLine($"\nGUARDADO: {notificacion.ToPrint()}\n");
                    } catch(DbUpdateConcurrencyException ex) {
                        foreach(var entry in ex.Entries) {
                            if(entry.Entity is Notificacione) {
                                var original = entry.OriginalValues;
                                var proposed = entry.CurrentValues;
                                var database = await entry.GetDatabaseValuesAsync();
                                foreach(var property in proposed.Properties.Where(p => !p.IsConcurrencyToken)) {
                                    if(!Object.Equals(original[property], proposed[property]) &&
                                        !Object.Equals(original[property], database[property]) &&
                                        !Object.Equals(database[property], proposed[property]))
                                        throw new NotSupportedException("No se puede resolver automáticamente.");
                                    if(Object.Equals(original[property], proposed[property]) &&
                                        !Object.Equals(original[property], database[property]))
                                        proposed[property] = database[property];
                                }
                                entry.OriginalValues.SetValues(database);
                                dbContext.SaveChanges();
                                Console.WriteLine($"\nGUARDADO: {notificacion.ToPrint()}\n");
                            } else {
                                throw new NotSupportedException(
                                    "Don't know how to handle concurrency conflicts for "
                                    + entry.Metadata.Name);
                            }
                        }
                    }
                } catch(Exception ex) {
                    Console.WriteLine("\n" + ex.ToString());
                }
            }
        }

    }
}
