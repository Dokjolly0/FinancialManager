import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
  untracked,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { CircleAlert, CircleCheck, Download, PlugZap } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { Switch } from '../../shared/ui/form-controls';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AiApi } from './ai.api';
import {
  AI_MAX_OUTPUT_TOKENS,
  AI_MIN_OUTPUT_TOKENS,
  AI_PROVIDERS,
  AiCredential,
  AiProvider,
  AiSettings,
  COMPATIBLE_PRESETS,
  PROVIDER_LABELS,
  requiresApiKey,
  requiresBaseUrl,
} from './ai.model';

const HINT_KEYS: Record<AiProvider, string> = {
  anthropic: 'aiProviderHintAnthropic',
  openai: 'aiProviderHintOpenai',
  gemini: 'aiProviderHintGemini',
  openai_compatible: 'aiProviderHintCompatible',
};

/** A decimal typed with a comma or a dot; empty is null. */
function parsePrice(raw: string): number | null {
  const text = raw.trim().replace(',', '.');
  if (!text) return null;
  const value = Number(text);
  return Number.isFinite(value) ? value : NaN;
}

/**
 * Provider and API key (plan.md sections 32.4, 32.5): provider, base URL
 * for OpenAI-compatible servers, key (stored encrypted on the server, only
 * its last digits come back), model (typed or loaded from the provider),
 * output limit, optional prices, analysis defaults; test, save, forget.
 */
@Component({
  selector: 'app-ai-provider-page',
  imports: [Icon, InlineError, PageHeader, ReactiveFormsModule, Spinner, Switch, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './ai-provider-page.html',
})
export class AiProviderPage {
  protected readonly ai = inject(AiApi);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly icons = { CircleAlert, CircleCheck, Download, PlugZap };
  protected readonly providers = AI_PROVIDERS;
  protected readonly compatiblePresets = COMPATIBLE_PRESETS;
  protected readonly minTokens = AI_MIN_OUTPUT_TOKENS;
  protected readonly maxTokens = AI_MAX_OUTPUT_TOKENS;
  protected readonly hintKeys = HINT_KEYS;

  protected readonly form = this.fb.group({
    provider: this.fb.control<AiProvider>('anthropic'),
    baseUrl: [''],
    apiKey: [''],
    model: [''],
    maxOutputTokens: [4096],
    inputPrice: [''],
    outputPrice: [''],
    includeTransactions: [false],
    anonymizeTitles: [false],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  /** The user asked to replace the stored key (shows the key field). */
  protected readonly replacingKey = signal(false);
  protected readonly removeKey = signal(false);
  protected readonly models = signal<{ id: string; display_name: string }[] | null>(null);
  protected readonly loadingModels = signal(false);
  protected readonly testing = signal(false);
  protected readonly testResult = signal<{ ok: boolean; text: string } | null>(null);
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();
  private initialized = false;

  /** The stored account for the chosen provider (and base URL, for compatible servers). */
  protected readonly stored = computed<AiCredential | null>(() =>
    this.storedFor(this.values().provider ?? 'anthropic', this.values().baseUrl ?? ''),
  );
  protected readonly needsBaseUrl = computed(() =>
    requiresBaseUrl(this.values().provider ?? 'anthropic'),
  );
  protected readonly needsKey = computed(() =>
    requiresApiKey(this.values().provider ?? 'anthropic'),
  );
  protected readonly showKeyField = computed(() => !this.stored()?.has_key || this.replacingKey());

  constructor() {
    this.ai.settings.reload();
    // Fill the form once from the active account and the saved defaults.
    effect(() => {
      const settings = this.ai.settings.value();
      if (!settings || this.initialized) return;
      this.initialized = true;
      untracked(() => this.fill(settings));
    });
    // Switching provider shows that provider's stored model.
    this.form.controls.provider.valueChanges.subscribe((provider) => {
      this.replacingKey.set(false);
      this.removeKey.set(false);
      this.models.set(null);
      this.testResult.set(null);
      // Compatible servers: the first stored one, if any.
      const stored = requiresBaseUrl(provider)
        ? (this.ai.settings.value()?.credentials?.find((c) => c.provider === provider) ?? null)
        : this.storedFor(provider, '');
      this.form.patchValue({
        apiKey: '',
        model: stored?.model ?? '',
        baseUrl: stored?.base_url ?? '',
      });
    });
  }

  private storedFor(provider: AiProvider, baseUrl: string): AiCredential | null {
    return (
      this.ai.settings
        .value()
        ?.credentials?.find(
          (c) =>
            c.provider === provider &&
            (!requiresBaseUrl(provider) || (c.base_url ?? '') === baseUrl.trim()),
        ) ?? null
    );
  }

  protected providerLabel(provider: AiProvider): string {
    return PROVIDER_LABELS[provider] ?? this.transloco.translate('aiProviderCompatible');
  }

  private fill(settings: AiSettings): void {
    const active = settings.active;
    this.form.patchValue(
      {
        provider: active?.provider ?? 'anthropic',
        baseUrl: active?.base_url ?? '',
        model: active?.model ?? '',
        maxOutputTokens: settings.max_output_tokens || 4096,
        inputPrice: settings.input_price_per_mtok?.toString() ?? '',
        outputPrice: settings.output_price_per_mtok?.toString() ?? '',
        includeTransactions: settings.defaults.include_transactions,
        anonymizeTitles: settings.defaults.anonymize_titles,
      },
      { emitEvent: false },
    );
    this.form.updateValueAndValidity();
  }

  protected applyPreset(baseUrl: string): void {
    this.form.controls.baseUrl.setValue(baseUrl);
  }

  /** The form as a probe: the typed key if any, else the server uses the stored one. */
  private probe() {
    const v = this.form.getRawValue();
    return {
      provider: v.provider,
      ...(requiresBaseUrl(v.provider) ? { base_url: v.baseUrl.trim() } : {}),
      api_key: v.apiKey.trim(),
      model: v.model.trim(),
    };
  }

  protected async loadModels(): Promise<void> {
    this.loadingModels.set(true);
    try {
      const models = await this.ai.models({ ...this.probe(), model: '' });
      this.models.set(models);
      this.toasts.show(
        models.length
          ? this.transloco.translate('aiModelsLoaded', { count: models.length })
          : this.transloco.translate('aiModelsNoneFound'),
      );
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.loadingModels.set(false);
    }
  }

  protected async test(): Promise<void> {
    this.testing.set(true);
    this.testResult.set(null);
    try {
      const result = await this.ai.test(this.probe());
      if (result.ok) {
        this.testResult.set({
          ok: true,
          text: result.model
            ? this.transloco.translate('aiTestOk', { model: result.model, ms: result.latency_ms })
            : this.transloco.translate('aiTestOkKeyOnly', { ms: result.latency_ms }),
        });
      } else {
        const code = this.errorText.code(result.error_code ?? 'AI_PROVIDER_ERROR');
        this.testResult.set({
          ok: false,
          text: result.error_message ? `${code} ${result.error_message}` : code,
        });
      }
    } catch (error) {
      this.testResult.set({ ok: false, text: this.errorText.message(error) });
    } finally {
      this.testing.set(false);
    }
  }

  /** The app's validateAiProviderForm, then the save request (key sent only when it changes). */
  protected async save(): Promise<void> {
    const v = this.form.getRawValue();
    const stored = this.stored();
    const inputPrice = parsePrice(v.inputPrice);
    const outputPrice = parsePrice(v.outputPrice);
    const typedKey = v.apiKey.trim();
    const codes: Record<string, string> = {};
    if (requiresBaseUrl(v.provider) && !v.baseUrl.trim()) codes['base_url'] = 'REQUIRED_FIELD';
    if (!v.model.trim()) codes['model'] = 'REQUIRED_FIELD';
    const hasKey = !!typedKey || (stored?.has_key === true && !this.removeKey());
    if (requiresApiKey(v.provider) && !hasKey) codes['api_key'] = 'REQUIRED_FIELD';
    const tokens = Number(v.maxOutputTokens);
    if (
      !Number.isInteger(tokens) ||
      tokens < AI_MIN_OUTPUT_TOKENS ||
      tokens > AI_MAX_OUTPUT_TOKENS
    ) {
      codes['max_output_tokens'] = 'VALUE_OUT_OF_RANGE';
    }
    if (Number.isNaN(inputPrice) || (inputPrice ?? 0) < 0)
      codes['input_price_per_mtok'] = 'NEGATIVE_NOT_ALLOWED';
    if (Number.isNaN(outputPrice) || (outputPrice ?? 0) < 0)
      codes['output_price_per_mtok'] = 'NEGATIVE_NOT_ALLOWED';
    if (!this.errors.check(codes)) return;

    this.saving.set(true);
    try {
      await this.ai.saveSettings({
        provider: v.provider,
        base_url: requiresBaseUrl(v.provider) ? v.baseUrl.trim() : '',
        model: v.model.trim(),
        api_key: typedKey ? typedKey : this.removeKey() ? '' : null,
        max_output_tokens: tokens,
        input_price_per_mtok: inputPrice,
        output_price_per_mtok: outputPrice,
        defaults: {
          include_transactions: v.includeTransactions,
          anonymize_titles: v.anonymizeTitles,
        },
        version: this.ai.settings.value()?.version ?? 0,
      });
      this.form.controls.apiKey.setValue('');
      this.replacingKey.set(false);
      this.removeKey.set(false);
      this.toasts.success(this.transloco.translate('webSaved'));
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }

  protected async forget(): Promise<void> {
    const stored = this.stored();
    if (!stored) return;
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('aiForgetProviderTitle'),
      message: this.transloco.translate('aiForgetProviderMessage'),
      confirmLabel: this.transloco.translate('aiForgetProviderAction'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.ai.deleteCredential(stored.id);
      this.form.patchValue({ apiKey: '', model: '' });
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }
}
