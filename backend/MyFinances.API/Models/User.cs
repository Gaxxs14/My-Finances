using System;
using System.ComponentModel.DataAnnotations;

namespace MyFinances.API.Models
{
    public class User
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(100)]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? PinHash { get; set; }

        [MaxLength(100)]
        public string? TelegramChatId { get; set; }

        [MaxLength(20)]
        public string? TelegramLinkToken { get; set; }

        public DateTime? TelegramLinkTokenExpires { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
