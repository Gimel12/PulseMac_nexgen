# PulseMac

PulseMac is a native macOS system-control dashboard built with SwiftUI. It shows what is using your CPU, memory, disk, and network ports, then gives you explicit controls to stop processes and recover storage safely.

![PulseMac dashboard](docs/PulseMac-Preview.png)

## Features

- Live CPU, memory, compressed-memory, swap, and disk monitoring
- Searchable process list sorted by CPU, memory, or name
- Graceful stop and separately confirmed force quit
- Detection of TCP services listening on local ports
- One-click opening of localhost services
- Downloads, Trash, and inactive-cache storage analysis
- Recoverable cleanup that moves eligible caches to Trash
- Menu-bar status display
- Clear labeling of user and system processes

## Requirements

- macOS 14 or newer
- Xcode 16 or newer for source builds
- The included release build targets Apple Silicon

## Build from source

```bash
swift build
```

To create a release-mode `.app` and ZIP:

```bash
bash scripts/build-release.sh
```

The finished files are written to `dist/`.

## Safety model

- PID 0, PID 1, and PulseMac itself are protected.
- macOS permissions are always respected.
- Stop, force-quit, and cleanup actions require confirmation.
- Cache cleanup only includes top-level application cache folders where nothing inside has been modified for at least 30 days.
- Cleanup moves files to Trash instead of permanently deleting them.

## Distribution note

The downloadable build is ad-hoc signed for testing. macOS may require **System Settings → Privacy & Security → Open Anyway** the first time it is opened. Public distribution without this warning requires signing with an Apple Developer ID and Apple notarization.
