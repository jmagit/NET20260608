using Demos.Models.Infraestructure;
using Microsoft.EntityFrameworkCore;

namespace Demos {
    internal class Program {
        static async Task Main(string[] args) {
            await Consultas();
        }

        static async Task Consultas() {
            var options = new DbContextOptionsBuilder<AWContext>()
                .UseSqlServer("Data Source=.;Initial Catalog=AdventureWorks2025;Persist Security Info=True;User ID=profe;Password=curso;Encrypt=False", 
                o => o.UseCompatibilityLevel(160))
                .LogTo(Console.WriteLine)
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

    }
}
