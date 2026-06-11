using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Xunit;

namespace Clipwell.Core.Tests;

public sealed class ClipRepositoryTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ClipRepository _repository;

    public ClipRepositoryTests()
    {
        _tempDir = Directory.CreateTempSubdirectory("clipwell-tests-").FullName;
        _repository = new ClipRepository(Path.Combine(_tempDir, "clips.sqlite"));
    }

    public void Dispose()
    {
        _repository.Dispose();
        Directory.Delete(_tempDir, recursive: true);
    }

    private static ClipItem MakeClip(
        string text,
        ClipType type = ClipType.Text,
        bool isPinned = false,
        DateTimeOffset? createdAt = null) =>
        new(
            Id: Guid.NewGuid().ToString(),
            CreatedAt: createdAt ?? DateTimeOffset.UtcNow,
            Type: type,
            PlainText: text,
            PayloadPath: null,
            SourceApp: "TestApp",
            IsPinned: isPinned,
            ContentHash: Clipwell.Core.Services.ContentHasher.Hash(text),
            Origin: ClipOrigin.Original,
            DerivedFromClipId: null);

    [Fact]
    public void InsertAndFetchRoundTrips()
    {
        var clip = MakeClip("hello world");
        _repository.Insert(clip);

        var fetched = Assert.Single(_repository.Fetch());
        Assert.Equal(clip.Id, fetched.Id);
        Assert.Equal("hello world", fetched.PlainText);
        Assert.Equal(ClipType.Text, fetched.Type);
        Assert.Equal(ClipOrigin.Original, fetched.Origin);
        Assert.Equal("TestApp", fetched.SourceApp);
        Assert.Equal(clip.ContentHash, fetched.ContentHash);
        Assert.Equal(clip.CreatedAt.ToUnixTimeMilliseconds(), fetched.CreatedAt.ToUnixTimeMilliseconds());
    }

    [Fact]
    public void SearchMatchesPlainTextSubstring()
    {
        _repository.Insert(MakeClip("alpha beta"));
        _repository.Insert(MakeClip("gamma delta"));

        var results = _repository.Fetch(search: "beta");
        Assert.Equal("alpha beta", Assert.Single(results).PlainText);
    }

    [Fact]
    public void FilterSelectsTextLikeTypes()
    {
        _repository.Insert(MakeClip("plain"));
        _repository.Insert(MakeClip("<b>rich</b>", ClipType.Html));
        _repository.Insert(MakeClip("/tmp/movie.mp4", ClipType.Media));
        _repository.Insert(MakeClip("/tmp/file.pdf", ClipType.Document));

        Assert.Equal(2, _repository.Fetch(filter: ClipFilter.Text).Count);
        Assert.Single(_repository.Fetch(filter: ClipFilter.Media));
        Assert.Single(_repository.Fetch(filter: ClipFilter.Document));
        Assert.Equal(4, _repository.Fetch(filter: ClipFilter.All).Count);
    }

    [Fact]
    public void FetchOrdersPinnedFirstThenNewest()
    {
        var baseTime = DateTimeOffset.UtcNow;
        _repository.Insert(MakeClip("oldest", createdAt: baseTime.AddMinutes(-3)));
        _repository.Insert(MakeClip("pinned-old", isPinned: true, createdAt: baseTime.AddMinutes(-2)));
        _repository.Insert(MakeClip("newest", createdAt: baseTime));

        var results = _repository.Fetch();
        Assert.Equal(["pinned-old", "newest", "oldest"], results.Select(clip => clip.PlainText));
    }

    [Fact]
    public void PruneKeepsPinnedAndNewest()
    {
        var baseTime = DateTimeOffset.UtcNow;
        _repository.Insert(MakeClip("pinned", isPinned: true, createdAt: baseTime.AddMinutes(-10)));
        for (var i = 0; i < 5; i++)
        {
            _repository.Insert(MakeClip($"clip-{i}", createdAt: baseTime.AddMinutes(-5 + i)));
        }

        _repository.Prune(maxCount: 2);

        var remaining = _repository.Fetch();
        Assert.Equal(3, remaining.Count);
        Assert.Contains(remaining, clip => clip.PlainText == "pinned");
        Assert.Contains(remaining, clip => clip.PlainText == "clip-4");
        Assert.Contains(remaining, clip => clip.PlainText == "clip-3");
    }

    [Fact]
    public void LatestClipReturnsNewestForDedup()
    {
        _repository.Insert(MakeClip("first", createdAt: DateTimeOffset.UtcNow.AddMinutes(-1)));
        var latest = MakeClip("second");
        _repository.Insert(latest);

        Assert.Equal(latest.ContentHash, _repository.LatestClip()?.ContentHash);
    }

    [Fact]
    public void SetPinnedUpdatesRow()
    {
        var clip = MakeClip("pin me");
        _repository.Insert(clip);
        _repository.SetPinned(clip.Id, true);

        Assert.True(Assert.Single(_repository.Fetch()).IsPinned);
    }

    [Fact]
    public void DeleteAndClearRemoveRows()
    {
        var clip = MakeClip("bye");
        _repository.Insert(clip);
        _repository.Delete(clip.Id);
        Assert.Empty(_repository.Fetch());

        _repository.Insert(MakeClip("a"));
        _repository.Insert(MakeClip("b"));
        _repository.Clear();
        Assert.Empty(_repository.Fetch());
    }

    [Fact]
    public void PayloadPathsBeyondLimitReturnsOnlyPrunablePayloads()
    {
        var baseTime = DateTimeOffset.UtcNow;
        var old = MakeClip("old", ClipType.Media, createdAt: baseTime.AddMinutes(-2)) with { PayloadPath = "/tmp/old.png" };
        var fresh = MakeClip("new", ClipType.Media, createdAt: baseTime) with { PayloadPath = "/tmp/new.png" };
        _repository.Insert(old);
        _repository.Insert(fresh);

        Assert.Equal(["/tmp/old.png"], _repository.PayloadPathsBeyondLimit(maxCount: 1));
    }
}
