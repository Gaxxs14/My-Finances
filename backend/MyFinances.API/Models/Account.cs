using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyFinances.API.Models
{
    public class Account
    {
        [Key]
        [Required]
        public string Id { get; set; } = string.Empty; // Sent from Flutter (UUID)

        [Required]
        public Guid UserId { get; set; }

        [Required]
        [MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Type { get; set; } = string.Empty; // 'bank', 'cash', 'card', 'savings'

        [Column(TypeName = "decimal(18,2)")]
        public decimal Balance { get; set; } = 0.00m;

        [Required]
        [MaxLength(10)]
        public string Currency { get; set; } = "USD";

        public bool IsActive { get; set; } = true;

        [ForeignKey("UserId")]
        public User? User { get; set; }
    }
}
