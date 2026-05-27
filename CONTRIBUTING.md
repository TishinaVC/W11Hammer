# Contributing to W11LatencyFix

Thank you for your interest in contributing! This project focuses on **100% safe** Windows 11 optimizations.

## Safety Requirements

All contributions must follow these safety rules:

- ❌ **NO** BCD/boot configuration changes
- ❌ **NO** Windows services disabled
- ❌ **NO** Windows features removed
- ❌ **NO** scheduled tasks or persistence
- ❌ **NO** security settings modified
- ❌ **NO** destructive operations

✅ **ONLY** safe, reversible registry changes
✅ **ONLY** HKCU (user preferences) or safe HKLM parameters

## What Makes a Good Contribution

- **Non-controversial**: Something most users would want
- **Safe**: Cannot damage system or prevent boot
- **Reversible**: Must be undoable via registry
- **Tested**: Verified on Windows 10/11
- **Documented**: Clear description of what it does

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Update documentation
5. Submit a pull request with detailed description

## Code Style

- Use the existing `Set-SafeRegValue` function
- Include descriptive comments
- Follow existing section naming convention
- Add to appropriate category section

## Questions?

Open an issue for discussion before major changes.
