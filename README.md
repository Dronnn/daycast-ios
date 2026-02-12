# DayCast iOS

SwiftUI iOS client for DayCast — a personal AI-powered service that transforms daily inputs (text, links, photos) into tailored content for multiple channels.

## Features

### Tabs

- **History** — browse past days with search. Tap into a day to see all inputs (with cleared/edited badges) and all generations. Copy any result. View edit history per item.
- **Channels** — configure which channels are active. Set default style, language, and output length per channel. Auto-saves on every change (debounced). Supports 5 channels: Blog, Diary, Telegram Personal, Telegram Public, Twitter/X. Generation settings: custom AI instruction and separate business/personal toggle. Access Reminders settings from the `⋯` menu.
- **Feed** — chat-like input stream (center tab, default). Add text, paste links, take photos from camera or pick from gallery. Composer bar has dedicated camera and gallery buttons. Edit and delete items. Flame importance rating (1–5, `FlameRatingView` with progressive-size flame icons — replaces the old `StarRatingView`). Flames shown on all item types including images. AI toggle to include/exclude items from generation. Edit history viewer. Export day as text. Publish input items directly. "Clear day" soft-deletes all items. Tap image to fullscreen with pinch-to-zoom and swipe-down-to-dismiss.
- **Generate** — trigger AI generation for all active channels. View results as cards with Copy, Share, and Publish. Regenerate per-channel or all. Switch between multiple generations per day.
- **Blog** — public feed of published posts. Channel filter pills, infinite scroll with cursor pagination, pull-to-refresh, shimmer loading skeletons. Tap a post card to view full detail with share/copy.

### Publishing

- **Publish / Unpublish** — publish any generated result or raw input item to the public DayCast Blog site. Available on result cards in Generate, Feed, and History Detail views.
- **Publish status** — batch status check shows which results and input items are already published.
- Published posts appear on the public site at `http://192.168.31.131:3000`.

### Share Extension

- **Share from any app** — share URLs, text, and images from Safari or any app via the iOS share sheet.
- **Source metadata** — each shared item is tagged with type and timestamp (e.g. "— last link shared at 14:30").
- **App Groups** — token shared between main app and extension via `group.ch.origin.daycast` (entitlements on both targets).
- **Auto-refresh** — feed automatically refreshes when returning to the app after sharing (via `scenePhase` observer).

### Reminders (Push Notifications)

- **Evening reminders** — local push notifications: "You added N items today. Ready to generate?"
- **Per-day schedule** — enable/disable each day of the week (Mon–Sun) with individual time pickers. Default: all days at 20:00.
- **Auto-update** — notification body updates with the actual item count whenever you add or clear items in Feed.
- **Settings** — accessible from Channels tab `⋯` menu → Reminders. Master toggle requests notification permission on first enable.

### Auth

- **Login / Register** — username + password authentication. JWT stored in UserDefaults (App Groups). Shows login screen when no token.
- **Auto-logout on session expiry** — 401 responses trigger automatic logout via `Notification.Name.sessionExpired`.
- **Logout** — available in Channels tab via the `⋯` menu (top-right). Confirmation dialog before clearing auth.
- **Token migration** — on first launch after update, token migrates from `UserDefaults.standard` to the App Group shared container.

## Tech Stack

- **SwiftUI** (iOS 18+)
- **Swift Concurrency** (async/await)
- **No external dependencies** — pure Apple frameworks

## Architecture

MVVM with 4 layers:

- **Views** — SwiftUI views (`BlogView`, `BlogPostDetailView`, `GenerateView`, `FeedView`, `ChannelsView`, `RemindersSettingsView`, `HistoryView`, `HistoryDetailView`, `LoginView`)
- **ViewModels** — `@Observable` classes (`BlogViewModel`, `FeedViewModel`, `GenerateViewModel`, `ChannelsViewModel`, `HistoryViewModel`, `HistoryDetailViewModel`)
- **Services** — `APIService` singleton (URLSession async/await, JWT auth + public endpoints), `NotificationManager` singleton (local push notifications scheduling via UNUserNotificationCenter)
- **Models** — Codable DTOs matching the backend API (`InputItem`, `Generation`, `GenerationResult`, `ChannelSetting`, `PublishedPostResponse`, `PublicPostListResponse`, `GenerationSettingsRequest/Response`, `ExportResponse`, etc.)
- **Shared** — `SharedTokenStorage` (App Group UserDefaults), `ShareExtensionAPI` (lightweight API client for extension)
- **DayCastShare** — Share Extension target (`ShareExtensionView`, `ShareViewController`)

Shared UI components in `Theme.swift`: color tokens, `ChannelIconView` (gradient letter badges), `ShimmerView` (loading skeletons), date formatters.

## API

Backend: `http://192.168.31.131:8000/api/v1/`. Auth via JWT Bearer token.

Endpoints used:
- `POST /auth/register`, `POST /auth/login` — authentication
- `GET/POST/PUT/DELETE /inputs` — input items CRUD
- `POST /inputs/upload` — image upload (multipart)
- `POST /generate` — trigger AI generation
- `POST /generate/{id}/regenerate` — regenerate channels
- `GET /days`, `GET /days/{date}`, `DELETE /days/{date}` — history
- `GET/POST /settings/channels` — channel config
- `GET/POST /settings/generation` — generation settings (custom instruction, business/personal)
- `POST /publish` — publish a generation result
- `POST /publish/input` — publish an input item directly
- `DELETE /publish/{id}` — unpublish
- `GET /publish/status?result_ids=...` — batch publish status check (generation results)
- `GET /publish/input-status?input_ids=...` — batch publish status check (input items)
- `GET /inputs/export?date=...` — export day as text
- `GET /public/posts` — public feed (no auth, cursor pagination, channel filter)
- `GET /public/posts/{slug}` — single public post by slug

## Setup

1. Open `daycast/daycast.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (Cmd+R)

The API server must be running on `192.168.31.131` (or update `baseURL` in `Services/APIService.swift`).

## License

Private project.
