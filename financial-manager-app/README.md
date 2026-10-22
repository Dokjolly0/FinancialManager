# financialmanager

The Flutter client of FinancialManager (Android, iOS and the web dashboard at https://financialmanager.alexviolatto.dev). The full specification is in [`../plan.md`](../plan.md).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:10003/v1   # emulator → local backend
flutter test
```

The API base URL comes from `--dart-define` (`lib/core/api/api_environment.dart`); without it, builds use production, `https://financialmanager.alexviolatto.dev/api/v1`. Only debug builds may use plain http (the debug manifest sets `usesCleartextTraffic` for the local backend on the emulator); release builds are HTTPS only.

## Web

The same code builds for the browser (`flutter build web --release --no-web-resources-cdn`); in production CI builds the image (`Dockerfile`, `docker/Caddyfile.web`, job `build-web` in `.github/workflows/mobile-ci.yml`), publishes it to Docker Hub as `dokjolly/financial-manager-web` on every push to `main`, and the VPS pulls it. Locally: `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:10003/v1`, with `CORS_ALLOWED_ORIGINS=http://localhost:5000` in the backend's `.env`.

What differs in the browser:

- No on-device AI: the engines use `dart:ffi` and come from `lib/features/ai/data/local/engines/local_engines.dart`, a conditional export with no engines on the web; `localAiSupportedProvider` is false, so analyses use cloud providers only and the model screens redirect to the AI settings.
- Google sign-in and linking use Google's rendered button (`lib/core/auth/google_web_button.dart`); the ID token arrives on `GoogleSignInService.webIdTokens`.
- Files (export, AI report) are browser downloads via `saveOrShareFile` (`lib/core/files/save_file.dart`); image cropping uses cropperjs, vendored in `web/cropperjs`.
- From 840 px the shell shows a side rail and pages are centered (`lib/app/layout/breakpoints.dart`); URLs use the path strategy.

To keep the web build working: no `dart:io` `Platform`/`File` outside `_io`/`_ffi` files (use `isAndroidApp`/`isIosApp` from `lib/core/platform/platform_info.dart` or `kIsWeb`), native-only code behind a conditional export. CI builds the web image on every push and pull request. Details: [`../docs/build-deploy.md`](../docs/build-deploy.md), "Dashboard web" and "Web in locale".

## Signing

Release and debug builds are signed with one upload key, the same on every PC, read from `android/key.properties` (copy `android/key.properties.example`; the file and the keystore are never committed). Without it builds fall back to the PC's debug key: they compile, but cannot update an installed app and Google Sign-In fails. Creating the key, using it on several PCs, registering its SHA-1 for Google Sign-In and the Play Store setup are in [`../docs/build-deploy.md`](../docs/build-deploy.md) ("Firma Android").

## Structure

Feature-first (`lib/features/<feature>/{data,domain,presentation}`), Riverpod for state, go_router for navigation (`lib/app/router.dart`), localized strings in `lib/l10n/app_{it,en}.arb`.

## AI analysis

`lib/features/ai/` implements the AI analysis (plan.md section 32) in two modes:

- **Cloud**: the backend calls the provider the user configured (Anthropic, OpenAI, Gemini, OpenAI-compatible) and streams the report over SSE.
- **On device** (plan.md section 33, Android arm64): the backend builds the prompt and keeps the history, the model runs on the phone.
  - Engines: LiteRT-LM (`.litertlm`, GPU in float32) and llama.cpp (GGUF, CPU only) through `flutter_edge_ai`; see `data/local/engines/` and `data/local/engine_model_host.dart`.
  - Models: the catalog in `assets/ai/local_models.json` (pinned Hugging Face revisions and SHA-256), resumable downloads, imports from file or URL (`data/local/model_*.dart`, `presentation/view_models/local_models_controller.dart`).
  - Runs: `data/local/local_ai_runner.dart` produces the same stream events as a cloud run; results the server hasn't received wait in an outbox (no expiry; readable by anyone on the phone in "Risposte non inviate", sent or deleted only by their author).
  - Background: `data/local/background_work.dart` runs downloads and generation in an Android foreground service with a progress notification (Pausa / Interrompi), `data/local/ai_notifier.dart` notifies when they finish; the Flutter engine is cached in `FinancialManagerApplication` so work survives a swipe from the recents.
  - Measurements behind the choices: [`../docs/ai-on-device-spike.md`](../docs/ai-on-device-spike.md).

The engines are why release APKs ship `arm64-v8a` only (about 92 MB), `minSdk` is 30 and the iOS target is 15. Tests use fake engines and servers (`test/features/ai/fakes/`); the engines themselves only run on a real Android phone.
