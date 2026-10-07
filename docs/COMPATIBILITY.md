# macOS Compatibility Guide

## Overview

SenseFlow supports macOS 14.0 (Sonoma) and later. The app uses modern SwiftUI APIs including `.snappy()` animations and Settings scene, which require macOS 14.0 as the minimum version.

## Supported Versions

| macOS Version | Support Status | Notes |
|---------------|----------------|-------|
| macOS 26+ (Tahoe) | ✅ Full Support | Liquid Glass effects, all features |
| macOS 14-25 (Sonoma-Sequoia) | ✅ Full Support | PhaseAnimator, thin material fallback |
| macOS 13 and earlier | ❌ Not Supported | Requires .snappy/.smooth animations (macOS 14+) |

## Visual Differences by Version

### macOS 26+ (Tahoe)
- **Glass Effects**: Liquid Glass with dynamic blur (`.glassEffect(.regular)`)
- **Animations**: PhaseAnimator with `.snappy()` and `.smooth()`
- **Material**: Native Liquid Glass for main panel

### macOS 14-25 (Sonoma through Sequoia)
- **Glass Effects**: Thin material with static blur (`.thinMaterial`)
- **Animations**: PhaseAnimator with `.snappy()` and `.smooth()`
- **Material**: Standard thin material

## Feature Compatibility

All core features work identically across all supported macOS versions:

✅ **Fully Compatible:**
- Clipboard monitoring and capture
- Global hotkey (Cmd+Option+V)
- Search functionality (text + OCR)
- Auto-paste feature
- Settings panel (NavigationSplitView)
- Prompt Tools
- Delete functionality
- Launch at login

⚠️ **Visual Differences Only:**
- Main panel background (Liquid Glass vs thin material)
- Card backgrounds (Liquid Glass vs thin material)
- Card entrance animations (PhaseAnimator vs .animation())

## Technical Implementation

### Compatibility Layer

The app uses a compatibility layer to automatically select appropriate APIs:

```swift
// Glass Effect Compatibility
extension View {
    func compatibleGlassEffect(cornerRadius: CGFloat = 20) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// Animation Compatibility
struct CompatiblePhaseAnimator<Phase, Content: View>: View {
    var body: some View {
        if #available(macOS 14, *) {
            PhaseAnimator(phases) { phase in content(phase) }
        } else {
            // Not used - macOS 14+ required
            content(currentPhase)
        }
    }
}
```

### API Mapping

| Feature | macOS 26+ | macOS 14-25 |
|---------|-----------|-------------|
| Glass Effect | `.glassEffect()` | `.thinMaterial` |
| Card Animation | `PhaseAnimator + .snappy()` | `PhaseAnimator + .snappy()` |
| Navigation | `NavigationSplitView` | `NavigationSplitView` |
| Settings | `Settings Scene` | `Settings Scene` |

## Performance

Performance targets are consistent across all supported versions:

- **CPU Usage**: < 0.1% during monitoring
- **Animation Frame Rate**: 60fps
- **Database Queries**: < 50ms
- **Memory Usage**: Reasonable with 200+ items

## Troubleshooting

### App won't launch on macOS 13 or earlier

**Symptom**: App crashes or shows "requires macOS 14" error

**Solution**:
1. Verify you're running macOS 14.0 or later: `sw_vers`
2. The app requires macOS 14.0 (Sonoma) minimum due to:
   - `.snappy()` and `.smooth()` animation APIs
   - Settings Scene with modern SwiftUI features
   - PhaseAnimator for card animations
3. Upgrade to macOS 14.0 or later to use SenseFlow

### Visual effects look different than screenshots

**Expected Behavior**:
- macOS 26+: Liquid Glass with dynamic blur
- macOS 14-25: Thin material with static blur

This is intentional - the app automatically uses the best available visual effects for your macOS version.

## Building from Source

### Requirements

- Xcode 15.0+
- macOS 14.0+ SDK
- Swift 5.9+

### Build Configuration

The deployment target is set to macOS 14.0:

```bash
# Verify deployment target
xcodebuild -project SenseFlow.xcodeproj -showBuildSettings | grep MACOSX_DEPLOYMENT_TARGET
# Should show: MACOSX_DEPLOYMENT_TARGET = 14.0
```

### Testing on Older Versions

To test on macOS 14-15:

1. Create VM with target macOS version
2. Install Xcode on VM
3. Build and run from Xcode
4. Verify all features work correctly
5. Check visual quality of fallback materials

## Migration Notes

### Upgrading from v0.4 (macOS 26+ only)

No data migration needed. The app will automatically:
- Use appropriate APIs for your macOS version
- Maintain all settings and history
- Apply visual fallbacks transparently

### Known Limitations

- **macOS 14-25**: No Liquid Glass (uses thin material)
- **macOS 13 and earlier**: Not supported (requires .snappy/.smooth animations)

## Support

For issues specific to older macOS versions:

1. Check this compatibility guide first
2. Verify your macOS version: `sw_vers`
3. Report issues with macOS version in bug report
4. Include screenshots showing visual differences if relevant
