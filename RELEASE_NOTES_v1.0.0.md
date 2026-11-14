# 1.0.0

First stable release of this fork of [Microsoft Windows Terminal](https://github.com/microsoft/terminal). This is a release of the fork, independently maintained and not an official Microsoft release.

## Features and changes

- Choose top, left, or right tab placement in Appearance settings or with `tabLocation` in settings.json.
- Display tabs in a left sidebar in Quake mode, including while focus mode is active.
- Add a default Git Bash profile with its own icon and MesloLGS NF font. Git for Windows must be installed at the standard location for this profile to launch.
- Bundle MesloLGS NF in regular, bold, italic, and bold italic styles, without requiring a system font installation.
- Adjust Visual Studio profile generation to skip the duplicate `18 (2)` instance and keep the original `18` instance visible.
- Provide setup installers and portable ZIP packages for x64 and ARM64. Publishing the release starts the build workflow; download assets will appear after the builds finish successfully.
- Set the default installer destination to `%LOCALAPPDATA%\Programs\Windows Terminal` and provide regular and Quake mode Start menu shortcuts.

## Acknowledgments and disclosure

Based on Microsoft Windows Terminal and the work of its contributors. Existing licenses and third-party notices continue to apply.

AI assistance was used to prepare these release notes and assist with release preparation, with maintainer permission.
