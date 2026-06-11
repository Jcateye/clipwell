using System.Net.Http;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Clipwell.Core.AI;
using Clipwell.Core.Pipeline;
using Clipwell.Core.Settings;
using Clipwell.Win.Services;

namespace Clipwell.Win.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsStore _settings;
    private readonly StartupService _startupService;
    private readonly ITextAIService _aiService;

    [ObservableProperty] private int _historyMaxCount;
    [ObservableProperty] private bool _monitoringPaused;
    [ObservableProperty] private bool _launchAtLoginEnabled;
    [ObservableProperty] private bool _dedupConsecutiveEnabled;
    [ObservableProperty] private bool _autoCloseDrawerEnabled;
    [ObservableProperty] private bool _autoPasteEnabled;
    [ObservableProperty] private string _ignoredAppListText = "";
    [ObservableProperty] private string _ignoredFileExtensionsText = "";
    [ObservableProperty] private string _drawerEdge = "right";
    [ObservableProperty] private double _drawerWidth = 420;
    [ObservableProperty] private string _hotkeyDisplayText = "";
    [ObservableProperty] private string _hotkeyStatusMessage = "";

    // Pro / AI
    [ObservableProperty] private bool _proEnabled;
    [ObservableProperty] private bool _proAIEnabled;
    [ObservableProperty] private string _proAIBaseUrl = "";
    [ObservableProperty] private string _proAIApiKey = "";
    [ObservableProperty] private string _proAIModel = "";
    [ObservableProperty] private string _proTranslationTargetLanguage = "";
    [ObservableProperty] private string _proOcrLanguagesText = "";
    [ObservableProperty] private bool _autoOcrImagesEnabled;
    [ObservableProperty] private bool _proVocabularyEnabled;
    [ObservableProperty] private string _aiConnectionStatus = "";

    public SettingsViewModel(
        SettingsStore settings,
        StartupService startupService,
        HotkeyService hotkeyService,
        ITextAIService aiService)
    {
        _settings = settings;
        _startupService = startupService;
        _aiService = aiService;
        hotkeyService.RegistrationFailed += (_, hotkey) =>
            HotkeyStatusMessage = $"Hotkey {hotkey.DisplayText} is in use by another app.";
        LoadFromSettings();
    }

    private void LoadFromSettings()
    {
        var current = _settings.Current;
        HistoryMaxCount = current.HistoryMaxCount;
        MonitoringPaused = current.MonitoringPaused;
        LaunchAtLoginEnabled = _startupService.IsEnabled;
        DedupConsecutiveEnabled = current.DedupConsecutiveEnabled;
        AutoCloseDrawerEnabled = current.AutoCloseDrawerEnabled;
        AutoPasteEnabled = current.AutoPasteEnabled;
        IgnoredAppListText = current.IgnoredAppListText;
        IgnoredFileExtensionsText = current.IgnoredFileExtensionsText;
        DrawerEdge = current.DrawerEdge;
        DrawerWidth = current.DrawerWidth;
        HotkeyDisplayText = current.ToggleDrawerHotkey.DisplayText;
        ProEnabled = current.ProEnabled;
        ProAIEnabled = current.ProAIEnabled;
        ProAIBaseUrl = current.ProAIBaseUrl;
        ProAIApiKey = current.ProAIApiKey;
        ProAIModel = current.ProAIModel;
        ProTranslationTargetLanguage = current.ProTranslationTargetLanguage;
        ProOcrLanguagesText = current.ProOcrLanguagesText;
        AutoOcrImagesEnabled = current.AutoOcrImagesEnabled;
        ProVocabularyEnabled = current.ProVocabularyEnabled;
    }

    [RelayCommand]
    private void Save()
    {
        _settings.Update(settings =>
        {
            settings.HistoryMaxCount = Math.Max(1, HistoryMaxCount);
            settings.MonitoringPaused = MonitoringPaused;
            settings.LaunchAtLoginEnabled = LaunchAtLoginEnabled;
            settings.DedupConsecutiveEnabled = DedupConsecutiveEnabled;
            settings.AutoCloseDrawerEnabled = AutoCloseDrawerEnabled;
            settings.AutoPasteEnabled = AutoPasteEnabled;
            settings.IgnoredAppListText = IgnoredAppListText;
            settings.IgnoredFileExtensionsText = IgnoredFileExtensionsText;
            settings.DrawerEdge = DrawerEdge;
            settings.DrawerWidth = DrawerWidth;
            settings.ProEnabled = ProEnabled;
            settings.ProAIEnabled = ProAIEnabled;
            settings.ProAIBaseUrl = ProAIBaseUrl;
            settings.ProAIApiKey = ProAIApiKey;
            settings.ProAIModel = ProAIModel;
            settings.ProTranslationTargetLanguage = ProTranslationTargetLanguage;
            settings.ProOcrLanguagesText = ProOcrLanguagesText;
            settings.AutoOcrImagesEnabled = AutoOcrImagesEnabled;
            settings.ProVocabularyEnabled = ProVocabularyEnabled;

            // Auto-OCR maps onto the post-capture pipeline's image-OCR stage, like on macOS.
            var ocrStage = settings.PostCapturePipelineStages
                .FirstOrDefault(stage => stage.PluginId == BuiltInPluginIds.ImageOcr);
            if (ocrStage is not null)
            {
                ocrStage.Enabled = AutoOcrImagesEnabled;
            }
        });
        _startupService.SetEnabled(LaunchAtLoginEnabled);
        HotkeyStatusMessage = "";
    }

    [RelayCommand]
    private async Task TestAIConnection()
    {
        AiConnectionStatus = "Testing...";
        try
        {
            var service = new OpenAICompatibleTextAIService(
                () => new OpenAICompatibleConfig(ProAIBaseUrl, ProAIApiKey, ProAIModel));
            await service.ValidateConnectionAsync();
            AiConnectionStatus = "Connection OK";
        }
        catch (Exception ex) when (ex is TextAIException or HttpRequestException or TaskCanceledException)
        {
            AiConnectionStatus = ex.Message;
        }
    }

    public void SetHotkey(HotkeyDefinition hotkey)
    {
        _settings.Update(settings => settings.ToggleDrawerHotkey = hotkey);
        HotkeyDisplayText = hotkey.DisplayText;
    }
}
