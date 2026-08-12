using System;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using MyFinances.API.Data;
using MyFinances.API.Models;

namespace MyFinances.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TelegramBotController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private static readonly HttpClient _httpClient = new HttpClient();

        public TelegramBotController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        // DTO for incoming Telegram update webhook
        public class TelegramUpdate
        {
            public int Update_id { get; set; }
            public TelegramMessage? Message { get; set; }
        }

        public class TelegramMessage
        {
            public int Message_id { get; set; }
            public TelegramChat Chat { get; set; } = new TelegramChat();
            public string? Text { get; set; }
        }

        public class TelegramChat
        {
            public long Id { get; set; }
            public string? Username { get; set; }
        }

        // Webhook receiver from Telegram
        [HttpPost("webhook")]
        public async Task<IActionResult> Webhook([FromBody] JsonElement rawUpdate)
        {
            try
            {
                // Inspect payload safely
                if (!rawUpdate.TryGetProperty("message", out var messageProp))
                    return Ok();

                if (!messageProp.TryGetProperty("chat", out var chatProp) || 
                    !chatProp.TryGetProperty("id", out var idProp))
                    return Ok();

                long chatId = idProp.GetInt64();
                string messageText = messageProp.TryGetProperty("text", out var textProp) ? textProp.GetString() ?? "" : "";

                if (string.IsNullOrWhiteSpace(messageText))
                    return Ok();

                messageText = messageText.Trim();

                // 1. Handle Commands
                if (messageText.StartsWith("/"))
                {
                    await HandleCommand(chatId, messageText);
                }
                else
                {
                    // 2. Parse and Register Transaction
                    await HandleTransactionMessage(chatId, messageText);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error processing Telegram webhook: {ex.Message}");
            }

            return Ok();
        }

        private async Task HandleCommand(long chatId, string text)
        {
            var parts = text.Split(' ', 2);
            string command = parts[0].ToLower();
            string args = parts.Length > 1 ? parts[1].Trim() : "";

            string replyText;

            if (command == "/start" || command == "/ayuda" || command == "/help")
            {
                replyText = "¡Hola! Bienvenido a *My Finances Assistant* 🤖💎\n\n" +
                            "Soy tu asistente virtual para registrar tus gastos al instante.\n\n" +
                            "Para empezar:\n" +
                            "1. Abre la app móvil *My Finances*.\n" +
                            "2. Ve a la pestaña de *Perfil* > *Vincular Telegram* para obtener tu código de vinculación de 6 dígitos.\n" +
                            "3. Escríbeme aquí el comando: `/link TU_CODIGO` (ejemplo: `/link 123456`)\n\n" +
                            "Una vez vinculado, solo envíame mensajes como:\n" +
                            "✍️ *\"gaste 150 bs en Farmatodo\"*\n" +
                            "✍️ *\"pago movil 10$ en gasolina\"*\n" +
                            "✍️ *\"recibi ingreso de 50$ de sueldo\"*";
            }
            else if (command == "/link")
            {
                if (string.IsNullOrWhiteSpace(args))
                {
                    replyText = "⚠️ Debes ingresar el código de vinculación. Ejemplo: `/link 123456`";
                }
                else
                {
                    var user = await _context.Users.FirstOrDefaultAsync(u => 
                        u.TelegramLinkToken == args && 
                        u.TelegramLinkTokenExpires > DateTime.UtcNow);

                    if (user == null)
                    {
                        replyText = "❌ Código inválido, expirado o ya utilizado. Genera uno nuevo en la pestaña de Perfil en la aplicación.";
                    }
                    else
                    {
                        // Link user to Telegram chat
                        user.TelegramChatId = chatId.ToString();
                        user.TelegramLinkToken = null; // Clear token
                        user.TelegramLinkTokenExpires = null;

                        await _context.SaveChangesAsync();

                        replyText = $"🎉 *¡Vinculación Exitosa!*\n\n" +
                                    $"Tu chat de Telegram ha sido enlazado a la cuenta de *{user.Username}*.\n\n" +
                                    $"A partir de ahora, puedes registrar transacciones directamente escribiéndome un mensaje.";
                    }
                }
            }
            else
            {
                replyText = "❓ Comando no reconocido. Escribe `/ayuda` para ver las instrucciones.";
            }

            await SendTelegramMessage(chatId, replyText);
        }

        private async Task HandleTransactionMessage(long chatId, string text)
        {
            // Find linked user
            var user = await _context.Users.FirstOrDefaultAsync(u => u.TelegramChatId == chatId.ToString());
            if (user == null)
            {
                string linkPrompt = "⚠️ Este chat no está vinculado a ninguna cuenta de *My Finances*.\n\n" +
                                    "Por favor, abre la app en tu teléfono, ve a *Perfil* > *Vincular Telegram*, obtén tu código de 6 dígitos y escribe aquí:\n" +
                                    "`/link TU_CODIGO`";
                await SendTelegramMessage(chatId, linkPrompt);
                return;
            }

            // Simple NLP parser using Regex
            // Matches amounts like: 250 bs, 350.50bs, 10$, 10 usd, 50 dolares
            var amountRegex = new Regex(@"(?:gaste|pago|ingreso|recibi|consumo)?[^\d]*([\d\.,]+)\s*(bs|ves|\$|usd|dolares)?", RegexOptions.IgnoreCase);
            var match = amountRegex.Match(text);

            if (!match.Success)
            {
                await SendTelegramMessage(chatId, "🤷‍♂️ No pude reconocer el monto en tu mensaje. Intenta con algo como: *\"gaste 150 bs en comida\"* o *\"pago movil 10$ en almuerzo\"*.");
                return;
            }

            string amountStr = match.Groups[1].Value;
            string currencyIndicator = match.Groups[2].Value.ToLower();

            decimal amount;
            // Handle Venezuelan format 1.250,50 or 250,50
            try
            {
                if (amountStr.Contains(",") && amountStr.Contains("."))
                {
                    amountStr = amountStr.Replace(".", "").Replace(",", ".");
                }
                else if (amountStr.Contains(","))
                {
                    amountStr = amountStr.Replace(",", ".");
                }
                amount = decimal.Parse(amountStr);
            }
            catch
            {
                await SendTelegramMessage(chatId, "⚠️ Formato de número no válido. Ejemplo: *150,50* o *1250*.");
                return;
            }

            // Determine Currency
            string currency = "VES"; // Default for Venezuelan context
            if (currencyIndicator.Contains("$") || currencyIndicator.Contains("usd") || currencyIndicator.Contains("dolar"))
            {
                currency = "USD";
            }

            // Determine Transaction Type (income or expense)
            string type = "expense";
            if (text.Contains("ingreso") || text.Contains("recibi") || text.Contains("sueldo") || text.Contains("pago de"))
            {
                type = "income";
            }

            // Find merchant
            string merchant = "Telegram Assitant";
            var merchantRegex = new Regex(@"(?:en|de|al|a)\s+([A-Za-z0-9\s\-]+)", RegexOptions.IgnoreCase);
            var merchantMatch = merchantRegex.Match(text);
            if (merchantMatch.Success)
            {
                merchant = merchantMatch.Groups[1].Value.Trim();
            }

            // Auto categorization based on keywords
            string category = "Otros";
            string lowerText = text.ToLower();
            if (lowerText.Contains("mercado") || lowerText.Contains("supermercado") || lowerText.Contains("gama") || lowerText.Contains("abasto") || lowerText.Contains("bodega"))
                category = "Supermercado";
            else if (lowerText.Contains("comida") || lowerText.Contains("restaurante") || lowerText.Contains("almuerzo") || lowerText.Contains("cena") || lowerText.Contains("cafe"))
                category = "Comida";
            else if (lowerText.Contains("taxi") || lowerText.Contains("ridery") || lowerBodyContainsGas(lowerText))
                category = "Transporte";
            else if (lowerText.Contains("luz") || lowerText.Contains("cantv") || lowerText.Contains("internet") || lowerText.Contains("telefono") || lowerText.Contains("simpletv"))
                category = "Servicios";
            else if (lowerText.Contains("farmacia") || lowerText.Contains("clinica") || lowerText.Contains("farmatodo") || lowerText.Contains("pastilla") || lowerText.Contains("locatel"))
                category = "Salud";
            else if (lowerText.Contains("cine") || lowerText.Contains("netflix") || lowerText.Contains("spotify") || lowerText.Contains("fiesta"))
                category = "Entretenimiento";

            // Find user account matching the currency
            var account = await _context.Accounts.FirstOrDefaultAsync(a => a.UserId == user.Id && a.Currency.ToUpper() == currency && a.IsActive);
            if (account == null)
            {
                // Fallback: create default cash account for this user in this currency
                account = new Account
                {
                    Id = Guid.NewGuid().ToString(),
                    UserId = user.Id,
                    Name = currency == "VES" ? "Efectivo Bolívares" : "Efectivo Dólares",
                    Type = "cash",
                    Balance = 0.00m,
                    Currency = currency,
                    IsActive = true
                };
                _context.Accounts.Add(account);
                await _context.SaveChangesAsync();
            }

            // Insert Transaction
            var transaction = new Transaction
            {
                Id = Guid.NewGuid().ToString(),
                AccountId = account.Id,
                Type = type,
                Amount = amount,
                Category = category,
                Description = $"{merchant} (Telegram)",
                Date = DateTime.UtcNow
            };

            // Update Account Balance
            if (type == "expense")
            {
                account.Balance -= amount;
            }
            else
            {
                account.Balance += amount;
            }

            _context.Transactions.Add(transaction);
            await _context.SaveChangesAsync();

            // Send Confirmation reply
            string confirmationMsg = $"✅ *¡Transacción Registrada!*\n\n" +
                                     $"🔹 *Monto:* {amount:N2} {currency}\n" +
                                     $"🔹 *Tipo:* {(type == "expense" ? "Gasto 📉" : "Ingreso 📈")}\n" +
                                     $"🔹 *Categoría:* {category}\n" +
                                     $"🔹 *Cuenta:* {account.Name}\n" +
                                     $"🔹 *Comercio:* {merchant}\n\n" +
                                     $"💡 Tu app móvil se sincronizará automáticamente al abrirla.";

            await SendTelegramMessage(chatId, confirmationMsg);
        }

        private bool lowerBodyContainsGas(string text)
        {
            return text.Contains("gasolina") || text.Contains("gas") || text.Contains("bomba");
        }

        // Endpoint for Flutter app to generate a link token
        [HttpGet("link-code")]
        [Authorize]
        public async Task<IActionResult> GenerateLinkCode()
        {
            // Extract username from token claims
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return Unauthorized();

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user == null)
                return NotFound("Usuario no encontrado.");

            // Generate random 6 digit token
            var random = new Random();
            string token = random.Next(100000, 999999).ToString();

            user.TelegramLinkToken = token;
            user.TelegramLinkTokenExpires = DateTime.UtcNow.AddMinutes(10); // Expire in 10 minutes

            await _context.SaveChangesAsync();

            return Ok(new { Code = token });
        }

        private async Task SendTelegramMessage(long chatId, string text)
        {
            var botToken = _configuration["Telegram:BotToken"] ?? "8517965835:AAHUfxF_NxdMiHE9292ZahkyuqZxtjahGKU";
            var url = $"https://api.telegram.org/bot{botToken}/sendMessage";

            var payload = new
            {
                chat_id = chatId,
                text = text,
                parse_mode = "Markdown"
            };

            var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

            try
            {
                await _httpClient.PostAsync(url, content);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending Telegram response: {ex.Message}");
            }
        }
    }
}
