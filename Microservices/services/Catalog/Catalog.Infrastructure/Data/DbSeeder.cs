using Catalog.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Catalog.Infrastructure.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(CatalogDbContext context)
    {
        await context.Database.MigrateAsync();

        if (await context.Categories.AnyAsync())
        {
            return;
        }

        var categories = new List<Category>
        {
            new Category
            {
                Id = Guid.NewGuid(),
                Name = "Electronics",
                Description = "Electronic devices and gadgets",
                CreatedAt = DateTime.UtcNow
            },
            new Category
            {
                Id = Guid.NewGuid(),
                Name = "Books",
                Description = "Books and publications",
                CreatedAt = DateTime.UtcNow
            },
            new Category
            {
                Id = Guid.NewGuid(),
                Name = "Clothing",
                Description = "Fashion and apparel",
                CreatedAt = DateTime.UtcNow
            }
        };

        await context.Categories.AddRangeAsync(categories);
        await context.SaveChangesAsync();

        var products = new List<Product>
        {
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Laptop",
                Description = "High-performance laptop for professionals",
                Price = 1299.99m,
                StockQuantity = 50,
                CategoryId = categories[0].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Smartphone",
                Description = "Latest model smartphone with advanced features",
                Price = 899.99m,
                StockQuantity = 100,
                CategoryId = categories[0].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Wireless Headphones",
                Description = "Noise-cancelling wireless headphones",
                Price = 249.99m,
                StockQuantity = 75,
                CategoryId = categories[0].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Clean Code",
                Description = "A Handbook of Agile Software Craftsmanship",
                Price = 39.99m,
                StockQuantity = 200,
                CategoryId = categories[1].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Domain-Driven Design",
                Description = "Tackling Complexity in the Heart of Software",
                Price = 49.99m,
                StockQuantity = 150,
                CategoryId = categories[1].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "T-Shirt",
                Description = "Comfortable cotton t-shirt",
                Price = 19.99m,
                StockQuantity = 300,
                CategoryId = categories[2].Id,
                CreatedAt = DateTime.UtcNow
            },
            new Product
            {
                Id = Guid.NewGuid(),
                Name = "Jeans",
                Description = "Classic denim jeans",
                Price = 59.99m,
                StockQuantity = 150,
                CategoryId = categories[2].Id,
                CreatedAt = DateTime.UtcNow
            }
        };

        await context.Products.AddRangeAsync(products);
        await context.SaveChangesAsync();
    }
}
