# E-commerce Microservices - .NET 9 with Onion Architecture

A scalable e-commerce application built with .NET 9 using Microservices Architecture, where each service follows Onion Architecture principles and Clean Code practices.

## Architecture

This application follows **Microservices Architecture** with the following services:

```
├── API Gateway (YARP)      # Entry point for all client requests
├── Identity Service        # User authentication and JWT token management
├── Catalog Service         # Product and category management
└── Orders Service          # Order processing and management
```

### Service Architecture

Each microservice follows **Onion Architecture** internally:

```
Service/
├── Domain          # Core entities and interfaces
├── Application     # Business logic, DTOs, service interfaces
├── Infrastructure  # Data access, EF Core, external services
└── API            # Controllers, configuration, entry point
```

### Key Design Principles

- **Service Independence**: Each service has its own database (one database per service)
- **API Gateway Pattern**: Single entry point using YARP reverse proxy
- **Onion Architecture**: Each service maintains clean separation of concerns
- **RESTful Communication**: Services communicate over REST APIs
- **Shared Authentication**: JWT tokens shared across services

## Services

### Identity Service
- **Port**: 5001
- **Database**: identity-db (PostgreSQL)
- **Responsibilities**:
  - User registration and authentication
  - JWT token generation
  - User management

### Catalog Service
- **Port**: 5002
- **Database**: catalog-db (PostgreSQL)
- **Responsibilities**:
  - Product CRUD operations
  - Category management
  - Product inventory

### Orders Service
- **Port**: 5003
- **Database**: orders-db (PostgreSQL)
- **Responsibilities**:
  - Order creation
  - Order history
  - Order status management

### API Gateway
- **Port**: 5000
- **Technology**: YARP (Yet Another Reverse Proxy)
- **Routes**:
  - `/api/auth/*` → Identity Service
  - `/api/products/*` → Catalog Service
  - `/api/categories/*` → Catalog Service
  - `/api/orders/*` → Orders Service

## Technology Stack

- **.NET 9**: Latest .NET framework
- **Entity Framework Core 9**: ORM with Code-First approach
- **PostgreSQL**: Relational database (one per service)
- **JWT**: Shared authentication across services
- **YARP**: API Gateway and reverse proxy
- **Swagger**: API documentation for each service
- **Docker**: Containerization

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your machine

### Running the Application

1. **Navigate to the project directory**

2. **Start all services**:
   ```bash
   docker compose up -d
   ```

   This will start:
   - 3 PostgreSQL databases (identity-db, catalog-db, orders-db)
   - 3 Microservices (Identity, Catalog, Orders)
   - 1 API Gateway

3. **Access the services**:
   - **API Gateway**: `http://localhost:5000`
   - **Identity Service**: `http://localhost:5001`
   - **Identity Swagger**: `http://localhost:5001/swagger`
   - **Catalog Service**: `http://localhost:5002`
   - **Catalog Swagger**: `http://localhost:5002/swagger`
   - **Orders Service**: `http://localhost:5003`
   - **Orders Swagger**: `http://localhost:5003/swagger`

4. **Stop the application**:
   ```bash
   docker compose down
   ```

### Default Credentials

The Identity service automatically seeds sample data on startup:

**Admin Account**:
- Email: `admin@ecommerce.com`
- Password: `Admin123!`
- Role: Admin (can manage products and categories)

**Customer Account**:
- Email: `customer@example.com`
- Password: `Customer123!`
- Role: Customer (can browse and order products)

## API Usage

### Via API Gateway (Recommended)

All requests should go through the API Gateway at `http://localhost:5000`:

#### 1. Register/Login (Identity Service)
```bash
# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "customer@example.com",
    "password": "Customer123!"
  }'
```

#### 2. Get Products (Catalog Service)
```bash
curl -X GET http://localhost:5000/api/products
```

#### 3. Get Categories (Catalog Service)
```bash
curl -X GET http://localhost:5000/api/categories
```

#### 4. Create Order (Orders Service)
```bash
curl -X POST http://localhost:5000/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {your-token}" \
  -d '{
    "items": [
      {
        "productId": "{product-guid}",
        "productName": "Laptop",
        "quantity": 2,
        "unitPrice": 1299.99
      }
    ]
  }'
```

### Direct Service Access

You can also access services directly:

- **Identity**: `http://localhost:5001/api/auth/*`
- **Catalog**: `http://localhost:5002/api/products/*` or `/api/categories/*`
- **Orders**: `http://localhost:5003/api/orders/*`

## Sample Data

### Categories (Catalog Service)
- Electronics
- Books
- Clothing

### Products (Catalog Service)
- Laptop ($1,299.99) - Electronics
- Smartphone ($899.99) - Electronics
- Wireless Headphones ($249.99) - Electronics
- Clean Code book ($39.99) - Books
- Domain-Driven Design book ($49.99) - Books
- T-Shirt ($19.99) - Clothing
- Jeans ($59.99) - Clothing

## Project Structure

```
Microservices/
├── services/
│   ├── Identity/
│   │   ├── Identity.Domain/
│   │   ├── Identity.Application/
│   │   ├── Identity.Infrastructure/
│   │   ├── Identity.API/
│   │   └── Dockerfile
│   ├── Catalog/
│   │   ├── Catalog.Domain/
│   │   ├── Catalog.Application/
│   │   ├── Catalog.Infrastructure/
│   │   ├── Catalog.API/
│   │   └── Dockerfile
│   └── Orders/
│       ├── Orders.Domain/
│       ├── Orders.Application/
│       ├── Orders.Infrastructure/
│       ├── Orders.API/
│       └── Dockerfile
├── gateway/
│   └── ApiGateway/
│       ├── Program.cs
│       ├── appsettings.json
│       ├── ApiGateway.csproj
│       └── Dockerfile
├── k8s/                        # Kubernetes manifests (optional)
├── docker-compose.yml
└── README.md
```

## Service Communication

```
┌─────────┐
│ Client  │
└────┬────┘
     │
     ▼
┌────────────────┐
│  API Gateway   │ (Port 5000)
│     (YARP)     │
└────┬───────────┘
     │
     ├──────────┬──────────┬──────────┐
     ▼          ▼          ▼          ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│Identity │ │ Catalog │ │ Orders  │
│Service  │ │ Service │ │ Service │
│ :5001   │ │ :5002   │ │ :5003   │
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│identity  │ │ catalog  │ │ orders   │
│   -db    │ │   -db    │ │   -db    │
└──────────┘ └──────────┘ └──────────┘
```

## Kubernetes Deployment (Optional)

Kubernetes manifests are provided in the `k8s/` directory for deploying to Kubernetes clusters.

### Prerequisites
- Kubernetes cluster (minikube, Docker Desktop, or cloud provider)
- kubectl configured

### Deploy to Kubernetes
```bash
kubectl apply -f k8s/
```

### Access the services
```bash
# Get the gateway URL
kubectl get ingress
```

## Development

### Running Individual Services Locally

Each service can be run independently:

```bash
# Identity Service
cd services/Identity/Identity.API
dotnet run

# Catalog Service
cd services/Catalog/Catalog.API
dotnet run

# Orders Service
cd services/Orders/Orders.API
dotnet run

# API Gateway
cd gateway/ApiGateway
dotnet run
```

**Note**: Update connection strings in `appsettings.json` to point to your local PostgreSQL instances.

### Adding a New Microservice

1. Create new service following Onion Architecture
2. Add database configuration in `docker-compose.yml`
3. Add service configuration in `docker-compose.yml`
4. Update API Gateway routes in `gateway/ApiGateway/appsettings.json`
5. Create Kubernetes manifests (if using K8s)

## Monitoring and Logging

Each service logs to console output. View logs with:

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f identity-service
docker compose logs -f catalog-service
docker compose logs -f orders-service
docker compose logs -f api-gateway
```

## Security Notes

- JWT secret in configuration is for development only
- In production, use environment variables and secure secret management
- Passwords are hashed using BCrypt in Identity service
- Each service validates JWT tokens independently
- API Gateway doesn't authenticate; services handle their own auth

## Advantages of Microservices Architecture

- **Independent Deployment**: Each service can be deployed independently
- **Technology Flexibility**: Services can use different technologies
- **Scalability**: Scale services independently based on demand
- **Fault Isolation**: Failure in one service doesn't crash entire system
- **Team Autonomy**: Different teams can work on different services

## Trade-offs

- **Complexity**: More complex than monolith
- **Data Consistency**: Distributed transactions are challenging
- **Network Latency**: Inter-service communication overhead
- **Testing**: Integration testing is more complex
- **Deployment**: Requires orchestration (Docker Compose, Kubernetes)

## License

This is a sample project for educational purposes.
