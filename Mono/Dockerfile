FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["src/EcommerceApp.API/EcommerceApp.API.csproj", "src/EcommerceApp.API/"]
COPY ["src/EcommerceApp.Application/EcommerceApp.Application.csproj", "src/EcommerceApp.Application/"]
COPY ["src/EcommerceApp.Infrastructure/EcommerceApp.Infrastructure.csproj", "src/EcommerceApp.Infrastructure/"]
COPY ["src/EcommerceApp.Domain/EcommerceApp.Domain.csproj", "src/EcommerceApp.Domain/"]

RUN dotnet restore "src/EcommerceApp.API/EcommerceApp.API.csproj"

COPY . .

WORKDIR "/src/src/EcommerceApp.API"
RUN dotnet build "EcommerceApp.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "EcommerceApp.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "EcommerceApp.API.dll"]
