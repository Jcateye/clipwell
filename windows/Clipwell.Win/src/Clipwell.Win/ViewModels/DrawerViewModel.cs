using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Clipwell.Core.Data;
using Clipwell.Core.Models;
using Clipwell.Win.Services;

namespace Clipwell.Win.ViewModels;

public partial class DrawerViewModel : ObservableObject
{
    private readonly ClipRepository _repository;
    private readonly PayloadStore _payloadStore;
    private readonly ClipRestoreService _restoreService;

    [ObservableProperty]
    private string _searchText = "";

    [ObservableProperty]
    private ClipFilter _filter = ClipFilter.All;

    public ObservableCollection<ClipItem> Clips { get; } = [];

    /// <summary>Raised after a clip is restored so the window can auto-close.</summary>
    public event EventHandler? ClipRestored;

    public DrawerViewModel(
        ClipRepository repository,
        PayloadStore payloadStore,
        ClipRestoreService restoreService,
        ClipboardMonitorService monitor)
    {
        _repository = repository;
        _payloadStore = payloadStore;
        _restoreService = restoreService;
        monitor.ClipCaptured += (_, _) => Refresh();
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
}
