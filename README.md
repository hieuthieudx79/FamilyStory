# Family Story

**Keep Their Voices Forever.**

A private, audio-first family memory archive for iOS. The app is local-first, offline-first, and privacy-first.

## Tier 1 MVP

- Native SwiftUI app targeting iOS 17+.
- Create a local archive without account registration.
- Record original audio with pause/resume and interruption feedback.
- Attach a title, notes, event date, and family members to a memory.
- Browse a chronological memory timeline and search titles, notes, transcripts, and people.
- Play, seek, and review the original recording.
- Add a photo from Photos; the app stores a copy in its local archive.
- Request on-device speech transcription when the selected locale and device support it.
- Export/import a complete .familyarchive package through Files or the iOS Share Sheet.
- Validate package paths and SHA-256 checksums before import; duplicate memory IDs are skipped rather than overwritten.
- View archive storage usage and delete the local archive.

## Visual direction — Quiet nostalgia

Warm paper, aged linen, sepia ink, muted olive and terracotta accents. Editorial serif headlines, generous whitespace, fine rules, calm controls and softly rounded surfaces.

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

Open FamilyStory.xcodeproj in Xcode 16 or later. Select the FamilyStory scheme and an iOS 17+ simulator/device.

A GitHub Actions workflow builds the app for the iOS Simulator on pushes and pull requests. This repository does not require third-party packages or network services.

## Local data and privacy

Archive metadata is stored using SwiftData. Audio and photo copies live under the app's Documents/FamilyStory directory. Speech recognition is configured to require on-device processing; if the OS cannot satisfy that requirement, the transcript action fails with an explanation and the original audio remains available.

“Local-first” does not disable iOS device backups or prevent copies created through a user-selected export/share destination. The user controls those destinations. No proprietary backend, remote media upload, or cloud AI API is implemented.

## Archive format

.familyarchive is a ZIP container using uncompressed entries, with:
- manifest.json (schema version 1)
- Audio/<filename> original audio
- Photos/<filename> copied images

The importer rejects unsupported versions, unsafe paths, undeclared files, invalid references, CRC failures, and SHA-256 mismatches. Existing memory IDs are skipped; current records are not silently overwritten.

## Current implementation boundaries

On-device transcription uses Apple's Speech framework with requiresOnDeviceRecognition = true. Speech recognition remains optional and language/device support varies. Foundation Models title and summary suggestions, a robust interrupted-recording recovery screen, advanced archive merge UI, StoreKit unlock, accessibility audit, privacy manifest review, and App Store submission work remain follow-up items.

Before release, run simulator and physical-device QA, especially recording interruptions, low storage, import duplicates, and restore from a clean install.
