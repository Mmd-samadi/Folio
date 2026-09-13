# Folio

**Read smarter.** A Flutter study assistant for academic PDFs — import, section, summarize, and chat with dual AI (on-device or Gemini cloud).

## Features

- Import and organize academic PDFs into books and reading sessions
- Automatic and manual section / chapter detection (TOC, headings, offline heuristics)
- Built-in PDF reader with reading progress (`pdfrx`)
- AI section summaries you can share
- Contextual chat scoped to the current section
- Dual AI providers: on-device models (Gemma / LiteRT / MediaPipe) or Gemini cloud (`gemini-2.5-flash`)
- Local persistence (`LocalStore` / SharedPreferences), light and dark themes, offline awareness

## Screenshots

Add product screenshots under `docs/screenshots/` and link them here when available.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.13.1`)
- A [Gemini API key](https://aistudio.google.com/apikey) if you use the cloud provider (optional when using on-device only)
- For on-device inference on Android: **minSdk 30**, **arm64-v8a** devices

## Setup

1. Clone the repository and enter the project directory:

   ```bash
   git clone <repository-url>
   cd folio
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Create your environment file:

   ```bash
   cp .env.example .env
   ```

4. Open `.env` and configure:

   ```
   GEMINI_API_KEY=your_actual_api_key_here

   # Optional: remote on-device model catalog (24h cache + Settings refresh)
   # ON_DEVICE_MODELS_CATALOG_URL=https://example.com/folio_on_device_models.json
   ```

   Never commit `.env` or hardcode API keys in source.

5. (Optional) Authenticate Hugging Face for gated on-device models:

   ```bash
   flutter run --dart-define=HUGGINGFACE_TOKEN=your_hf_token
   ```

6. Run the app:

   ```bash
   flutter run
   ```

## AI providers

| Provider | Default | Notes |
|----------|---------|--------|
| **On-device** | Yes | Models from the bundled catalog (`assets/on_device_models.json`) or an optional remote URL; download via Settings (Hugging Face). Works offline after install. |
| **Gemini** | No | Uses `gemini-2.5-flash`. Set `GEMINI_API_KEY` in `.env` or enter the key in Settings. |

Switch provider, summary format/length, chat scope, custom prompts, text direction, and theme in **Settings**.

## Project structure

```
lib/
├── core/          # theme, router, LocalStore, constants, shared widgets
└── features/
    ├── ai/        # on-device Gemma + model catalog
    ├── books/     # library / book folders
    ├── import/    # PDF pick, TOC / heading / offline section detection
    ├── reader/    # PDF view, summarization, section chat
    ├── sessions/  # splash, home, reading sessions
    ├── settings/  # provider, prompts, theme, API key
    └── chat/      # Gemini repository (legacy ChatPage not in router)
└── main.dart
```

## Tech stack

- Flutter / Dart
- BLoC / Cubit (`flutter_bloc`)
- Navigation (`go_router`)
- PDF rendering (`pdfrx`)
- On-device AI (`flutter_gemma`, LiteRT, MediaPipe)
- Gemini API (`google_generative_ai`)
- Config (`flutter_dotenv`)
- Local storage (`shared_preferences`, `path_provider`)

## Architecture

Feature-first Clean Architecture: each feature splits **data**, **domain**, and **presentation**. App state uses BLoC/Cubit; routing uses `go_router` (splash → home → book → reader, plus settings and import flows). Data stays on-device; there is no auth or remote database.

## Testing

```bash
flutter test
```

Coverage includes settings, books migration, Gemini repository, section improvements, and topic detection under `test/`.

## Platform notes

| Platform | Notes |
|----------|--------|
| **Android** | Primary target for on-device models (`minSdk` ≥ 30, `arm64-v8a`) |
| **iOS / macOS / Linux / Windows** | Scaffolded Flutter runners; on-device support depends on `flutter_gemma` engine availability |
| **Web** | Scaffolded; full on-device inference is typically limited vs mobile |

## License

No license file is included in this repository yet.
