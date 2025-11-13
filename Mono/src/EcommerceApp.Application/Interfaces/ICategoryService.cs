using EcommerceApp.Application.DTOs.Categories;

namespace EcommerceApp.Application.Interfaces;

public interface ICategoryService
{
    Task<IEnumerable<CategoryDto>> GetAllCategoriesAsync();
    Task<CategoryDto?> GetCategoryByIdAsync(Guid id);
    Task<CategoryDto> CreateCategoryAsync(CreateCategoryRequest request);
    Task DeleteCategoryAsync(Guid id);
}
