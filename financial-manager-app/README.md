# financialmanager

The Flutter client of FinancialManager for Android and iOS (the web dashboard is [`../financial-manager-web/`](../financial-manager-web/)). The full specification is in [`../plan.md`](../plan.md).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:10003/v1   # emulator → local backend
flutter test
```

The API base URL comes from `--dart-define` (`lib/core/api/api_environment.dart`); without it, builds use production, `https://financialmanager.alexviolatto.dev/api/v1`. Only debug builds may use plain http (the debug manifest sets `usesCleartextTraffic` for the local backend on the emulator); release builds are HTTPS only.

## Platforms

Android and iOS only. The web dashboard is a separate Angular app, [`../financial-manager-web/`](../financial-manager-web/), with the same features except the on-device AI; it reuses this app's ARB files for its strings, so a new or changed key in `lib/l10n/app_{it,en}.arb` shows up in both (its CI checks that both languages have every key and the same placeholders). The app keeps a wide layout for tablets: from 840 px the shell shows a side rail and pages are centered (`lib/app/layout/breakpoints.dart`).

Email links: the backend's emails link to `/reset-password?token=...` and `/verify-email?token=...` (`lib/features/authentication/presentation/screens/reset_password_screen.dart`, `verify_email_screen.dart`), routes reachable with or without a session. They open the web dashboard in a browser; on Android the same `https://financialmanager.alexviolatto.dev/...` URLs open the app through App Links: the `autoVerify` intent-filter in `android/app/src/main/AndroidManifest.xml` plus `../financial-manager-web/docker/assetlinks.json`, served by the web image at `/.well-known/assetlinks.json` with the signing key's SHA-256 (add Play's app signing key there at the first Play release). Details: [`../docs/build-deploy.md`](../docs/build-deploy.md), section "12. Email", "App Links".

## Signing

Release and debug builds are signed with one upload key, the same on every PC, read from `android/key.properties` (copy `android/key.properties.example`; the file and the keystore are never committed). Without it builds fall back to the PC's debug key: they compile, but cannot update an installed app and Google Sign-In fails. Creating the key, using it on several PCs, registering its SHA-1 for Google Sign-In and the Play Store setup are in [`../docs/build-deploy.md`](../docs/build-deploy.md) ("Firma Android").

## Structure

Feature-first (`lib/features/<feature>/{data,domain,presentation}`), Riverpod for state, go_router for navigation (`lib/app/router.dart`), localized strings in `lib/l10n/app_{it,en}.arb` (shared with the web dashboard).

## AI analysis

`lib/features/ai/` implements the AI analysis (plan.md section 32) in two modes:

- **Cloud**: the backend calls the provider the user configured (Anthropic, OpenAI, Gemini, OpenAI-compatible) and streams the report over SSE.
- **On device** (plan.md section 33, Android arm64): the backend builds the prompt and keeps the history, the model runs on the phone.
  - Engines: LiteRT-LM (`.litertlm`, GPU in float32) and llama.cpp (GGUF, CPU only) through `flutter_edge_ai`; see `data/local/engines/` and `data/local/engine_model_host.dart`.
  - Models: the catalog in `assets/ai/local_models.json` (pinned Hugging Face revisions and SHA-256), resumable downloads, imports from file or URL (`data/local/model_*.dart`, `presentation/view_models/local_models_controller.dart`).
  - Runs: `data/local/local_ai_runner.dart` produces the same stream events as a cloud run; results the server hasn't received wait in an outbox (no expiry; readable by anyone on the phone in "Risposte non inviate", sent or deleted only by their author).
  - Background: `data/local/background_work.dart` runs downloads and generation in an Android foreground service with a progress notification (Pausa / Interrompi), `data/local/ai_notifier.dart` notifies when they finish; the Flutter engine is cached in `FinancialManagerApplication` so work survives a swipe from the recents.
  - Measurements behind the choices: [`../docs/ai-on-device-spike.md`](../docs/ai-on-device-spike.md).

**Chiedi all'assistente** (plan.md section 34) is a chat about the user's own transactions, in both modes: `presentation/screens/ai_chat_screen.dart` asks the question, previews silently (`AiAnalysisRequest.chat`, preset `CHAT`) and hands over to the analysis screen, which shows a chat's first question as a bubble and the transactions the server searched for a question behind a chip. The history filters reports and chats (`AiHistoryType`). On a cloud provider the server may search the transactions with tools: the `tool` stream event (`AiStreamTool`) drives a status line while the answer is written, and the stored `tool_trace` (`AiToolTraceEntry`) the "Ricerche fatte" section under it.

The engines are why release APKs ship `arm64-v8a` only (about 92 MB), `minSdk` is 30 and the iOS target is 15. Tests use fake engines and servers (`test/features/ai/fakes/`); the engines themselves only run on a real Android phone.
