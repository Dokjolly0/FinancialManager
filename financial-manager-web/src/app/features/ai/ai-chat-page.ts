import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
  untracked,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { History, MessageCircle, SendHorizontal } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, Spinner } from '../../shared/ui/states';
import { AiDraft } from './ai-draft';
import { AiApi } from './ai.api';
import { AI_QUESTION_MAX_LENGTH, PROVIDER_LABELS, chatRequest } from './ai.model';

/**
 * "Chiedi all'assistente" (plan.md section 34, the app's AiChatScreen): a
 * question about the user's own transactions, answered as a chat. No setup:
 * the server picks the data, the preview only gives the fingerprint.
 * Sending opens the conversation on the run page. Cloud accounts only, as
 * every analysis on the web.
 */
@Component({
  selector: 'app-ai-chat-page',
  imports: [
    EmptyState,
    FormsModule,
    Icon,
    InlineError,
    PageHeader,
    RouterLink,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'aiChatTitle' | transloco"
        back="/app/account/ai"
        [backLabel]="'backAction' | transloco"
      >
        <a routerLink="/app/ai/analyses" class="btn btn-ghost">
          <app-icon [icon]="icons.History" [size]="16" /> {{ 'aiHistoryTitle' | transloco }}
        </a>
      </app-page-header>

      @if (ai.settings.isLoading() && !ai.settings.hasValue()) {
        <div class="card card-pad space-y-3">
          <div class="skeleton h-5 w-2/3"></div>
          <div class="skeleton h-24 w-full"></div>
        </div>
      } @else if (ai.settings.error()) {
        <div class="card">
          <app-inline-error
            [message]="errorText.message(ai.settings.error())"
            (retry)="ai.settings.reload()"
          />
        </div>
      } @else if (!ai.credentials().length) {
        <div class="card">
          <app-empty-state [message]="'aiNotReadyBody' | transloco" [icon]="icons.MessageCircle">
            <a routerLink="/app/account/ai" class="btn btn-primary btn-sm">{{
              'aiGoToSetup' | transloco
            }}</a>
          </app-empty-state>
        </div>
      } @else {
        <section class="card card-pad space-y-4">
          <p class="text-sm leading-relaxed text-fg">{{ 'aiChatIntro' | transloco }}</p>
          <div>
            <h2 class="text-xs font-semibold uppercase tracking-wide text-fg-muted">
              {{ 'aiChatExamplesTitle' | transloco }}
            </h2>
            <div class="mt-2 flex flex-wrap gap-2">
              @for (key of examples; track key) {
                <button type="button" class="chip" (click)="useExample(key)">
                  {{ key | transloco }}
                </button>
              }
            </div>
          </div>
          <div>
            <label class="label" for="ai-chat-model">{{ 'aiRunModelLabel' | transloco }}</label>
            <select
              id="ai-chat-model"
              class="input"
              [ngModel]="credentialId()"
              (ngModelChange)="credentialId.set($event)"
            >
              @for (c of ai.credentials(); track c.id) {
                <option [value]="c.id">{{ credentialLabel(c.id) }}</option>
              }
            </select>
            <p class="hint">{{ 'aiChatDataNoteCloud' | transloco }}</p>
          </div>
          @if (error()) {
            <p
              class="rounded-xl border border-debit/30 bg-debit/5 px-4 py-3 text-sm text-debit"
              role="alert"
            >
              {{ error() }}
            </p>
          }
        </section>

        <form
          class="card sticky bottom-20 mt-6 flex items-end gap-2 p-2 shadow-pop md:bottom-4"
          (submit)="$event.preventDefault(); send()"
        >
          <label class="sr-only" for="ai-chat-question">{{ 'aiChatHint' | transloco }}</label>
          <textarea
            id="ai-chat-question"
            class="max-h-40 min-h-11 flex-1 resize-none bg-transparent px-3 py-2.5 text-sm text-fg outline-none placeholder:text-fg-muted"
            rows="2"
            [maxlength]="questionMax"
            [placeholder]="'aiChatHint' | transloco"
            [ngModel]="question()"
            [ngModelOptions]="{ standalone: true }"
            (ngModelChange)="question.set($event)"
            (keydown.enter)="onEnter($any($event))"
          ></textarea>
          <button
            type="submit"
            class="btn btn-primary btn-icon"
            [attr.aria-label]="'aiAskAction' | transloco"
            [disabled]="!canSend()"
          >
            @if (sending()) {
              <app-spinner />
            } @else {
              <app-icon [icon]="icons.SendHorizontal" [size]="18" />
            }
          </button>
        </form>
      }
    </div>
  `,
})
export class AiChatPage {
  protected readonly ai = inject(AiApi);
  private readonly draft = inject(AiDraft);
  private readonly router = inject(Router);
  private readonly overlay = inject(Overlay);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);

  protected readonly icons = { History, MessageCircle, SendHorizontal };
  protected readonly questionMax = AI_QUESTION_MAX_LENGTH;
  protected readonly examples = [
    'aiChatExampleInsurance',
    'aiChatExampleFuel',
    'aiChatExampleYearly',
  ];

  protected readonly credentialId = signal<string | null>(null);
  protected readonly question = signal('');
  protected readonly sending = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly canSend = computed(() => !!this.question().trim() && !this.sending());

  constructor() {
    this.ai.settings.reload();
    // The account that runs it: the active one, else the first usable.
    effect(() => {
      const credentials = this.ai.credentials();
      const active = this.ai.settings.value()?.active?.id;
      untracked(() => {
        if (!credentials.some((c) => c.id === this.credentialId())) {
          this.credentialId.set(
            (credentials.find((c) => c.id === active) ?? credentials[0])?.id ?? null,
          );
        }
      });
    });
  }

  protected credentialLabel(id: string): string {
    const c = this.ai.credentials().find((credential) => credential.id === id);
    if (!c) return '';
    return `${PROVIDER_LABELS[c.provider] ?? this.transloco.translate('aiProviderCompatible')} · ${c.model}`;
  }

  protected useExample(key: string): void {
    this.question.set(this.transloco.translate(key));
  }

  /** Enter sends, Shift+Enter starts a new line. */
  protected onEnter(event: KeyboardEvent): void {
    if (event.shiftKey) return;
    event.preventDefault();
    void this.send();
  }

  protected async send(): Promise<void> {
    const settings = this.ai.settings.value();
    if (!this.canSend() || !settings) return;
    if (settings.consent.required) {
      const { AiConsentDialog } = await import('./ai-consent-dialog');
      const accepted = await this.overlay.result<boolean, number>(AiConsentDialog, {
        data: settings.consent.current_version,
        variant: 'drawer',
      });
      if (!accepted) return;
    }
    const request = chatRequest(this.question(), this.credentialId());
    this.sending.set(true);
    this.error.set(null);
    try {
      const preview = await this.ai.preview(request);
      this.draft.set(request, preview, this.credentialLabel(this.credentialId() ?? ''));
      await this.router.navigateByUrl('/app/ai/run', { replaceUrl: true });
    } catch (error) {
      this.error.set(this.errorText.message(error));
    } finally {
      this.sending.set(false);
    }
  }
}
