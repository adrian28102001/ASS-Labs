using Microsoft.EntityFrameworkCore;

namespace Orders.Infrastructure.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(OrdersDbContext context)
    {
        await context.Database.MigrateAsync();

        // Orders service doesn't need seed data - orders will be created by users
    }
}
