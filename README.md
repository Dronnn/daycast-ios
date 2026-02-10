# DayCast iOS

SwiftUI iOS client for DayCast — a personal AI-powered service that transforms daily inputs (text, links, photos) into tailored content for multiple channels.

## Features

### Tabs

- **History** — browse past days with search. Tap into a day to see all inputs (with cleared/edited badges) and all generations. Copy any result. View edit history per item.
- **Channels** — configure which channels are active. Set default style, language, and output length per channel. Auto-saves on every change (debounced). Supports 5 channels: Blog, Diary, Telegram Personal, Telegram Public, Twitter/X.
- **Feed** — chat-like input stream (center tab, default). Add text, paste links, take photos from camera or pick from gallery. Composer bar has dedicated camera and gallery buttons. Edit and delete items. "Clear day" soft-deletes all items. Tap image to fullscreen with pinch-to-zoom and swipe-down-to-dismiss.
- **Generate** — trigger AI generation for all active channels. View results as cards with Copy, Share, and Publish. Regenerate per-channel or all. Switch between multiple generations per day.
- **Blog** — public feed of published posts. Channel filter pills, infinite scroll with cursor pagination, pull-to-refresh, shimmer loading skeletons. Tap a post card to view full detail with share/copy.

### Publishing

- **Publish / Unpublish** — publish any generated result to the public DayCast Blog site. Available on result cards in Generate and History Detail views.
- **Publish status** — batch status check shows which results are already published.
- Published posts appear on the public site at `http://192.168.31.131:3000`.

### Share Extension

- **Share from any app** — share URLs, text, and images from Safari or any app via the iOS share sheet.
- **Source metadata** — each shared item is tagged with type and timestamp (e.g. "— last link shared at 14:30").
- **App Groups** — token shared between main app and extension via `group.ch.origin.daycast` (entitlements on both targets).
- **Auto-refresh** — feed automatically refreshes when returning to the app after sharing (via `scenePhase` observer).

### Auth

- **Login / Register** — username + password authentication. JWT stored in UserDefaults (App Groups). Shows login screen when no token.
- **Logout** — available in Channels tab via the `⋯` menu (top-right). Confirmation dialog before clearing auth.
- **Token migration** — on first launch after update, token migrates from `UserDefaults.standard` to the App Group shared container.

## Tech Stack

- **SwiftUI** (iOS 18+)
- **Swift Concurrency** (async/await)
- **No external dependencies** — pure Apple frameworks

## Architecture

MVVM with 4 layers:

- **Views** — SwiftUI views (`BlogView`, `BlogPostDetailView`, `GenerateView`, `FeedView`, `ChannelsView`, `HistoryView`, `HistoryDetailView`, `LoginView`)
- **ViewModels** — `@Observable` classes (`BlogViewModel`, `FeedViewModel`, `GenerateViewModel`, `ChannelsViewModel`, `HistoryViewModel`, `HistoryDetailViewModel`)
- **Services** — `APIService` singleton (URLSession async/await, JWT auth + public endpoints)
- **Models** — Codable DTOs matching the backend API (`InputItem`, `Generation`, `GenerationResult`, `ChannelSetting`, `PublishedPostResponse`, `PublicPostListResponse`, etc.)
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
- `POST /publish` — publish a generation result
- `DELETE /publish/{id}` — unpublish
- `GET /publish/status?result_ids=...` — batch publish status check
- `GET /public/posts` — public feed (no auth, cursor pagination, channel filter)
- `GET /public/posts/{slug}` — single public post by slug

## Setup

1. Open `daycast/daycast.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (Cmd+R)

The API server must be running on `192.168.31.131` (or update `baseURL` in `Services/APIService.swift`).

## License

Private project.
