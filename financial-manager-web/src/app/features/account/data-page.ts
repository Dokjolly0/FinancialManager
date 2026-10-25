import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Download, TriangleAlert } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { filenameFromDisposition, saveFile } from '../../core/files/save-file';
import { SessionService } from '../../core/session/session.service';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AccountApi, ExportRecord } from './account.api';
import { PasswordPromptData, PasswordPromptDialog } from './password-prompt-dialog';

const POLL_MS = 1500;
const POLL_LIMIT = 40;

/**
 * Data (plan.md sections 7.13, 20.2, 20.3): export as CSV or JSON, handed to
 * the browser as a download once the server has it ready, and account
 * deletion behind the password (optional for Google-only accounts).
 */
@Component({
  selector: 'app-data-page',
  imports: [Icon, PageHeader, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'accountDataMenuTitle' | transloco"
        back="/app/account"
        [backLabel]="'backAction' | transloco"
      />

      <section class="card card-pad">
        <h2 class="font-semibold text-fg">{{ 'exportDataSectionTitle' | transloco }}</h2>
        <p class="mt-1 text-sm leading-relaxed text-fg-muted">
          {{ 'exportDataDescription' | transloco }}
        </p>
        <div class="mt-5 flex flex-wrap gap-3">
          @for (format of formats; track format.value) {
            <button
              type="button"
              class="btn btn-outline"
              [disabled]="exporting() !== null"
              (click)="export(format.value)"
            >
              @if (exporting() === format.value) {
                <app-spinner />
              } @else {
                <app-icon [icon]="icons.Download" [size]="18" />
              }
              {{ format.key | transloco }}
            </button>
          }
        </div>
      </section>

      <section class="card card-pad mt-6 border-debit/40">
        <div class="flex items-start gap-3">
          <span
            class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-debit/10 text-debit"
          >
            <app-icon [icon]="icons.TriangleAlert" [size]="20" />
          </span>
          <div class="flex-1">
            <h2 class="font-semibold text-debit">{{ 'dangerZoneTitle' | transloco }}</h2>
            <p class="mt-1 text-sm leading-relaxed text-fg-muted">
              {{ 'deleteAccountConfirmMessage' | transloco }}
            </p>
            <button
              type="button"
              class="btn btn-danger mt-4"
              [disabled]="deleting()"
              (click)="deleteAccount()"
            >
              @if (deleting()) {
                <app-spinner />
              }
              {{ 'deleteAccountAction' | transloco }}
            </button>
          </div>
        </div>
      </section>
    </div>
  `,
})
export class DataPage {
  private readonly account = inject(AccountApi);
  private readonly session = inject(SessionService);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly icons = { Download, TriangleAlert };
  protected readonly formats = [
    { value: 'csv' as const, key: 'exportCsvAction' },
    { value: 'json' as const, key: 'exportJsonAction' },
  ];
  protected readonly exporting = signal<'csv' | 'json' | null>(null);
  protected readonly deleting = signal(false);

  protected async export(format: 'csv' | 'json'): Promise<void> {
    this.exporting.set(format);
    try {
      let record: ExportRecord = await this.account.requestExport(format);
      for (
        let i = 0;
        record.status !== 'ready' && record.status !== 'failed' && i < POLL_LIMIT;
        i++
      ) {
        await new Promise((resolve) => setTimeout(resolve, POLL_MS));
        record = await this.account.getExport(record.id);
      }
      if (record.status !== 'ready') {
        this.toasts.error(this.errorText.code('EXPORT_FAILED'));
        return;
      }
      const response = await this.account.downloadExport(record);
      const name =
        filenameFromDisposition(response.headers.get('Content-Disposition')) ??
        `export-${record.id}.${record.format}`;
      saveFile(response.body!, name);
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.exporting.set(null);
    }
  }

  protected async deleteAccount(): Promise<void> {
    const password = await this.overlay.result<string, PasswordPromptData>(PasswordPromptDialog, {
      data: {
        title: this.transloco.translate('deleteAccountConfirmTitle'),
        message: this.transloco.translate('deleteAccountConfirmMessage'),
        label: this.transloco.translate('currentPasswordOptionalGoogleLabel'),
        confirmLabel: this.transloco.translate('deleteAccountAction'),
        optional: true,
        destructive: true,
      },
    });
    if (password === undefined) return;
    this.deleting.set(true);
    try {
      await this.account.deleteAccount(password || null);
      await this.session.signOut();
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.deleting.set(false);
    }
  }
}
