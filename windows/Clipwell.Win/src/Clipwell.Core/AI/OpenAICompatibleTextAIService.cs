using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Clipwell.Core.AI;

/// <summary>
/// Talks to any OpenAI-compatible /chat/completions endpoint. Port of the macOS
/// OpenAICompatibleTextAIService, including its system prompts, so both platforms
/// behave identically against the same endpoint.
/// </summary>
public sealed class OpenAICompatibleTextAIService : ITextAIService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private readonly HttpClient _httpClient;
    private readonly Func<OpenAICompatibleConfig> _configProvider;

    public OpenAICompatibleTextAIService(Func<OpenAICompatibleConfig> configProvider, HttpClient? httpClient = null)
    {
        _configProvider = configProvider;
        _httpClient = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
    }

    public async Task ValidateConnectionAsync(CancellationToken cancellationToken = default)
    {
        var config = ValidatedConfig();
        using var request = new HttpRequestMessage(HttpMethod.Get, Endpoint(config, "models"));
        Authorize(request, config);
        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            throw new TextAIException(await UpstreamMessageAsync(response,
                $"AI validation failed with status {(int)response.StatusCode}.").ConfigureAwait(false));
        }
    }

    public Task<string> RewriteAsync(string text, CancellationToken cancellationToken = default) =>
        CompleteAsync(
            "You are a concise rewriting assistant. Rewrite the user's clipboard text for clarity while preserving meaning. Return only the rewritten text.",
            text, cancellationToken);

    public Task<string> SummarizeAsync(string text, CancellationToken cancellationToken = default) =>
        CompleteAsync(
            "You are a concise summarization assistant. Summarize the user's clipboard text into short bullet points. Return only the summary.",
            text, cancellationToken);

    public Task<string> TranslateAsync(string text, string targetLanguage, CancellationToken cancellationToken = default) =>
        CompleteAsync(
            $"You are a precise translation assistant. Translate the user's clipboard text into {targetLanguage}. Preserve meaning, tone, structure, lists, and line breaks when possible. Return only the translated text.",
            text, cancellationToken);

    private async Task<string> CompleteAsync(string system, string user, CancellationToken cancellationToken)
    {
        var normalized = user.Trim();
        if (normalized.Length == 0)
        {
            throw new TextAIException("Input text is empty.");
        }
        var config = ValidatedConfig();

        var payload = new ChatCompletionRequest(
            config.Model,
            [new ChatMessage("system", system), new ChatMessage("user", normalized)],
            Temperature: 0.2);

        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint(config, "chat/completions"))
        {
            Content = new StringContent(JsonSerializer.Serialize(payload, JsonOptions), Encoding.UTF8, "application/json"),
        };
        Authorize(request, config);

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            throw new TextAIException(await UpstreamMessageAsync(response,
                $"AI request failed with status {(int)response.StatusCode}.").ConfigureAwait(false));
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        var decoded = JsonSerializer.Deserialize<ChatCompletionResponse>(body, JsonOptions);
        var content = decoded?.Choices?.FirstOrDefault()?.Message?.Content?.Trim();
        if (string.IsNullOrEmpty(content))
        {
            throw new TextAIException("AI returned an invalid response.");
        }
        return content;
    }

    private OpenAICompatibleConfig ValidatedConfig()
    {
        var config = _configProvider();
        var baseUrl = config.BaseUrl.Trim();
        var model = config.Model.Trim();
        if (baseUrl.Length == 0)
        {
            throw new TextAIException("AI base URL is not configured. Open Settings and add your OpenAI-compatible endpoint.");
        }
        if (model.Length == 0)
        {
            throw new TextAIException("AI model is not configured. Open Settings and choose a model.");
        }
        return new OpenAICompatibleConfig(baseUrl, config.ApiKey.Trim(), model);
    }

    private static Uri Endpoint(OpenAICompatibleConfig config, string path)
    {
        var baseUrl = config.BaseUrl.TrimEnd('/');
        if (!Uri.TryCreate($"{baseUrl}/{path}", UriKind.Absolute, out var uri))
        {
            throw new TextAIException("AI base URL is invalid.");
        }
        return uri;
    }

    private static void Authorize(HttpRequestMessage request, OpenAICompatibleConfig config)
    {
        if (config.ApiKey.Length > 0)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", config.ApiKey);
        }
    }

    private static async Task<string> UpstreamMessageAsync(HttpResponseMessage response, string fallback)
    {
        try
        {
            var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
            var envelope = JsonSerializer.Deserialize<ErrorEnvelope>(body, JsonOptions);
            return string.IsNullOrEmpty(envelope?.Error?.Message) ? fallback : envelope.Error.Message;
        }
        catch (JsonException)
        {
            return fallback;
        }
    }

    private sealed record ChatMessage(string Role, string? Content);

    private sealed record ChatCompletionRequest(string Model, List<ChatMessage> Messages, double Temperature);

    private sealed record ChatCompletionResponse(List<Choice>? Choices);

    private sealed record Choice(ChatMessage? Message);

    private sealed record ErrorEnvelope(ErrorBody? Error);

    private sealed record ErrorBody(string? Message);
}
