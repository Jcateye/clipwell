using System.Windows;
using System.Windows.Controls;
using Clipwell.Core.Models;

namespace Clipwell.Win.Views;

/// <summary>Picks the list item template: image preview for raw media payloads, file row for paths, text otherwise.</summary>
public sealed class ClipItemTemplateSelector : DataTemplateSelector
{
    public DataTemplate? TextTemplate { get; set; }
    public DataTemplate? ImageTemplate { get; set; }
    public DataTemplate? FileTemplate { get; set; }

    public override DataTemplate? SelectTemplate(object item, DependencyObject container)
    {
        if (item is not ClipItem clip)
        {
            return base.SelectTemplate(item, container);
        }
        return clip.Type switch
        {
            ClipType.Media when clip.PayloadPath is not null => ImageTemplate,
            ClipType.Media or ClipType.Document => FileTemplate,
            _ => TextTemplate,
        };
    }
}
