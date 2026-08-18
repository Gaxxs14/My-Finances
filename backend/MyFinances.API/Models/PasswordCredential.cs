using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyFinances.API.Models
{
    public class PasswordCredential
    {
        [Key]
        [Required]
        public string Id { get; set; } = string.Empty; // Sent from Flutter (UUID)

        [Required]
        public Guid UserId { get; set; }

        [Required]
        [MaxLength(150)]
        public string ServiceName { get; set; } = string.Empty; // e.g. 'Bank of America'

        [Required]
        [MaxLength(150)]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string EncryptedPassword { get; set; } = string.Empty; // AES encrypted cipher text

        [MaxLength(500)]
        public string? WebsiteUrl { get; set; }

        public string? EncryptedNotes { get; set; } // AES encrypted notes payload

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("UserId")]
        public User? User { get; set; }
    }
}
