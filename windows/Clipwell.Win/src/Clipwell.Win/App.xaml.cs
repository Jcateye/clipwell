using System.Windows;
using Clipwell.Core.AI;
using Clipwell.Core.Data;
using Clipwell.Core.Pipeline;
using Clipwell.Core.Settings;
using Clipwell.Core.Vocabulary;
using Clipwell.Win.Interop;
using Clipwell.Win.Services;
using Clipwell.Win.ViewModels;
using Clipwell.Win.Views;

namespace Clipwell.Win;

/// <summary>
/// Composition root. Wires storage, clipboard monitoring, hotkeys, pipeline, tray, and windows.
/// A named mutex enforces a single running instance.
/// </summary>
public partial class App : Application
{
    private Mutex? _singleInstanceMutex;
    private MessageWindow? _messageWindow;
    private HotkeyService? _hotkeyService;
    private TrayService? _trayService;
    private ClipRepository? _repository;
    private DrawerWindow? _drawerWindow;
    private SettingsWindow? _settingsWindow;
    private SettingsViewModel? _settingsViewModel;
    private VocabularyWindow? _vocabularyWindow;
    private VocabularyStore? _vocabularyStore;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstanceMutex = new Mutex(initiallyOwned: true, "Clipwell.Win.SingleInstance", out var createdNew);
        if (!createdNew)
        {
            Shutdown();
            return;
        }

        var paths = new AppPaths();
        var settings = new SettingsStore(paths.SettingsPath);
        _repository = new ClipRepository(paths.DatabasePath);
        var payloadStore = new PayloadStore(paths.PayloadsDirectory);
        _vocabularyStore = new VocabularyStore(paths.VocabularyPath);

        // Pro services and pipeline plugins.
        var aiService = new OpenAICompatibleTextAIService(() => new OpenAICompatibleConfig(
            settings.Current.ProAIBaseUrl, settings.Current.ProAIApiKey, settings.Current.ProAIModel));
        var ocrService = new WindowsOcrService(() => settings.Current.ProOcrLanguagesText
            .Split([',', ';', ' ', '\n', '\t'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        var pipelineHost = new PipelineHost(_repository,
        [
            new ImageOcrPlugin(ocrService),
            new TranslatePlugin(aiService, () => settings.Current.ProTranslationTargetLanguage),
            new SummarizePlugin(aiService),
            new RewritePlugin(aiService),
            new AddToVocabularyPlugin(_vocabularyStore),
        ]);

        _messageWindow = new MessageWindow();
        var monitor = new ClipboardMonitorService(
            _messageWindow, _repository, payloadStore, settings,
            new ClipboardReader(), new ForegroundAppService());
        monitor.ClipCaptured += (_, clip) =>
        {
            if (settings.Current.ProEnabled)
            {
                _ = Task.Run(() => pipelineHost.RunPostCaptureAsync(clip, settings.Current.PostCapturePipelineStages));
            }
        };
        var restoreService = new ClipRestoreService(payloadStore, monitor);

        var drawerViewModel = new DrawerViewModel(_repository, payloadStore, restoreService, monitor, pipelineHost);
        _drawerWindow = new DrawerWindow(drawerViewModel, settings);

        var screenshotOcr = new ScreenshotOcrService(_repository, payloadStore, ocrService);
        screenshotOcr.ClipSaved += (_, _) => Dispatcher.BeginInvoke(drawerViewModel.Refresh);

        _hotkeyService = new HotkeyService(_messageWindow, settings);
        _hotkeyService.ToggleDrawerRequested += (_, _) => _drawerWindow.Toggle();
        _hotkeyService.ScreenshotOcrRequested += async (_, _) =>
        {
            if (settings.Current.ProEnabled)
            {
                await screenshotOcr.CaptureAndRecognizeAsync();
            }
        };

        var startupService = new StartupService();
        _settingsViewModel = new SettingsViewModel(settings, startupService, _hotkeyService, aiService);

        _trayService = new TrayService(
            settings,
            toggleDrawer: () => _drawerWindow.Toggle(),
            openSettings: ShowSettingsWindow,
            openVocabulary: ShowVocabularyWindow,
            quit: Shutdown);
    }

    private void ShowSettingsWindow()
    {
        if (_settingsWindow is { IsLoaded: true })
        {
            _settingsWindow.Activate();
            return;
        }
        _settingsWindow = new SettingsWindow(_settingsViewModel!);
        _settingsWindow.Show();
    }

    private void ShowVocabularyWindow()
    {
        if (_vocabularyWindow is { IsLoaded: true })
        {
            _vocabularyWindow.Activate();
            return;
        }
        _vocabularyWindow = new VocabularyWindow(new VocabularyViewModel(_vocabularyStore!));
        _vocabularyWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayService?.Dispose();
        _hotkeyService?.Dispose();
        _messageWindow?.Dispose();
        _repository?.Dispose();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
