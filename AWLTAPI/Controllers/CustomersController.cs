using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using AWLTAPI.Models;

[Route("api/[controller]")]
[ApiController]
public class CustomersController : ControllerBase
{
    private readonly AWLTContext _context;
    public CustomersController(AWLTContext context)
    {
        _context = context;
    }

    // GET: api/Customer
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Customer>>> GetCustomer()
    {
        return await _context.Customers.ToListAsync();
    }

    // GET: api/Customer/json
    [HttpGet("json")]
    public async Task<ActionResult<string>> GetCustomerJson(int page = 0, int rows = 20) {
        return Content(await _context.Database.SqlQuery<string>($"""
                SELECT (
                    SELECT CustomerID id
                          ,FirstName nombre
                          ,LastName apellidos
                          ,EmailAddress [contacto.email]
                          ,Phone [contacto.telefono]
                    FROM SalesLT.Customer
                    ORDER BY CustomerID OFFSET {page * rows} ROWS FETCH NEXT {rows} ROWS ONLY
                    FOR JSON PATH
                ) Value
            """).SingleAsync(), "application/json");
    }
    // GET: api/Customer/5
    [HttpGet("{customerid}")]
    public async Task<ActionResult<Customer>> GetCustomer(int customerid)
    {
        var customer = await _context.Customers.FindAsync(customerid);

        if (customer == null)
        {
            return NotFound();
        }

        return customer;
    }

    // PUT: api/Customer/5
    // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
    [HttpPut("{customerid}")]
    public async Task<IActionResult> PutCustomer(int? customerid, Customer customer)
    {
        if (customerid != customer.CustomerId)
        {
            return BadRequest();
        }

        _context.Entry(customer).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!CustomerExists(customerid))
            {
                return NotFound();
            }
            else
            {
                throw;
            }
        }

        return NoContent();
    }

    // POST: api/Customer
    // To protect from overposting attacks, see https://go.microsoft.com/fwlink/?linkid=2123754
    [HttpPost]
    public async Task<ActionResult<Customer>> PostCustomer(Customer customer)
    {
        _context.Customers.Add(customer);
        await _context.SaveChangesAsync();

        return CreatedAtAction("GetCustomer", new { customerid = customer.CustomerId }, customer);
    }

    // DELETE: api/Customer/5
    [HttpDelete("{customerid}")]
    public async Task<IActionResult> DeleteCustomer(int? customerid)
    {
        var customer = await _context.Customers.FindAsync(customerid);
        if (customer == null)
        {
            return NotFound();
        }

        _context.Customers.Remove(customer);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool CustomerExists(int? customerid)
    {
        return _context.Customers.Any(e => e.CustomerId == customerid);
    }
}
