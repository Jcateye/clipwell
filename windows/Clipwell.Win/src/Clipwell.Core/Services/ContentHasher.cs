using System.Security.Cryptography;
using System.Text;

namespace Clipwell.Core.Services;

/// <summary>Lowercase-hex SHA-256, matching the macOS ClipboardParser hash format.</summary>
public static class ContentHasher
{
    public static string Hash(byte[] data) => Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant();

    public static string Hash(string text) => Hash(Encoding.UTF8.GetBytes(text));
}
