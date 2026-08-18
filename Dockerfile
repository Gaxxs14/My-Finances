# Build stage using .NET 10 SDK
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app

# Copy csproj and restore dependencies
COPY backend/MyFinances.API/*.csproj ./backend/MyFinances.API/
RUN dotnet restore backend/MyFinances.API/MyFinances.API.csproj

# Copy remaining source code and build/publish
COPY backend/MyFinances.API/ ./backend/MyFinances.API/
WORKDIR /app/backend/MyFinances.API
RUN dotnet publish -c Release -o /app/out

# Runtime stage using ASP.NET Core 10.0 Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .

# Expose port (Render will route traffic to port 8080 or PORT env var)
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "MyFinances.API.dll"]
