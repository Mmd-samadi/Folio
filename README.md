# Nexus Chat

A Flutter chatbot app powered by the Gemini API (`gemini-3.6-flash`). Built with Clean Architecture and BLoC for state management.

## Features

- Send and receive chat messages
- Typing indicator while waiting for a response
- In-session conversation history
- Offline / no internet error handling
- Dark and light theme toggle

## Out of Scope

- Login / authentication
- Database / persistent storage
- Multi-session management
- Voice input / output

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+)
- A free Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)

## Setup

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd nexus_chat
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Create your environment file:

   ```bash
   cp .env.example .env
   ```

4. Open `.env` and set your API key:

   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```

   Never commit your `.env` file or hardcode the API key in source code.

5. Run the app:

   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   └── theme/
├── features/
│   └── chat/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

## Tech Stack

- Flutter
- BLoC (`flutter_bloc`)
- Gemini API (`google_generative_ai`)
- Clean Architecture

## Testing Checklist

- Send a message and receive a Gemini response
- Send multiple messages and verify session context is preserved
- Enable airplane mode and confirm the offline error appears
- Toggle between dark and light themes
