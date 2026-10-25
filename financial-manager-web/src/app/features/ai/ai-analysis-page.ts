import { Location } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  OnDestroy,
  OnInit,
  computed,
  inject,
  input,
  signal,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Copy, Download, Pencil, SendHorizontal, Square, Trash2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { saveFile } from '../../core/files/save-file';
import { AppDatePipe } from '../../core/formatting/pipes';
import { LocaleService } from '../../core/formatting/locale.service';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { TextPromptData, TextPromptDialog } from '../../shared/ui/text-prompt-dialog';
import { Toasts } from '../../shared/ui/toast';
import { AiDraft } from './ai-draft';
import { AiApi } from './ai.api';
import {
  AI_CHAT_PRESET,
  AI_QUESTION_MAX_LENGTH,
  AiAnalysisDetail,
  AiMessage,
  AiStatus,
  AiStreamEvent,
  PROVIDER_LABELS,
} from './ai.model';
import { Markdown } from './markdown';

/** The message being written by the model right now. */
interface Live {
  kind: 'REPORT' | 'ANSWER';
  question?: string;
  content: string;
  status: AiStatus;
  errorCode?: string;
  inputTokens?: number;
  outputTokens?: number;
  truncated?: boolean;
}

/**
 * An analysis and its conversation (plan.md section 32.7): the report
 * written as it streams (stop keeps what was written), the data that was
 * sent, follow-up questions (up to the server's limit), copy, Markdown
 * download, rename, delete. /app/ai/run starts the previewed draft; once the
 * server names the analysis the URL becomes /app/ai/analyses/:id. A chat
 * (plan.md section 34) is the same page with its first question shown as
 * the first message, and the transactions searched for a question under it.
 */
@Component({
  selector: 'app-ai-analysis-page',
  imports: [
    AppDatePipe,
    FormsModule,
    Icon,
    InlineError,
    Markdown,
    PageHeader,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './ai-analysis-page.html',
})
export class AiAnalysisPage implements OnInit, OnDestroy {
  /** Route param of /app/ai/analyses/:id; absent on /app/ai/run. */
  readonly id = input<string>();

  private readonly ai = inject(AiApi);
  private readonly draft = inject(AiDraft);
  private readonly router = inject(Router);
  private readonly location = inject(Location);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly locale = inject(LocaleService);
  protected readonly errorText = inject(ErrorText);

  protected readonly icons = { Copy, Download, Pencil, SendHorizontal, Square, Trash2 };
  protected readonly questionMax = AI_QUESTION_MAX_LENGTH;

  protected readonly detail = signal<AiAnalysisDetail | null>(null);
  protected readonly loading = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly live = signal<Live | null>(null);
  protected readonly streamError = signal<string | null>(null);
  protected readonly question = signal('');
  /** A new chat's first question, until the stored one arrives. */
  private readonly draftQuestion = signal<string | null>(null);
  private analysisId: string | null = null;
  private abort: AbortController | null = null;

  protected readonly streaming = computed(() => this.live()?.status === 'STREAMING');
  /** A chat's first question; null for reports. */
  protected readonly chatQuestion = computed(() => {
    const d = this.detail();
    if (d) return d.preset === AI_CHAT_PRESET ? (d.question ?? null) : null;
    return this.draftQuestion();
  });
  /** Messages shown as the conversation; the CONTEXT one is "what was sent". */
  protected readonly messages = computed(() =>
    (this.detail()?.messages ?? []).filter((m) => m.kind !== 'CONTEXT'),
  );
  protected readonly sent = computed(
    () => this.detail()?.messages.find((m) => m.kind === 'CONTEXT') ?? null,
  );
  protected readonly report = computed(
    () =>
      this.detail()?.messages.find((m) => m.kind === 'REPORT')?.content ??
      (this.live()?.kind === 'REPORT' ? this.live()!.content : ''),
  );
  protected readonly providerLabel = computed(() => {
    const provider = this.detail()?.provider ?? '';
    return PROVIDER_LABELS[provider] ?? this.transloco.translate('aiProviderCompatible');
  });

  ngOnInit(): void {
    const id = this.id();
    if (id) {
      this.analysisId = id;
      void this.load();
      return;
    }
    const request = this.draft.request();
    const preview = this.draft.preview();
    if (!request || !preview) {
      void this.router.navigateByUrl('/app/ai/new');
      return;
    }
    if (request.preset === AI_CHAT_PRESET) this.draftQuestion.set(request.instructions);
    this.draft.clear();
    void this.consume('REPORT', undefined, (signal) =>
      this.ai.run(
        {
          ...request,
          data_fingerprint: preview.data_fingerprint,
          client_request_id: crypto.randomUUID(),
        },
        signal,
      ),
    );
  }

  ngOnDestroy(): void {
    this.abort?.abort();
  }

  protected async load(): Promise<void> {
    if (!this.analysisId) return;
    this.loading.set(!this.detail());
    this.loadError.set(null);
    try {
      this.detail.set(await this.ai.get(this.analysisId));
    } catch (error) {
      this.loadError.set(this.errorText.message(error));
    } finally {
      this.loading.set(false);
    }
  }

  /** Reads a stream into the live message, then reloads the stored conversation. */
  private async consume(
    kind: Live['kind'],
    question: string | undefined,
    start: (signal: AbortSignal) => AsyncGenerator<AiStreamEvent>,
  ): Promise<void> {
    this.abort = new AbortController();
    this.streamError.set(null);
    this.live.set({ kind, question, content: '', status: 'STREAMING' });
    try {
      for await (const event of start(this.abort.signal)) this.apply(event);
      if (this.live()?.status === 'STREAMING') this.patch({ status: 'COMPLETED' });
    } catch (error) {
      const appError = this.errorText.present(error);
      const cancelled = error instanceof DOMException && error.name === 'AbortError';
      this.patch({ status: cancelled ? 'CANCELLED' : 'FAILED' });
      if (!cancelled) this.streamError.set(appError.message);
    } finally {
      this.abort = null;
    }
    if (this.analysisId) {
      await this.load();
      // The stored conversation now holds the message: drop the live copy
      // unless nothing was stored (an error before the stream started).
      if (this.detail()) this.live.set(null);
    }
  }

  private apply(event: AiStreamEvent): void {
    switch (event.type) {
      case 'meta':
        if (!this.analysisId) {
          this.analysisId = event.analysisId;
          // Same page, real URL: a reload or a bookmark opens this analysis.
          this.location.replaceState(`/app/ai/analyses/${event.analysisId}`);
        }
        break;
      case 'delta':
        this.live.update((live) => (live ? { ...live, content: live.content + event.text } : live));
        break;
      case 'usage':
        this.patch({
          inputTokens: event.inputTokens,
          outputTokens: event.outputTokens,
          truncated: event.truncated,
        });
        break;
      case 'error':
        this.patch({ status: 'FAILED', errorCode: event.code });
        this.streamError.set(this.errorText.code(event.code));
        break;
      case 'done':
        this.patch({ status: event.status });
        break;
    }
  }

  private patch(changes: Partial<Live>): void {
    this.live.update((live) => (live ? { ...live, ...changes } : live));
  }

  /** Closing the connection is "stop" for the server: it keeps the partial text. */
  protected stop(): void {
    this.abort?.abort();
  }

  protected async ask(): Promise<void> {
    const content = this.question().trim();
    const id = this.analysisId;
    if (!content || !id || this.streaming()) return;
    this.question.set('');
    await this.consume('ANSWER', content, (signal) => this.ai.ask(id, content, signal));
  }

  /** Enter sends, Shift+Enter starts a new line. */
  protected onEnter(event: KeyboardEvent): void {
    if (event.shiftKey) return;
    event.preventDefault();
    void this.ask();
  }

  protected copy(): void {
    void navigator.clipboard
      .writeText(this.report())
      .then(() => this.toasts.success(this.transloco.translate('aiCopied')));
  }

  /** The report and the answers as a Markdown file (the app's "download" on the web). */
  protected download(): void {
    const d = this.detail();
    const quote = (text: string) => `> ${text.replace(/\n/g, '\n> ')}`;
    const first = this.chatQuestion();
    const parts = [
      ...(first ? [quote(first)] : []),
      ...(d?.messages ?? [])
        .filter((m) => m.kind !== 'CONTEXT')
        .map((m) => (m.kind === 'QUESTION' ? quote(m.content) : m.content)),
    ];
    const body = `# ${d?.title ?? this.transloco.translate('aiAnalysisTitle')}\n\n${parts.join('\n\n---\n\n')}\n`;
    saveFile(body, `analisi-${d?.id ?? 'report'}.md`, 'text/markdown');
  }

  protected async rename(): Promise<void> {
    const d = this.detail();
    if (!d) return;
    const title = await this.overlay.result<string, TextPromptData>(TextPromptDialog, {
      data: {
        title: this.transloco.translate('aiRenameTitle'),
        label: this.transloco.translate('titleFieldLabel'),
        value: d.title,
        confirmLabel: this.transloco.translate('commonSave'),
        maxLength: 200,
      },
    });
    if (!title) return;
    try {
      this.detail.set(await this.ai.rename(d.id, title));
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }

  protected async remove(): Promise<void> {
    const d = this.detail();
    if (!d) return;
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('aiDeleteAnalysisTitle'),
      confirmLabel: this.transloco.translate('aiDeleteAction'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.ai.delete(d.id);
      await this.router.navigateByUrl('/app/ai/analyses');
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }

  protected tokens(m: { input_tokens?: number | null; output_tokens?: number | null }): string {
    const format = new Intl.NumberFormat(this.locale.intl());
    return this.transloco.translate('aiTokensUsed', {
      input: format.format(m.input_tokens ?? 0),
      output: format.format(m.output_tokens ?? 0),
    });
  }

  protected cost(value: number): string {
    return new Intl.NumberFormat(this.locale.intl(), {
      maximumFractionDigits: value < 0.1 ? 4 : 2,
    }).format(value);
  }

  /** The note under an assistant message that didn't finish normally. */
  protected note(m: Pick<AiMessage, 'status' | 'truncated' | 'error_code'>): string | null {
    if (m.status === 'CANCELLED') return this.transloco.translate('aiAnswerStopped');
    if (m.status === 'FAILED') return this.errorText.code(m.error_code ?? 'AI_PROVIDER_ERROR');
    if (m.truncated) return this.transloco.translate('aiAnswerTruncated');
    return null;
  }

  /** Asked by the leave guard: leaving stops the model. */
  canLeave(): boolean {
    return !this.streaming();
  }
}
