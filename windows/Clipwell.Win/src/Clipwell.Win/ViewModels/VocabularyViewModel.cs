using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Clipwell.Core.Vocabulary;

namespace Clipwell.Win.ViewModels;

public partial class VocabularyViewModel : ObservableObject
{
    private readonly VocabularyStore _store;

    [ObservableProperty]
    private string _searchText = "";

    public ObservableCollection<VocabularyItem> Items { get; } = [];

    public VocabularyViewModel(VocabularyStore store)
    {
        _store = store;
        Refresh();
    }

    partial void OnSearchTextChanged(string value) => Refresh();

    public void Refresh()
    {
        Items.Clear();
        foreach (var item in _store.Search(SearchText))
        {
            Items.Add(item);
        }
    }

    [RelayCommand]
    private void Remove(VocabularyItem item)
    {
        _store.Remove(item.Id);
        Refresh();
    }
}
