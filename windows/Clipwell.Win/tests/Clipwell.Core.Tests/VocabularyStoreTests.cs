using Clipwell.Core.Vocabulary;
using Xunit;

namespace Clipwell.Core.Tests;

public sealed class VocabularyStoreTests : IDisposable
{
    private readonly string _tempDir;
    private readonly string _path;

    public VocabularyStoreTests()
    {
        _tempDir = Directory.CreateTempSubdirectory("clipwell-vocab-").FullName;
        _path = Path.Combine(_tempDir, "vocabulary.json");
    }

    public void Dispose() => Directory.Delete(_tempDir, recursive: true);

    [Fact]
    public void AddNormalizesAndPersists()
    {
        var store = new VocabularyStore(_path);
        var item = store.Add("  Serendipity ", "Safari", "clip-1");

        Assert.NotNull(item);
        Assert.Equal("Serendipity", item!.SourceText);
        Assert.Equal("serendipity", item.NormalizedText);

        var reloaded = new VocabularyStore(_path);
        var persisted = Assert.Single(reloaded.Items);
        Assert.Equal("serendipity", persisted.NormalizedText);
        Assert.Equal("Safari", persisted.SourceApp);
        Assert.Equal("clip-1", persisted.SourceClipId);
    }

    [Fact]
    public void AddRejectsDuplicatesAndEmpty()
    {
        var store = new VocabularyStore(_path);
        Assert.NotNull(store.Add("hello"));
        Assert.Null(store.Add("  HELLO  "));
        Assert.Null(store.Add("   "));
        Assert.Single(store.Items);
    }

    [Fact]
    public void RemoveDeletesById()
    {
        var store = new VocabularyStore(_path);
        var item = store.Add("word")!;
        Assert.True(store.Remove(item.Id));
        Assert.False(store.Remove(item.Id));
        Assert.Empty(store.Items);
    }

    [Fact]
    public void SearchMatchesNormalizedSubstring()
    {
        var store = new VocabularyStore(_path);
        store.Add("Ephemeral");
        store.Add("Serendipity");

        Assert.Single(store.Search("PHEM"));
        Assert.Equal(2, store.Search("").Count);
        Assert.Empty(store.Search("zzz"));
    }

    [Fact]
    public void CorruptFileFallsBackToEmpty()
    {
        File.WriteAllText(_path, "not json");
        var store = new VocabularyStore(_path);
        Assert.Empty(store.Items);
    }
}
