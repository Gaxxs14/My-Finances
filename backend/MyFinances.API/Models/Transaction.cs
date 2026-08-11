using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyFinances.API.Models
{
    public class Transaction
    {
        [Key]
        [Required]
        public string Id { get; set; } = string.Empty; // Sent from Flutter (UUID)

        [Required]
        public string AccountId { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Type { get; set; } = string.Empty; // 'income', 'expense', 'savings'

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        [Required]
        [MaxLength(100)]
        public string Category { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? Description { get; set; }

        [Required]
        public DateTime Date { get; set; }

        [ForeignKey("AccountId")]
        public Account? Account { get; set; }
    }
}
