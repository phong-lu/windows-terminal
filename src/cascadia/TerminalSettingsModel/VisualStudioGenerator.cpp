// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

#include "pch.h"
#include "DynamicProfileUtils.h"
#include "VisualStudioGenerator.h"
#include "VsDevCmdGenerator.h"
#include "VsDevShellGenerator.h"

using namespace winrt::Microsoft::Terminal::Settings::Model;

std::wstring_view VisualStudioGenerator::Namespace{ L"Windows.Terminal.VisualStudio" };
static constexpr std::wstring_view IconPath{ L"ms-appx:///ProfileGeneratorIcons/VisualStudio.png" };

std::wstring_view VisualStudioGenerator::GetNamespace() const noexcept
{
    return Namespace;
}

std::wstring_view VisualStudioGenerator::GetDisplayName() const noexcept
{
    return RS_(L"VisualStudioGeneratorDisplayName");
}

std::wstring_view VisualStudioGenerator::GetIcon() const noexcept
{
    return IconPath;
}

void VisualStudioGenerator::GenerateProfiles(std::vector<winrt::com_ptr<implementation::Profile>>& profiles) const
{
    const auto instances = VsSetupConfiguration::QueryInstances();

    VsDevCmdGenerator devCmdGenerator;
    VsDevShellGenerator devShellGenerator;

    // Instances are ordered from latest to oldest. Hide all but the profiles for the latest instance.
    auto hidden = false;
    for (const auto& instance : instances)
    {
        // Prefer the original VS 18 instance over the duplicate installation.
        // Keep the normal latest-instance behavior for other Visual Studio versions.
        const auto suffix = instance.GetProfileNameSuffix();
        if (suffix == L"18 (2)")
        {
            continue;
        }
        const auto instanceHidden = suffix == L"18" ? false : hidden;
        devCmdGenerator.GenerateProfiles(instance, instanceHidden, profiles);
        devShellGenerator.GenerateProfiles(instance, instanceHidden, profiles);
        hidden = true;
    }
}
