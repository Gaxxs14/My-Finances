# Build stage using .NET 10 SDK
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app

# Copy csproj and restore dependencies
COPY *.csproj ./
RUN dotnet restore

# Copy remaining source code and build/publish
COPY . ./
RUN dotnet publish -c Release -o out

# Runtime stage using ASP.NET Core 10.0 Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/out .

# Expose port (Render/Koyeb will route traffic to port 8080 or the PORT environment variable)
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "MyFinances.API.dll"]
