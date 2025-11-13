using EcommerceApp.Application.DTOs.Orders;
using EcommerceApp.Application.Interfaces;
using EcommerceApp.Domain.Entities;
using EcommerceApp.Domain.Interfaces;

namespace EcommerceApp.Application.Services;

public class OrderService : IOrderService
{
    private readonly IRepository<Order> _orderRepository;
    private readonly IRepository<Product> _productRepository;
    private readonly IRepository<OrderItem> _orderItemRepository;

    public OrderService(
        IRepository<Order> orderRepository,
        IRepository<Product> productRepository,
        IRepository<OrderItem> orderItemRepository)
    {
        _orderRepository = orderRepository;
        _productRepository = productRepository;
        _orderItemRepository = orderItemRepository;
    }

    public async Task<OrderDto> CreateOrderAsync(Guid userId, CreateOrderRequest request)
    {
        if (request.Items.Count == 0)
        {
            throw new InvalidOperationException("Order must contain at least one item");
        }

        var products = await _productRepository.GetAllAsync();
        var productDict = products.ToDictionary(p => p.Id);

        decimal totalAmount = 0;
        var orderItems = new List<OrderItem>();

        foreach (var item in request.Items)
        {
            if (!productDict.TryGetValue(item.ProductId, out var product))
            {
                throw new InvalidOperationException($"Product {item.ProductId} not found");
            }

            if (product.StockQuantity < item.Quantity)
            {
                throw new InvalidOperationException($"Insufficient stock for product {product.Name}");
            }

            var orderItem = new OrderItem
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = product.Price,
                CreatedAt = DateTime.UtcNow
            };

            orderItems.Add(orderItem);
            totalAmount += orderItem.UnitPrice * orderItem.Quantity;

            product.StockQuantity -= item.Quantity;
            await _productRepository.UpdateAsync(product);
        }

        var order = new Order
        {
            UserId = userId,
            TotalAmount = totalAmount,
            Status = "Pending",
            CreatedAt = DateTime.UtcNow
        };

        await _orderRepository.AddAsync(order);

        foreach (var item in orderItems)
        {
            item.OrderId = order.Id;
            await _orderItemRepository.AddAsync(item);
        }

        return new OrderDto
        {
            Id = order.Id,
            UserId = order.UserId,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            CreatedAt = order.CreatedAt,
            Items = orderItems.Select(oi => new OrderItemDto
            {
                ProductId = oi.ProductId,
                ProductName = productDict[oi.ProductId].Name,
                Quantity = oi.Quantity,
                UnitPrice = oi.UnitPrice
            }).ToList()
        };
    }

    public async Task<IEnumerable<OrderDto>> GetUserOrdersAsync(Guid userId)
    {
        var orders = await _orderRepository.GetAllAsync();
        var userOrders = orders.Where(o => o.UserId == userId).ToList();

        var orderItems = await _orderItemRepository.GetAllAsync();
        var products = await _productRepository.GetAllAsync();
        var productDict = products.ToDictionary(p => p.Id);

        return userOrders.Select(order => new OrderDto
        {
            Id = order.Id,
            UserId = order.UserId,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            CreatedAt = order.CreatedAt,
            Items = orderItems.Where(oi => oi.OrderId == order.Id).Select(oi => new OrderItemDto
            {
                ProductId = oi.ProductId,
                ProductName = productDict.GetValueOrDefault(oi.ProductId)?.Name ?? "Unknown",
                Quantity = oi.Quantity,
                UnitPrice = oi.UnitPrice
            }).ToList()
        });
    }

    public async Task<OrderDto?> GetOrderByIdAsync(Guid orderId, Guid userId)
    {
        var order = await _orderRepository.GetByIdAsync(orderId);
        if (order == null || order.UserId != userId)
        {
            return null;
        }

        var orderItems = await _orderItemRepository.GetAllAsync();
        var products = await _productRepository.GetAllAsync();
        var productDict = products.ToDictionary(p => p.Id);

        return new OrderDto
        {
            Id = order.Id,
            UserId = order.UserId,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            CreatedAt = order.CreatedAt,
            Items = orderItems.Where(oi => oi.OrderId == order.Id).Select(oi => new OrderItemDto
            {
                ProductId = oi.ProductId,
                ProductName = productDict.GetValueOrDefault(oi.ProductId)?.Name ?? "Unknown",
                Quantity = oi.Quantity,
                UnitPrice = oi.UnitPrice
            }).ToList()
        };
    }
}
