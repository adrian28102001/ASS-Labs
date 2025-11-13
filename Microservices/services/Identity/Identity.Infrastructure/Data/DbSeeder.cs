using Identity.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Identity.Infrastructure.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(IdentityDbContext context)
    {
        await context.Database.MigrateAsync();

        if (await context.Users.AnyAsync())
        {
            return;
        }

        var users = new List<User>
        {
            new User
            {
                Id = Guid.NewGuid(),
                Email = "admin@ecommerce.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin123!"),
                FirstName = "Admin",
                LastName = "User",
                Role = "Admin",
                CreatedAt = DateTime.UtcNow
            },
            new User
            {
                Id = Guid.NewGuid(),
                Email = "customer@example.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Customer123!"),
                FirstName = "John",
                LastName = "Doe",
                Role = "Customer",
                CreatedAt = DateTime.UtcNow
            }
        };

        await context.Users.AddRangeAsync(users);
        await context.SaveChangesAsync();
    }
}
