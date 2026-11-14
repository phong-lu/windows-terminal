// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#include "pch.h"
#include "TabRowControl.h"

#include "TabRowControl.g.cpp"

using namespace winrt::Windows::ApplicationModel::DataTransfer;

using namespace winrt;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Windows::UI::Text;

namespace winrt
{
    namespace MUX = Microsoft::UI::Xaml;
    namespace WUX = Windows::UI::Xaml;
}

namespace winrt::TerminalApp::implementation
{
    TabRowControl::TabRowControl()
    {
        InitializeComponent();
    }

    void TabRowControl::SetVertical(bool vertical)
    {
        if (_vertical == vertical)
        {
            return;
        }

        const auto tabView = TabView();
        if (!vertical)
        {
            for (const auto& saved : _cornerOverrides)
            {
                if (const auto container = saved.container.get())
                {
                    if (saved.binding)
                    {
                        container.SetBinding(WUX::Controls::Grid::CornerRadiusProperty(), saved.binding);
                    }
                    else
                    {
                        container.CornerRadius(saved.radius);
                    }
                }
            }
            _cornerOverrides.clear();
        }
        if (!_horizontalTemplate)
        {
            tabView.ApplyTemplate();
            _horizontalTemplate = tabView.Template();
        }
        // TabItems normally aliases the internal ListView's Items collection.
        // Detach the items and give TabView a staging vector before replacing
        // that ListView, or the old template will clear the tabs on unload.
        const auto selected = tabView.SelectedItem();
        std::vector<IInspectable> items;
        for (const auto& item : tabView.TabItems())
        {
            items.push_back(item);
        }
        tabView.TabItems().Clear();
        tabView.SetValue(MUX::Controls::TabView::TabItemsProperty(), single_threaded_observable_vector<IInspectable>(std::move(items)));
        _vertical = vertical;
        tabView.Template(vertical ? Resources().Lookup(box_value(L"VerticalTabViewTemplate")).as<WUX::Controls::ControlTemplate>() : _horizontalTemplate);
        tabView.VerticalAlignment(vertical ? WUX::VerticalAlignment::Stretch : WUX::VerticalAlignment::Bottom);
        tabView.ApplyTemplate();
        tabView.SelectedItem(selected);
    }

    void TabRowControl::UpdateTabCorners(const MUX::Controls::TabViewItem& item)
    {
        if (!_vertical)
        {
            return;
        }

        // WinUI versions resolve the tab template's radius resource differently.
        // Set the actual header grid so the bundled runtime also stays square.
        std::vector<WUX::DependencyObject> pending{ item };
        while (!pending.empty())
        {
            const auto node = pending.back();
            pending.pop_back();
            if (const auto container = node.try_as<WUX::Controls::Grid>(); container && container.Name() == L"TabContainer")
            {
                const auto radius = container.CornerRadius();
                if (radius.TopLeft != 0 || radius.TopRight != 0)
                {
                    std::erase_if(_cornerOverrides, [](const auto& saved) { return !saved.container.get(); });
                    if (std::none_of(_cornerOverrides.begin(), _cornerOverrides.end(), [&](const auto& saved) { return saved.container.get() == container; }))
                    {
                        const auto expression = container.GetBindingExpression(WUX::Controls::Grid::CornerRadiusProperty());
                        _cornerOverrides.push_back({ make_weak(container), expression ? expression.ParentBinding() : nullptr, radius });
                    }
                    container.CornerRadius({ 0, 0, radius.BottomRight, radius.BottomLeft });
                }
                return;
            }
            for (auto i = 0; i < WUX::Media::VisualTreeHelper::GetChildrenCount(node); ++i)
            {
                pending.push_back(WUX::Media::VisualTreeHelper::GetChild(node, i));
            }
        }
    }

    // Method Description:
    // - Bound in the Xaml editor to the [+] button.
    // Arguments:
    // <unused>
    void TabRowControl::OnNewTabButtonClick(const IInspectable&, const Controls::SplitButtonClickEventArgs&)
    {
    }

    // Method Description:
    // - Bound in Drag&Drop of the Xaml editor to the [+] button.
    // Arguments:
    // <unused>
    void TabRowControl::OnNewTabButtonDrop(const IInspectable&, const winrt::Windows::UI::Xaml::DragEventArgs&)
    {
    }

    // Method Description:
    // - Bound in Drag-over of the Xaml editor to the [+] button.
    // Allows drop of 'StorageItems' which will be used as StartingDirectory
    // Arguments:
    //  - <unused>
    //  - e: DragEventArgs which hold the items
    void TabRowControl::OnNewTabButtonDragOver(const IInspectable&, const winrt::Windows::UI::Xaml::DragEventArgs& e)
    {
        // We can only handle drag/dropping StorageItems (files).
        // If the format on the clipboard is anything else, returning
        // early here will prevent the drag/drop from doing anything.
        if (!e.DataView().Contains(StandardDataFormats::StorageItems()))
        {
            return;
        }

        // Make sure to set the AcceptedOperation, so that we can later receive the path in the Drop event
        e.AcceptedOperation(DataPackageOperation::Copy);

        const auto modifiers = static_cast<uint32_t>(e.Modifiers());
        if (WI_IsFlagSet(modifiers, static_cast<uint32_t>(DragDrop::DragDropModifiers::Alt)))
        {
            e.DragUIOverride().Caption(RS_(L"DropPathTabSplit/Text"));
        }
        else if (WI_IsFlagSet(modifiers, static_cast<uint32_t>(DragDrop::DragDropModifiers::Shift)))
        {
            e.DragUIOverride().Caption(RS_(L"DropPathTabNewWindow/Text"));
        }
        else
        {
            e.DragUIOverride().Caption(RS_(L"DropPathTabRun/Text"));
        }

        // Sets if the caption is visible
        e.DragUIOverride().IsCaptionVisible(true);
        // Sets if the dragged content is visible
        e.DragUIOverride().IsContentVisible(false);
        // Sets if the glyph is visible
        e.DragUIOverride().IsGlyphVisible(false);
    }
}
