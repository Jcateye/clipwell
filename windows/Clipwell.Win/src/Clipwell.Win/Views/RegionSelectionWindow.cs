using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Clipwell.Win.Views;

/// <summary>
/// Full-virtual-screen overlay for picking a screenshot region: dim background,
/// rubber-band rectangle while dragging, Esc cancels. Returns the region in
/// physical screen coordinates (for Graphics.CopyFromScreen).
/// </summary>
public sealed class RegionSelectionWindow : Window
{
    private readonly Canvas _canvas;
    private readonly Rectangle _rubberBand;
    private Point _origin;
    private bool _dragging;
    private Rect? _selection;

    private RegionSelectionWindow()
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        AllowsTransparency = true;
        Background = new SolidColorBrush(Color.FromArgb(0x50, 0, 0, 0));
        Cursor = Cursors.Cross;

        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;

        _rubberBand = new Rectangle
        {
            Stroke = Brushes.White,
            StrokeThickness = 1,
            Fill = new SolidColorBrush(Color.FromArgb(0x20, 0xFF, 0xFF, 0xFF)),
            Visibility = Visibility.Collapsed,
        };
        _canvas = new Canvas();
        _canvas.Children.Add(_rubberBand);
        Content = _canvas;

        MouseLeftButtonDown += OnMouseDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseUp;
        KeyDown += (_, e) =>
        {
            if (e.Key == Key.Escape)
            {
                _selection = null;
                Close();
            }
        };
    }

    /// <summary>Shows the overlay modally; null when the user cancels.</summary>
    public static Rect? SelectRegion()
    {
        var window = new RegionSelectionWindow();
        window.ShowDialog();
        return window._selection;
    }

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        _origin = e.GetPosition(_canvas);
        _dragging = true;
        _rubberBand.Visibility = Visibility.Visible;
        CaptureMouse();
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }
        var current = e.GetPosition(_canvas);
        var rect = new Rect(_origin, current);
        Canvas.SetLeft(_rubberBand, rect.X);
        Canvas.SetTop(_rubberBand, rect.Y);
        _rubberBand.Width = rect.Width;
        _rubberBand.Height = rect.Height;
    }

    private void OnMouseUp(object sender, MouseButtonEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }
        _dragging = false;
        ReleaseMouseCapture();

        var windowRect = new Rect(_origin, e.GetPosition(_canvas));
        // Convert from window-local DIPs to physical screen pixels (handles DPI scaling).
        var topLeft = PointToScreen(new Point(windowRect.X, windowRect.Y));
        var bottomRight = PointToScreen(new Point(windowRect.Right, windowRect.Bottom));
        _selection = new Rect(topLeft, bottomRight);
        Close();
    }
}
