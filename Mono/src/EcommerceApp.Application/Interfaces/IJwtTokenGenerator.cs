using EcommerceApp.Domain.Entities;

namespace EcommerceApp.Application.Interfaces;

public interface IJwtTokenGenerator
{
    string GenerateToken(User user);
}
