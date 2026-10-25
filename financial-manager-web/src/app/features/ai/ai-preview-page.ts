import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Coins, Database, EyeOff, FileText, Send, User, Wallet } from 'lucide';

import { LocaleService } from '../../core/formatting/locale.service';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { AiDraft } from './ai-draft';
import { AI_INSTRUCTIONS_MAX_LENGTH, PROVIDER_LABELS, SECTION_KEYS } from './ai.model';

/**
 * The exact prompt before anything is sent (plan.md section 32.4): who gets
 * it, what it discloses, token and cost estimate, the read-only rules and
 * data, and the instructions, which can be edited (they aren't part of the
 * data fingerprint).
 */
@Component({
  selector: 'app-ai-preview-page',
  imports: [FormsModule, Icon, PageHeader, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'aiPreviewTitle' | transloco"
        back="/app/ai/new"
        [backLabel]="'backAction' | transloco"
      />
      @if (draft.preview(); as p) {
        <section class="card card-pad">
          <p class="text-sm font-semibold text-fg">
            {{ 'aiPreviewSentTo' | transloco: { provider: providerLabel(), model: p.model } }}
          </p>
          <ul class="mt-4 grid gap-2 text-sm text-fg sm:grid-cols-2">
            <li class="flex items-center gap-2">
              <app-icon [icon]="icons.Wallet" [size]="16" class="text-fg-muted" />
              {{ 'aiPreviewWallets' | transloco: { count: p.disclosure.wallet_count } }}
            </li>
            <li class="flex items-center gap-2">
              <app-icon [icon]="icons.Database" [size]="16" class="text-fg-muted" />
              @if (p.disclosure.sections.length) {
                {{ 'aiPreviewSections' | transloco: { sections: sectionList() } }}
              } @else {
                {{ 'aiPreviewOnlyTotals' | transloco }}
              }
            </li>
            <li class="flex items-center gap-2">
              <app-icon [icon]="icons.FileText" [size]="16" class="text-fg-muted" />
              @if (p.disclosure.transaction_count > 0) {
                {{
                  'aiPreviewTransactions'
                    | transloco
                      : {
                          count: p.disclosure.transaction_count,
                          omitted: p.disclosure.transactions_omitted,
                        }
                }}
              } @else {
                {{ 'aiPreviewNoTransactions' | transloco }}
              }
            </li>
            @if (p.disclosure.anonymized) {
              <li class="flex items-center gap-2">
                <app-icon [icon]="icons.EyeOff" [size]="16" class="text-fg-muted" />{{
                  'aiPreviewAnonymized' | transloco
                }}
              </li>
            }
            @if (p.disclosure.includes_personal_context) {
              <li class="flex items-center gap-2">
                <app-icon [icon]="icons.User" [size]="16" class="text-fg-muted" />{{
                  'aiPreviewWithContext' | transloco
                }}
              </li>
            }
            <li class="flex items-center gap-2">
              <app-icon [icon]="icons.Coins" [size]="16" class="text-fg-muted" />
              {{ 'aiPreviewTokens' | transloco: { tokens: number(p.estimated_input_tokens) } }} ·
              @if (p.estimated_cost; as cost) {
                {{
                  'aiPreviewCost'
                    | transloco: { cost: costText(cost.input_cost + cost.max_output_cost) }
                }}
              } @else {
                {{ 'aiPreviewNoCost' | transloco }}
              }
            </li>
          </ul>
          @if (p.disclosure.compaction_steps?.length) {
            <p class="mt-3 rounded-xl bg-warning/10 px-3 py-2 text-xs text-warning">
              {{
                'aiPreviewCompacted' | transloco: { count: p.disclosure.compaction_steps!.length }
              }}
            </p>
          }
        </section>

        <section class="card card-pad mt-6">
          <label class="label" for="ai-instructions">{{ 'aiInstructionsLabel' | transloco }}</label>
          <textarea
            id="ai-instructions"
            class="input font-mono text-[13px]"
            rows="8"
            [maxlength]="max"
            [ngModel]="instructions()"
            (ngModelChange)="instructions.set($event)"
            [attr.aria-invalid]="!instructions().trim() || null"
          ></textarea>
          <div class="mt-1.5 flex items-center justify-between gap-3">
            <p class="hint mt-0">
              {{
                (instructions().trim() ? 'aiInstructionsHint' : 'aiInstructionsRequired')
                  | transloco
              }}
            </p>
            @if (instructions() !== p.instructions) {
              <button
                type="button"
                class="text-xs font-semibold text-primary hover:underline"
                (click)="instructions.set(p.instructions)"
              >
                {{ 'aiRestoreInstructions' | transloco }}
              </button>
            }
          </div>
        </section>

        <details class="card card-pad mt-6">
          <summary class="cursor-pointer select-none text-sm font-semibold text-fg">
            {{ 'aiSystemPromptLabel' | transloco }}
          </summary>
          <p class="hint">{{ 'aiSystemPromptHint' | transloco }}</p>
          <pre
            class="mt-3 max-h-96 overflow-auto whitespace-pre-wrap rounded-xl bg-surface-2 p-4 text-xs leading-relaxed text-fg"
            >{{ p.system_prompt }}</pre>
        </details>
        <details class="card card-pad mt-4">
          <summary class="cursor-pointer select-none text-sm font-semibold text-fg">
            {{ 'aiDataBlockLabel' | transloco }}
          </summary>
          <p class="hint">{{ 'aiDataBlockHint' | transloco }}</p>
          <pre
            class="mt-3 max-h-96 overflow-auto whitespace-pre-wrap rounded-xl bg-surface-2 p-4 text-xs leading-relaxed text-fg"
            >{{ p.data_block }}</pre>
        </details>

        <div class="mt-6 flex justify-end">
          <button
            type="button"
            class="btn btn-primary btn-lg"
            [disabled]="!instructions().trim()"
            (click)="send()"
          >
            <app-icon [icon]="icons.Send" [size]="18" /> {{ 'aiSendAction' | transloco }}
          </button>
        </div>
      }
    </div>
  `,
})
export class AiPreviewPage {
  protected readonly draft = inject(AiDraft);
  private readonly router = inject(Router);
  private readonly transloco = inject(TranslocoService);
  private readonly locale = inject(LocaleService);

  protected readonly icons = { Coins, Database, EyeOff, FileText, Send, User, Wallet };
  protected readonly max = AI_INSTRUCTIONS_MAX_LENGTH;
  protected readonly instructions = signal(this.draft.preview()?.instructions ?? '');

  protected readonly providerLabel = computed(() => {
    const provider = this.draft.preview()?.provider ?? '';
    return PROVIDER_LABELS[provider] ?? this.transloco.translate('aiProviderCompatible');
  });
  protected readonly sectionList = computed(() =>
    (this.draft.preview()?.disclosure.sections ?? [])
      .map((s) => this.transloco.translate(SECTION_KEYS[s]))
      .join(', '),
  );

  constructor() {
    // Reloaded page: the draft is gone, start again.
    if (!this.draft.preview()) void this.router.navigateByUrl('/app/ai/new');
  }

  protected number(value: number): string {
    return new Intl.NumberFormat(this.locale.intl()).format(value);
  }

  /** User-entered prices carry no currency: just the number, more digits when tiny. */
  protected costText(cost: number): string {
    return new Intl.NumberFormat(this.locale.intl(), {
      maximumFractionDigits: cost < 0.1 ? 4 : 2,
    }).format(cost);
  }

  protected send(): void {
    const request = this.draft.request();
    if (!request) return;
    this.draft.request.set({ ...request, instructions: this.instructions().trim() });
    void this.router.navigateByUrl('/app/ai/run');
  }
}
