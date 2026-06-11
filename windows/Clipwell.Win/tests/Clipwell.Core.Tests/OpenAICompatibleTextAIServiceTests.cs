using System.Net;
using System.Text;
using System.Text.Json;
using Clipwell.Core.AI;
using Xunit;

namespace Clipwell.Core.Tests;

public sealed class OpenAICompatibleTextAIServiceTests
{
    private sealed class FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public HttpRequestMessage? LastRequest { get; private set; }
        public string? LastRequestBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastRequest = request;
            LastRequestBody = request.Content is null
                ? null
                : await request.Content.ReadAsStringAsync(cancellationToken);
            return respond(request);
        }
    }

    private static OpenAICompatibleTextAIService Service(FakeHandler handler, string baseUrl = "http://ai.local/v1") =>
        new(() => new OpenAICompatibleConfig(baseUrl, "test-key", "test-model"), new HttpClient(handler));

    private static HttpResponseMessage ChatResponse(string content) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(
            JsonSerializer.Serialize(new
            {
                choices = new[] { new { message = new { role = "assistant", content } } },
            }),
            Encoding.UTF8, "application/json"),
    };

    [Fact]
    public async Task TranslateSendsChatCompletionAndReturnsContent()
    {
        var handler = new FakeHandler(_ => ChatResponse("  你好  "));
        var result = await Service(handler).TranslateAsync("hello", "Simplified Chinese");

        Assert.Equal("你好", result);
        Assert.Equal("http://ai.local/v1/chat/completions", handler.LastRequest!.RequestUri!.ToString());
        Assert.Equal("Bearer", handler.LastRequest.Headers.Authorization!.Scheme);
        Assert.Equal("test-key", handler.LastRequest.Headers.Authorization.Parameter);
        Assert.Contains("test-model", handler.LastRequestBody);
        Assert.Contains("Simplified Chinese", handler.LastRequestBody);
        Assert.Contains("hello", handler.LastRequestBody);
    }

    [Fact]
    public async Task UpstreamErrorMessageIsSurfaced()
    {
        var handler = new FakeHandler(_ => new HttpResponseMessage(HttpStatusCode.Unauthorized)
        {
            Content = new StringContent("""{"error": {"message": "Invalid API key"}}""", Encoding.UTF8, "application/json"),
        });

        var ex = await Assert.ThrowsAsync<TextAIException>(() => Service(handler).SummarizeAsync("text"));
        Assert.Equal("Invalid API key", ex.Message);
    }

    [Fact]
    public async Task MissingConfigThrowsBeforeAnyRequest()
    {
        var handler = new FakeHandler(_ => throw new InvalidOperationException("should not be called"));
        var service = new OpenAICompatibleTextAIService(
            () => new OpenAICompatibleConfig("", "key", "model"), new HttpClient(handler));

        await Assert.ThrowsAsync<TextAIException>(() => service.RewriteAsync("text"));
        Assert.Null(handler.LastRequest);
    }

    [Fact]
    public async Task EmptyInputThrows()
    {
        var handler = new FakeHandler(_ => ChatResponse("x"));
        await Assert.ThrowsAsync<TextAIException>(() => Service(handler).RewriteAsync("   "));
    }

    [Fact]
    public async Task ValidateConnectionHitsModelsEndpoint()
    {
        var handler = new FakeHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{}", Encoding.UTF8, "application/json"),
        });
        await Service(handler).ValidateConnectionAsync();
        Assert.Equal("http://ai.local/v1/models", handler.LastRequest!.RequestUri!.ToString());
    }

    [Fact]
    public async Task EmptyChoicesIsInvalidResponse()
    {
        var handler = new FakeHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("""{"choices": []}""", Encoding.UTF8, "application/json"),
        });
        await Assert.ThrowsAsync<TextAIException>(() => Service(handler).SummarizeAsync("text"));
    }
}
