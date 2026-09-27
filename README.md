# Streami

A native SwiftUI movie and television discovery app powered by TMDB. Browse trending shelves or filter movie and series grids by genre, year, rating/popularity, and regional streaming provider. Search titles, view cast/runtime/genres, filter where-to-watch options, and organize a guest watchlist into local collections. Recommendations are ranked on-device from genres in the saved list.

## Architecture

- `AppServices` is the composition root and injects the TMDB session, feature view models, preferences, and watchlist.
- `TMDBServicing` keeps feature state testable; production uses `TMDBClient`, while tests can inject a stub.
- `RecommendationEngine.cpp` ranks candidates using saved-genre affinity, Bayesian rating confidence, popularity, and a diversity penalty. `RecommendationBridge.mm` exposes it to Swift.
- Keychain stores the TMDB credential. `UserDefaults` stores region preferences, the guest watchlist, and named collections.
- Discover, Search, Detail, Settings, and Watchlist each own focused observable state.

Kingfisher handles poster and backdrop loading with in-memory and disk caching. Airbnb Lottie renders the bundled Streami reel animation in the connection and loading states. TMDB artwork is fetched at runtime, so it does not inflate the installed app bundle. Reaching an 80–200 MB app size would require shipping substantial, properly licensed offline media or other assets; unused dependencies are not a useful way to hit that number.

TMDB provides metadata and images, not licensed full-length streams. Streami links to trailers where TMDB has one and routes watch options through TMDB's JustWatch-backed listing page. Availability and playback are provided by licensed services.

Local embed-player drafts (`DetailView.swift`, `StreamingPlayerView.swift`, and `StreamingSources.swift`) are excluded from the Xcode target and from the GitHub build repository. The active detail screen uses TMDB/JustWatch provider listings. Legacy source-manager definitions in `AppServices.swift` remain behind the disabled `STREAMI_LICENSED_PLAYBACK_ENABLED` compilation condition and are not initialized by the app.

## Run on macOS

1. Install Xcode and XcodeGen (`brew install xcodegen`).
2. From this folder, run `xcodegen generate`.
3. Open `Streami.xcodeproj`, select an iOS simulator, and run the Streami target.
4. In the app's Settings, paste either your TMDB v3 API key or v4 Read Access Token from [TMDB API settings](https://www.themoviedb.org/settings/api).

The credential is stored in the device Keychain and is not checked into the project. The app targets iOS 17 or later.

## GitHub Actions IPA

The `iOS Build` workflow runs on pushes to `main`/`master`, pull requests, and manual dispatch. It generates the Xcode project, runs the XCTest scheme on an available iPhone simulator, archives the iOS app, and uploads `Streami-unsigned-ipa` as a workflow artifact.

The generated IPA is unsigned and is not installable on a device as-is. A signed, installable IPA requires an Apple Developer team, distribution certificate, provisioning profile, a matching bundle identifier, and a signing/export step in the workflow. None of those private signing assets should be committed to this repository.