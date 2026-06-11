namespace Clipwell.Core.AI;

public sealed record OpenAICompatibleConfig(string BaseUrl, string ApiKey, string Model);

public class TextAIException : Exception
{
    public TextAIException(string message) : base(message)
    {
    }

    public TextAIException(string message, Exception inner) : base(message, inner)
    {
    }
}

/// <summary>Text AI operations backed by a configurable provider (mac: Pro/AI/TextAIService.swift).</summary>
public interface ITextAIService
{
    Task ValidateConnectionAsync(CancellationToken cancellationToken = default);
    Task<string> RewriteAsync(string text, CancellationToken cancellationToken = default);
    Task<string> SummarizeAsync(string text, CancellationToken cancellationToken = default);
    Task<string> TranslateAsync(string text, string targetLanguage, CancellationToken cancellationToken = default);
}
