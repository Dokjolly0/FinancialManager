# financialmanager

The Flutter client of FinancialManager (Android and iOS). The full specification is in [`../plan.md`](../plan.md).

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:10003/v1   # emulator → local backend
flutter test
```

The API base URL comes from `--dart-define` (`lib/core/api/api_environment.dart`); release builds are described in [`../docs/build-deploy.md`](../docs/build-deploy.md).

## Structure

Feature-first (`lib/features/<feature>/{data,domain,presentation}`), Riverpod for state, go_router for navigation (`lib/app/router.dart`), localized strings in `lib/l10n/app_{it,en}.arb`.

## AI analysis

`lib/features/ai/` implements the AI analysis (plan.md section 32) in two modes:

- **Cloud**: the backend calls the provider the user configured (Anthropic, OpenAI, Gemini, OpenAI-compatible) and streams the report over SSE.
- **On device** (plan.md section 33, Android arm64): the backend builds the prompt and keeps the history, the model runs on the phone.
  - Engines: LiteRT-LM (`.litertlm`, GPU in float32) and llama.cpp (GGUF, CPU only) through `flutter_edge_ai`; see `data/local/engines/` and `data/local/engine_model_host.dart`.
  - Models: the catalog in `assets/ai/local_models.json` (pinned Hugging Face revisions and SHA-256), resumable downloads, imports from file or URL (`data/local/model_*.dart`, `presentation/view_models/local_models_controller.dart`).
  - Runs: `data/local/local_ai_runner.dart` produces the same stream events as a cloud run; results the server hasn't received wait in an outbox.
  - Measurements behind the choices: [`../docs/ai-on-device-spike.md`](../docs/ai-on-device-spike.md).

The engines are why release APKs ship `arm64-v8a` only (about 92 MB), `minSdk` is 30 and the iOS target is 15. Tests use fake engines and servers (`test/features/ai/fakes/`); the engines themselves only run on a real Android phone.
