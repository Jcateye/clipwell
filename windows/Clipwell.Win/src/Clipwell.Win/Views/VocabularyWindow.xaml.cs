using System.Windows;
using Clipwell.Win.ViewModels;

namespace Clipwell.Win.Views;

public partial class VocabularyWindow : Window
{
    public VocabularyWindow(VocabularyViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        viewModel.Refresh();
    }
}
