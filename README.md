# DayCast iOS

SwiftUI iOS client for DayCast — a personal AI-powered service that transforms daily inputs (text, links, photos) into tailored content for multiple channels.

## Features

- **Feed** — chat-like input stream. Add text, paste links, take photos from camera or gallery. Edit and delete items. "Clear day" soft-deletes all items.
- **Generate** — trigger AI generation for all active channels. View results as cards with Copy and Share. Regenerate per-channel or all. Switch between multiple generations per day.
- **Channels** — configure which channels are active. Set default style, language, and output length per channel.
- **History** — browse past days with search. Tap into a day to see all inputs (with cleared/edited badges) and all generations. Copy any result.
- **Login / Register** — username + password authentication. JWT stored in UserDefaults. Shows login screen without token. Logout button in toolbar.

## Tech Stack

- **SwiftUI** (iOS 26+)
- **Swift Concurrency** (async/await)
- **No external dependencies** — pure Apple frameworks

## Architecture

- **Views** — SwiftUI views for each screen
- **ViewModels** — `@Observable` classes with business logic
- **Services** — API client (URLSession async/await)
- **Models** — Codable DTOs matching the backend API

## API

The app communicates with the DayCast backend API at `http://192.168.31.131:8000/api/v1/`. Authentication via JWT — token stored in UserDefaults and sent as `Authorization: Bearer` header.

Key endpoints:
- `POST /api/v1/auth/register` — register new user
- `POST /api/v1/auth/login` — login existing user
- `GET/POST/PUT/DELETE /api/v1/inputs` — manage input items
- `POST /api/v1/generate` — trigger AI content generation
- `GET /api/v1/days` — browse history
- `GET/POST /api/v1/settings/channels` — channel configuration

## Setup

1. Open `daycast/daycast.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (Cmd+R)

The API server must be running on `192.168.31.131` (or update the base URL in `Services/APIService.swift`).

## License

Private project.
