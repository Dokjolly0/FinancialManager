import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { History, Pencil, Sparkles, Trash2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { AppDatePipe } from '../../core/formatting/pipes';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, SkeletonList, Spinner } from '../../shared/ui/states';
import { TextPromptData, TextPromptDialog } from '../../shared/ui/text-prompt-dialog';
import { Toasts } from '../../shared/ui/toast';
import { AiApi } from './ai.api';
import { AiAnalysisSummary, PROVIDER_LABELS } from './ai.model';

/** Analysis history (plan.md section 32.7): read again, rename, delete one or all. */
@Component({
  selector: 'app-ai-history-page',
  imports: [
    AppDatePipe,
    EmptyState,
    Icon,
    InlineError,
    PageHeader,
    RouterLink,
    SkeletonList,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'aiHistoryTitle' | transloco"
        back="/app/account/ai"
        [backLabel]="'backAction' | transloco"
      >
        @if (items().length) {
          <button type="button" class="btn btn-danger-ghost" (click)="removeAll()">
            {{ 'aiDeleteAllAction' | transloco }}
          </button>
        }
        <a routerLink="/app/ai/new" class="btn btn-primary">
          <app-icon [icon]="icons.Sparkles" [size]="18" /> {{ 'aiNewAnalysisTitle' | transloco }}
        </a>
      </app-page-header>
      <div class="card divide-y divide-border overflow-hidden">
        @if (loading()) {
          <app-skeleton-list [rows]="4" />
        } @else if (error()) {
          <app-inline-error [message]="error()!" (retry)="load(true)" />
        } @else {
          @for (a of items(); track a.id) {
            <div class="flex items-center gap-2 pr-2">
              <a [routerLink]="['/app/ai/analyses', a.id]" class="list-row min-w-0 flex-1">
                <span
                  class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-primary-soft text-primary"
                >
                  <app-icon [icon]="icons.Sparkles" [size]="18" />
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate text-sm font-medium text-fg">{{ a.title }}</span>
                  <span class="block truncate text-xs text-fg-muted">
                    {{ a.created_at | appDate: 'dateTime' }} · {{ provider(a) }} · {{ a.model }}
                  </span>
                </span>
                @if (a.status !== 'COMPLETED') {
                  <span
                    class="badge"
                    [class]="
                      a.status === 'FAILED'
                        ? 'bg-debit/10 text-debit'
                        : 'bg-warning/10 text-warning'
                    "
                  >
                    {{ statusKey(a) | transloco }}
                  </span>
                }
              </a>
              <button
                type="button"
                class="btn btn-ghost btn-icon btn-sm"
                [attr.aria-label]="'aiRenameAction' | transloco"
                (click)="rename(a)"
              >
                <app-icon [icon]="icons.Pencil" [size]="16" />
              </button>
              <button
                type="button"
                class="btn btn-ghost btn-icon btn-sm text-debit"
                [attr.aria-label]="'aiDeleteAction' | transloco"
                (click)="remove(a)"
              >
                <app-icon [icon]="icons.Trash2" [size]="16" />
              </button>
            </div>
          } @empty {
            <app-empty-state [message]="'aiHistoryEmpty' | transloco" [icon]="icons.History">
              <a routerLink="/app/ai/new" class="btn btn-primary btn-sm">{{
                'aiNewAnalysisTitle' | transloco
              }}</a>
            </app-empty-state>
          }
        }
      </div>
      @if (cursor()) {
        <div class="flex justify-center py-5">
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            [disabled]="loadingMore()"
            (click)="load(false)"
          >
            @if (loadingMore()) {
              <app-spinner />
            }
            {{ 'webLoadMore' | transloco }}
          </button>
        </div>
      }
    </div>
  `,
})
export class AiHistoryPage implements OnInit {
  private readonly ai = inject(AiApi);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly icons = { History, Pencil, Sparkles, Trash2 };
  protected readonly items = signal<AiAnalysisSummary[]>([]);
  protected readonly cursor = signal<string | null>(null);
  protected readonly loading = signal(true);
  protected readonly loadingMore = signal(false);
  protected readonly error = signal<string | null>(null);

  ngOnInit(): void {
    void this.load(true);
  }

  protected async load(reset: boolean): Promise<void> {
    if (reset) {
      this.loading.set(true);
      this.error.set(null);
    } else {
      this.loadingMore.set(true);
    }
    try {
      const page = await this.ai.list(reset ? null : this.cursor());
      this.items.update((items) =>
        reset ? (page.items ?? []) : [...items, ...(page.items ?? [])],
      );
      this.cursor.set(page.next_cursor ?? null);
    } catch (error) {
      if (reset) this.error.set(this.errorText.message(error));
      else this.toasts.error(this.errorText.message(error));
    } finally {
      this.loading.set(false);
      this.loadingMore.set(false);
    }
  }

  protected provider(a: AiAnalysisSummary): string {
    return PROVIDER_LABELS[a.provider] ?? this.transloco.translate('aiProviderCompatible');
  }

  protected statusKey(a: AiAnalysisSummary): string {
    return a.status === 'FAILED'
      ? 'webAiStatusFailed'
      : a.status === 'CANCELLED'
        ? 'webAiStatusCancelled'
        : 'webAiStatusStreaming';
  }

  protected async rename(a: AiAnalysisSummary): Promise<void> {
    const title = await this.overlay.result<string, TextPromptData>(TextPromptDialog, {
      data: {
        title: this.transloco.translate('aiRenameTitle'),
        label: this.transloco.translate('titleFieldLabel'),
        value: a.title,
        confirmLabel: this.transloco.translate('commonSave'),
        maxLength: 200,
      },
    });
    if (!title) return;
    try {
      const renamed = await this.ai.rename(a.id, title);
      this.items.update((items) =>
        items.map((i) => (i.id === a.id ? { ...i, title: renamed.title } : i)),
      );
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }

  protected async remove(a: AiAnalysisSummary): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('aiDeleteAnalysisTitle'),
      message: a.title,
      confirmLabel: this.transloco.translate('aiDeleteAction'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.ai.delete(a.id);
      this.items.update((items) => items.filter((i) => i.id !== a.id));
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }

  protected async removeAll(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('aiDeleteAllTitle'),
      message: this.transloco.translate('aiDeleteAllMessage'),
      confirmLabel: this.transloco.translate('aiDeleteAllAction'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.ai.deleteAll();
      this.items.set([]);
      this.cursor.set(null);
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }
}
