using System.Windows.Threading;
using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Core.Settings;
using Clipwell.Win.Interop;

namespace Clipwell.Win.Services;

/// <summary>
/// Listens for clipboard changes (via MessageWindow), debounces duplicate notifications,
/// applies pause / ignored-app / self-copy / consecutive-dedup rules, then persists
/// the clip and its payload and trims history to the configured limit.
/// </summary>
public sealed class ClipboardMonitorService
{
    private static readonly TimeSpan DebounceInterval = TimeSpan.FromMilliseconds(100);

    private readonly ClipRepository _repository;
    private readonly PayloadStore _payloadStore;
    private readonly SettingsStore _settings;
    private readonly ClipboardReader _reader;
    private readonly ForegroundAppService _foregroundApp;
    private readonly DispatcherTimer _debounceTimer;

    /// <summary>Hash of content this app itself just restored to the clipboard; skipped once.</summary>
    private string? _selfCopyHash;

    public event EventHandler<ClipItem>? ClipCaptured;

    public ClipboardMonitorService(
        MessageWindow messageWindow,
        ClipRepository repository,
        PayloadStore payloadStore,
        SettingsStore settings,
        ClipboardReader reader,
        ForegroundAppService foregroundApp)
    {
        _repository = repository;
        _payloadStore = payloadStore;
        _settings = settings;
        _reader = reader;
        _foregroundApp = foregroundApp;

        _debounceTimer = new DispatcherTimer { Interval = DebounceInterval };
        _debounceTimer.Tick += (_, _) =>
        {
            _debounceTimer.Stop();
            Capture();
        };

        messageWindow.ClipboardUpdated += (_, _) =>
        {
            // Many apps fire WM_CLIPBOARDUPDATE multiple times per copy; coalesce.
            _debounceTimer.Stop();
            _debounceTimer.Start();
        };
        messageWindow.StartClipboardListener();
    }

    public void MarkSelfCopy(string contentHash) => _selfCopyHash = contentHash;

    private void Capture()
    {
        if (_settings.Current.MonitoringPaused)
        {
            return;
        }

        var sourceApp = _foregroundApp.ForegroundAppName();
        if (_settings.ShouldIgnoreApp(sourceApp))
        {
            return;
        }

        var parsed = _reader.Read(_settings.IgnoredFileExtensions);
        if (parsed is null)
        {
            return;
        }

        if (_selfCopyHash == parsed.ContentHash)
        {
            _selfCopyHash = null;
            return;
        }

        if (_settings.Current.DedupConsecutiveEnabled &&
            _repository.LatestClip()?.ContentHash == parsed.ContentHash)
        {
            return;
        }

        var clip = ClipItem.CreateNew(
            parsed.Type,
            parsed.PlainText,
            payloadPath: null,
            sourceApp,
            parsed.ContentHash);

        if (parsed.PayloadData is { } payload && parsed.PayloadExtension is { } extension)
        {
            var payloadPath = _payloadStore.Save(clip.Id, extension, payload);
            clip = clip with { PayloadPath = payloadPath };
        }

        _repository.Insert(clip);
        Trim();
        ClipCaptured?.Invoke(this, clip);
    }

    private void Trim()
    {
        var maxCount = _settings.Current.HistoryMaxCount;
        _payloadStore.DeleteAll(_repository.PayloadPathsBeyondLimit(maxCount));
        _repository.Prune(maxCount);
    }
}
