using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using MyFinances.API.Models;

namespace MyFinances.API.Services
{
    public class TokenService
    {
        private readonly IConfiguration _configuration;

        public TokenService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public string GenerateToken(User user)
        {
            var keySection = _configuration["Jwt:Key"] ?? "SUPER_SECRET_KEY_FOR_FINANCES_PROJECT_2026_CHANGE_THIS_IN_PROD";
            var issuer = _configuration["Jwt:Issuer"] ?? "MyFinancesAPI";
            var audience = _configuration["Jwt:Audience"] ?? "MyFinancesClients";

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keySection));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: DateTime.UtcNow.AddDays(7), // Long live token or implement refresh
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}
