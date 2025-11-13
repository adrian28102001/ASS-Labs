# E-commerce Application - .NET 9 with Onion Architecture

A clean, maintainable e-commerce MVP built with .NET 9, following Onion Architecture principles and Clean Code practices.

## Architecture

This application follows **Onion Architecture** with clear separation of concerns:

```
├── Domain          # Core entities and interfaces (innermost layer)
├── Application     # Business logic, DTOs, service interfaces
├── Infrastructure  # Data access, EF Core, external services
└── API            # Controllers, configuration, entry point
```

### Key Design Principles

- **Dependency Inversion**: Inner layers define interfaces, outer layers implement them
- **Clean Separation**: Each layer has a single, well-defined responsibility
- **Domain-Centric**: Business logic lives in the core, independent of frameworks

## Features

- **Authentication**: JWT-based authentication with role-based authorization
- **Products Management**: Full CRUD operations (Admin only for create/update/delete)
- **Categories Management**: CRUD operations for product categories
- **Order Processing**: Customers can place orders with automatic stock management
- **API Documentation**: Swagger/OpenAPI for easy testing

## Technology Stack

- **.NET 9**: Latest .NET framework
- **Entity Framework Core 9**: ORM with Code-First approach
- **PostgreSQL**: Relational database
- **JWT**: Authentication and authorization
- **Swagger**: API documentation and testing
- **Docker**: Containerization for easy deployment

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your machine

### Running the Application

1. **Clone or navigate to the project directory**

2. **Start the application**:
   ```bash
   docker compose up -d
   ```

3. **Access the API**:
   - API URL: `http://localhost:5000`
   - Swagger UI: `http://localhost:5000/swagger`

4. **Stop the application**:
   ```bash
   docker compose down
   ```

### Default Credentials

The application automatically seeds sample data on startup:

**Admin Account**:
- Email: `admin@ecommerce.com`
- Password: `Admin123!`
- Role: Admin (can manage products and categories)

**Customer Account**:
- Email: `customer@example.com`
- Password: `Customer123!`
- Role: Customer (can browse and order products)

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login and receive JWT token

### Categories

- `GET /api/categories` - Get all categories
- `GET /api/categories/{id}` - Get category by ID
- `POST /api/categories` - Create category (Admin only)
- `DELETE /api/categories/{id}` - Delete category (Admin only)

### Products

- `GET /api/products` - Get all products
- `GET /api/products/{id}` - Get product by ID
- `POST /api/products` - Create product (Admin only)
- `PUT /api/products/{id}` - Update product (Admin only)
- `DELETE /api/products/{id}` - Delete product (Admin only)

### Orders

- `POST /api/orders` - Create an order (Authenticated users)
- `GET /api/orders` - Get user's orders (Authenticated users)
- `GET /api/orders/{id}` - Get specific order (Authenticated users)

## Sample Data

The application seeds the following sample data:

### Categories
- Electronics
- Books
- Clothing

### Products
- Laptop ($1,299.99)
- Smartphone ($899.99)
- Wireless Headphones ($249.99)
- Clean Code book ($39.99)
- Domain-Driven Design book ($49.99)
- T-Shirt ($19.99)
- Jeans ($59.99)

## Testing the API with Swagger

1. Navigate to `http://localhost:5000/swagger`
2. Click **Authorize** button
3. Login using one of the default accounts:
   - Use `POST /api/auth/login` endpoint
   - Copy the `token` from the response
4. Enter the token in the format: `Bearer {your-token}`
5. Now you can test all authenticated endpoints

## Example API Usage

### 1. Login
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "customer@example.com",
    "password": "Customer123!"
  }'
```

### 2. Get All Products
```bash
curl -X GET http://localhost:5000/api/products
```

### 3. Create an Order (requires authentication)
```bash
curl -X POST http://localhost:5000/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {your-token}" \
  -d '{
    "items": [
      {
        "productId": "{product-guid}",
        "quantity": 2
      }
    ]
  }'
```

## Project Structure

```
EcommerceApp/
├── src/
│   ├── EcommerceApp.Domain/
│   │   ├── Entities/              # Core business entities
│   │   │   ├── BaseEntity.cs
│   │   │   ├── User.cs
│   │   │   ├── Product.cs
│   │   │   ├── Category.cs
│   │   │   ├── Order.cs
│   │   │   └── OrderItem.cs
│   │   └── Interfaces/            # Repository contracts
│   │       └── IRepository.cs
│   │
│   ├── EcommerceApp.Application/
│   │   ├── DTOs/                  # Data Transfer Objects
│   │   │   ├── Auth/
│   │   │   ├── Products/
│   │   │   ├── Categories/
│   │   │   └── Orders/
│   │   ├── Interfaces/            # Service contracts
│   │   │   ├── IAuthService.cs
│   │   │   ├── IProductService.cs
│   │   │   ├── ICategoryService.cs
│   │   │   ├── IOrderService.cs
│   │   │   └── IJwtTokenGenerator.cs
│   │   └── Services/              # Business logic implementation
│   │       ├── AuthService.cs
│   │       ├── ProductService.cs
│   │       ├── CategoryService.cs
│   │       └── OrderService.cs
│   │
│   ├── EcommerceApp.Infrastructure/
│   │   ├── Data/                  # Database context and seeding
│   │   │   ├── AppDbContext.cs
│   │   │   └── DbSeeder.cs
│   │   ├── Repositories/          # Repository implementations
│   │   │   └── Repository.cs
│   │   └── Services/              # External service implementations
│   │       └── JwtTokenGenerator.cs
│   │
│   └── EcommerceApp.API/
│       ├── Controllers/           # API endpoints
│       │   ├── AuthController.cs
│       │   ├── ProductsController.cs
│       │   ├── CategoriesController.cs
│       │   └── OrdersController.cs
│       ├── Program.cs             # Application entry point
│       └── appsettings.json       # Configuration
│
├── Dockerfile                     # Container definition
├── docker-compose.yml             # Multi-container setup
└── README.md
```

## Development

### Running without Docker

If you prefer to run the application locally:

1. Install .NET 9 SDK
2. Install PostgreSQL
3. Update the connection string in `appsettings.json`
4. Run migrations:
   ```bash
   cd src/EcommerceApp.API
   dotnet ef database update
   ```
5. Run the application:
   ```bash
   dotnet run
   ```

### Database Migrations

To create a new migration:
```bash
cd src/EcommerceApp.API
dotnet ef migrations add MigrationName --project ../EcommerceApp.Infrastructure
```

## Security Notes

- The JWT secret in the configuration is for development only
- In production, use environment variables and secure secret management
- Passwords are hashed using BCrypt
- API uses HTTPS in production (configure in production environment)

## License

This is a sample project for educational purposes.
