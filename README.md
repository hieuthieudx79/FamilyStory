# Family Story

**Keep Their Voices Forever.**

A private, audio-first family memory archive for iOS. Family Story is local-first, offline-first, and privacy-first.

## Tier 1 MVP

- SwiftUI native app; iOS 17+ baseline.
- Local archive without account registration or backend.
- Record, pause/resume, save and play original audio.
- Editable story title, notes and date.
- Local chronological memory library and metadata search.
- Capability-gated transcription / on-device AI adapters; neither is required for recording.
- Export/import are staged for the next implementation slice.

## Visual direction — Quiet nostalgia

A restrained archival palette: warm paper, aged linen, sepia ink, muted olive and terracotta accents. Editorial typography, generous whitespace, fine rules, softly rounded surfaces. Avoid bright gradients, glossy effects and overly playful UI.

| Token | Hex | Use |
|---|---|---|
| Paper | #F4F0E7 | Main canvas |
| Linen | #E8E0D2 | Cards and secondary surfaces |
| Ink | #302C27 | Primary text |
| Sepia | #786957 | Supporting text |
| Olive | #74765A | Primary action |
| Clay | #A66F58 | Recording accent |
| Rule | #D8CFC1 | Dividers and borders |

## Build

Open `FamilyStory.xcodeproj` in Xcode 16 or later. Select the FamilyStory scheme and an iOS 17+ simulator/device.

No third-party packages or network services are required.

## Privacy

The app stores archive metadata and media in its app-private Documents directory. “Local-first” does not disable iOS device backups or prevent copies created through a user-selected export/share destination. No remote upload or cloud AI API is implemented.

## Current scope

This repository starts the iOS MVP foundation: onboarding, archive home, memory list/detail, people list, and a working AVFoundation recording/playback path. Transcription and Foundation Models remain capability-gated follow-up work.
