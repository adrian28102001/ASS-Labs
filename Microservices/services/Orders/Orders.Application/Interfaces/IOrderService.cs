using Orders.Application.DTOs;

namespace Orders.Application.Interfaces;

public interface IOrderService
{
    Task<OrderDto> CreateOrderAsync(Guid userId, CreateOrderRequest request);
    Task<IEnumerable<OrderDto>> GetUserOrdersAsync(Guid userId);
    Task<OrderDto?> GetOrderByIdAsync(Guid orderId, Guid userId);
}
