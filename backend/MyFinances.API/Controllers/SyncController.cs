using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using MyFinances.API.Data;
using MyFinances.API.Models;

namespace MyFinances.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class SyncController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SyncController(AppDbContext context)
        {
            _context = context;
        }

        private Guid? GetUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst(ClaimTypes.Name);
            if (claim != null && Guid.TryParse(claim.Value, out Guid parsedId))
            {
                return parsedId;
            }
            return null;
        }

        // --- ACCOUNT SYNC ---

        [HttpPost("accounts")]
        public async Task<IActionResult> SyncAccounts([FromBody] List<Account> clientAccounts)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            foreach (var clientAcc in clientAccounts)
            {
                clientAcc.UserId = userId.Value;
                var existing = await _context.Accounts.FirstOrDefaultAsync(a => a.Id == clientAcc.Id && a.UserId == userId.Value);
                if (existing == null)
                {
                    _context.Accounts.Add(clientAcc);
                }
                else
                {
                    existing.Name = clientAcc.Name;
                    existing.Type = clientAcc.Type;
                    existing.Balance = clientAcc.Balance;
                    existing.Currency = clientAcc.Currency;
                    existing.IsActive = clientAcc.IsActive;
                }
            }

            await _context.SaveChangesAsync();

            var serverAccounts = await _context.Accounts.Where(a => a.UserId == userId.Value).ToListAsync();
            return Ok(serverAccounts);
        }

        // --- TRANSACTION SYNC ---

        [HttpPost("transactions")]
        public async Task<IActionResult> SyncTransactions([FromBody] List<Transaction> clientTransactions)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            // Validate that the transactions correspond to accounts owned by the user
            var userAccountIds = await _context.Accounts
                .Where(a => a.UserId == userId.Value)
                .Select(a => a.Id)
                .ToListAsync();

            foreach (var clientTx in clientTransactions)
            {
                if (!userAccountIds.Contains(clientTx.AccountId))
                {
                    continue; // Skip transactions for accounts not owned by this user
                }

                var existing = await _context.Transactions.FirstOrDefaultAsync(t => t.Id == clientTx.Id);
                if (existing == null)
                {
                    _context.Transactions.Add(clientTx);
                }
                else
                {
                    existing.Amount = clientTx.Amount;
                    existing.Type = clientTx.Type;
                    existing.Category = clientTx.Category;
                    existing.Description = clientTx.Description;
                    existing.Date = clientTx.Date;
                }
            }

            await _context.SaveChangesAsync();

            // Return all transactions for the user's accounts
            var serverTransactions = await _context.Transactions
                .Where(t => userAccountIds.Contains(t.AccountId))
                .ToListAsync();

            return Ok(serverTransactions);
        }

        // --- PASSWORD CREDENTIAL SYNC (AES Cifrada de Extremo a Extremo) ---

        [HttpPost("credentials")]
        public async Task<IActionResult> SyncCredentials([FromBody] List<PasswordCredential> clientCredentials)
        {
            var userId = GetUserId();
            if (userId == null) return Unauthorized();

            foreach (var clientCred in clientCredentials)
            {
                clientCred.UserId = userId.Value;
                var existing = await _context.Credentials.FirstOrDefaultAsync(c => c.Id == clientCred.Id && c.UserId == userId.Value);
                if (existing == null)
                {
                    _context.Credentials.Add(clientCred);
                }
                else if (clientCred.UpdatedAt > existing.UpdatedAt)
                {
                    existing.ServiceName = clientCred.ServiceName;
                    existing.Username = clientCred.Username;
                    existing.EncryptedPassword = clientCred.EncryptedPassword;
                    existing.WebsiteUrl = clientCred.WebsiteUrl;
                    existing.EncryptedNotes = clientCred.EncryptedNotes;
                    existing.UpdatedAt = clientCred.UpdatedAt;
                }
            }

            await _context.SaveChangesAsync();

            var serverCredentials = await _context.Credentials.Where(c => c.UserId == userId.Value).ToListAsync();
            return Ok(serverCredentials);
        }
    }
}
