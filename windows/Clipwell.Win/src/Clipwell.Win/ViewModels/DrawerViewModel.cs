using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Core.Pipeline;
using Clipwell.Win.Services;

namespace Clipwell.Win.ViewModels;

public partial class DrawerViewModel : ObservableObject
{
    private readonly ClipRepository _repository;
    private readonly PayloadStore _payloadStore;
    private readonly ClipRestoreService _restoreService;
    private readonly PipelineHost _pipelineHost;

    [ObservableProperty]
    private string _searchText = "";

    [ObservableProperty]
    private ClipFilter _filter = ClipFilter.All;

    [ObservableProperty]
    private string _statusMessage = "";

    public ObservableCollection<ClipItem> Clips { get; } = [];

    /// <summary>Raised after a clip is restored so the window can auto-close.</summary>
    public event EventHandler? ClipRestored;

    public DrawerViewModel(
        ClipRepository repository,
        PayloadStore payloadStore,
        ClipRestoreService restoreService,
        ClipboardMonitorService monitor,
        PipelineHost pipelineHost)
    {
        _repository = repository;
        _payloadStore = payloadStore;
        _restoreService = restoreService;
        _pipelineHost = pipelineHost;
        monitor.ClipCaptured += (_, _) => Refresh();
        pipelineHost.DerivedClipSaved += (_, _) =>
            Application.Current?.Dispatcher.BeginInvoke(Refresh);
        pipelineHost.StageFailed += (_, stage) =>
            Application.Current?.Dispatcher.BeginInvoke(() => StatusMessage = $"{stage.PluginId}: {stage.Message}");
    }

    partial void OnSearchTextChanged(string value) => Refresh();

    partial void OnFilterChanged(ClipFilter value) => Refresh();

    public void Refresh()
    {
        Clips.Clear();
        foreach (var clip in _repository.Fetch(SearchText, Filter))
        {
            Clips.Add(clip);
        }
    }

    [RelayCommand]
    private void Restore(ClipItem clip)
    {
        if (_restoreService.Restore(clip))
        {
            ClipRestored?.Invoke(this, EventArgs.Empty);
        }
    }

    [RelayCommand]
    private void TogglePin(ClipItem clip)
    {
        _repository.SetPinned(clip.Id, !clip.IsPinned);
        Refresh();
    }

    [RelayCommand]
    private void Delete(ClipItem clip)
    {
        _payloadStore.Delete(clip.PayloadPath);
        _repository.Delete(clip.Id);
        Refresh();
    }

    [RelayCommand]
    private void ClearHistory()
    {
        _payloadStore.DeleteAll(_repository.PayloadPaths());
        _repository.Clear();
        Refresh();
    }

    [RelayCommand]
    private void SetFilter(string filterName) =>
        Filter = Enum.TryParse<ClipFilter>(filterName, ignoreCase: true, out var parsed) ? parsed : ClipFilter.All;

    [RelayCommand]
    private Task Translate(ClipItem clip) => RunManualAsync(clip, BuiltInPluginIds.Translate);

    [RelayCommand]
    private Task Summarize(ClipItem clip) => RunManualAsync(clip, BuiltInPluginIds.Summarize);

    [RelayCommand]
    private Task Rewrite(ClipItem clip) => RunManualAsync(clip, BuiltInPluginIds.Rewrite);

    [RelayCommand]
    private Task RunOcr(ClipItem clip) => RunManualAsync(clip, BuiltInPluginIds.ImageOcr);

    [RelayCommand]
    private Task AddToVocabulary(ClipItem clip) => RunManualAsync(clip, BuiltInPluginIds.AddToVocabulary);

    private async Task RunManualAsync(ClipItem clip, string pluginId)
    {
        StatusMessage = "Working...";
        var result = await _pipelineHost.RunManualAsync(clip, pluginId);
        var failed = result.StageResults.FirstOrDefault(stage => stage.Status == ClipPipelineStageStatus.Failed);
        StatusMessage = failed?.Message ?? "";
        Refresh();
    }
}
