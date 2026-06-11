using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Core.Pipeline;
using Clipwell.Core.Services;
using Xunit;

namespace Clipwell.Core.Tests;

public sealed class PipelineTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ClipRepository _repository;

    public PipelineTests()
    {
        _tempDir = Directory.CreateTempSubdirectory("clipwell-pipeline-").FullName;
        _repository = new ClipRepository(Path.Combine(_tempDir, "clips.sqlite"));
    }

    public void Dispose()
    {
        _repository.Dispose();
        Directory.Delete(_tempDir, recursive: true);
    }

    private static ClipItem TextClip(string text) =>
        ClipItem.CreateNew(ClipType.Text, text, null, "TestApp", ContentHasher.Hash(text));

    private sealed class FakePlugin(string id, Func<ClipPipelineContext, Task>? process = null, bool canProcess = true)
        : IClipPipelinePlugin
    {
        public string Id => id;
        public string Name => id;
        public Task<bool> CanProcessAsync(ClipPipelineContext context) => Task.FromResult(canProcess);
        public Task ProcessAsync(ClipPipelineContext context, CancellationToken cancellationToken) =>
            process?.Invoke(context) ?? Task.CompletedTask;
    }

    [Fact]
    public async Task RunnerRecordsSucceededSkippedAndFailedStages()
    {
        var runner = new ClipPipelineRunner(
        [
            new FakePlugin("ok"),
            new FakePlugin("skipped", canProcess: false),
            new FakePlugin("boom", _ => throw new InvalidOperationException("nope")),
            new FakePlugin("after-failure"),
        ]);

        var result = await runner.RunAsync(new ClipPipelineContext(ClipPipelineTrigger.Manual, TextClip("hi")));

        Assert.Equal(
            [ClipPipelineStageStatus.Succeeded, ClipPipelineStageStatus.Skipped, ClipPipelineStageStatus.Failed, ClipPipelineStageStatus.Succeeded],
            result.StageResults.Select(stage => stage.Status));
        Assert.Equal("nope", result.StageResults[2].Message);
    }

    [Fact]
    public async Task RunnerStopOnFailurePolicyRethrows()
    {
        var runner = new ClipPipelineRunner(
            [new FakePlugin("boom", _ => throw new InvalidOperationException("stop"))],
            ClipPipelineFailurePolicy.StopOnFailure);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            runner.RunAsync(new ClipPipelineContext(ClipPipelineTrigger.Manual, TextClip("hi"))));
    }

    [Fact]
    public async Task HostSavesArtifactsAsDerivedClips()
    {
        var original = TextClip("bonjour");
        _repository.Insert(original);

        var plugin = new FakePlugin("translator", context =>
        {
            context.Artifacts.Add(new ClipPipelineArtifact("translation", "Translate", "hello", "translator"));
            context.RequestedEffects |= ClipPipelineEffects.SaveDerivedClip;
            return Task.CompletedTask;
        });
        var host = new PipelineHost(_repository, [plugin]);

        await host.RunManualAsync(original, "translator");

        var derived = _repository.Fetch().Single(clip => clip.Origin == ClipOrigin.ProDerived);
        Assert.Equal("hello", derived.PlainText);
        Assert.Equal(original.Id, derived.DerivedFromClipId);
        Assert.Equal("TestApp", derived.SourceApp);
    }

    [Fact]
    public async Task HostPostCaptureRespectsEnabledFlagAndOrder()
    {
        var calls = new List<string>();
        Task Record(ClipPipelineContext context, string name)
        {
            calls.Add(name);
            return Task.CompletedTask;
        }
        var host = new PipelineHost(_repository,
        [
            new FakePlugin("first", c => Record(c, "first")),
            new FakePlugin("second", c => Record(c, "second")),
            new FakePlugin("disabled", c => Record(c, "disabled")),
        ]);

        var stages = new List<ClipPipelineStageConfiguration>
        {
            new() { PluginId = "second", Enabled = true, Order = 20 },
            new() { PluginId = "first", Enabled = true, Order = 10 },
            new() { PluginId = "disabled", Enabled = false, Order = 5 },
            new() { PluginId = "unknown-plugin", Enabled = true, Order = 1 },
        };
        await host.RunPostCaptureAsync(TextClip("hi"), stages);

        Assert.Equal(["first", "second"], calls);
    }

    [Fact]
    public async Task ImageOcrPluginOnlyProcessesRawImageClips()
    {
        var plugin = new ImageOcrPlugin(new FakeOcr("recognized"));

        var rawImage = ClipItem.CreateNew(ClipType.Media, null, null, "App", "h") with { PayloadPath = "/tmp/x.png" };
        var mediaFile = ClipItem.CreateNew(ClipType.Media, "/tmp/movie.mp4", null, "App", "h");
        var text = TextClip("hi");

        Assert.True(await plugin.CanProcessAsync(new ClipPipelineContext(ClipPipelineTrigger.PostCapture, rawImage)));
        Assert.False(await plugin.CanProcessAsync(new ClipPipelineContext(ClipPipelineTrigger.PostCapture, mediaFile)));
        Assert.False(await plugin.CanProcessAsync(new ClipPipelineContext(ClipPipelineTrigger.PostCapture, text)));

        var context = new ClipPipelineContext(ClipPipelineTrigger.PostCapture, rawImage);
        await plugin.ProcessAsync(context, CancellationToken.None);
        Assert.Equal("recognized", context.CurrentText);
        Assert.True(context.RequestedEffects.HasFlag(ClipPipelineEffects.SaveDerivedClip));
    }

    private sealed class FakeOcr(string result) : IOcrService
    {
        public Task<string> RecognizeAsync(string imagePath, CancellationToken cancellationToken = default) =>
            Task.FromResult(result);
    }
}
