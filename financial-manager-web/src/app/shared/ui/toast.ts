import { ChangeDetectionStrategy, Component, Injectable, inject, signal } from '@angular/core';
import { CircleAlert, CircleCheck, Info, X } from 'lucide';

import { Icon } from './icon';

export type ToastKind = 'success' | 'error' | 'info';

interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
}

/** Transient messages (the app's snack bars). */
@Injectable({ providedIn: 'root' })
export class Toasts {
  private nextId = 1;
  readonly items = signal<ToastItem[]>([]);

  show(message: string, kind: ToastKind = 'info', durationMs = 4500): void {
    const id = this.nextId++;
    this.items.update((items) => [...items.slice(-3), { id, kind, message }]);
    setTimeout(() => this.dismiss(id), durationMs);
  }

  success(message: string): void {
    this.show(message, 'success');
  }

  error(message: string): void {
    this.show(message, 'error', 7000);
  }

  dismiss(id: number): void {
    this.items.update((items) => items.filter((item) => item.id !== id));
  }
}

@Component({
  selector: 'app-toaster',
  imports: [Icon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div
      class="pointer-events-none fixed inset-x-0 bottom-24 z-[1100] flex flex-col items-center gap-2 px-4 md:bottom-6 md:items-end md:px-6"
      aria-live="polite"
    >
      @for (toast of toasts.items(); track toast.id) {
        <div
          class="pointer-events-auto flex w-full max-w-sm animate-slide-in-up items-start gap-3 rounded-xl border border-border bg-surface px-4 py-3 text-sm text-fg shadow-pop"
          [attr.role]="toast.kind === 'error' ? 'alert' : 'status'"
        >
          @switch (toast.kind) {
            @case ('success') {
              <app-icon [icon]="CircleCheck" [size]="18" class="text-credit" />
            }
            @case ('error') {
              <app-icon [icon]="CircleAlert" [size]="18" class="text-debit" />
            }
            @default {
              <app-icon [icon]="Info" [size]="18" class="text-info" />
            }
          }
          <p class="min-w-0 flex-1 leading-snug">{{ toast.message }}</p>
          <button
            type="button"
            class="-m-1 rounded p-1 text-fg-muted hover:text-fg"
            aria-label="OK"
            (click)="toasts.dismiss(toast.id)"
          >
            <app-icon [icon]="X" [size]="16" />
          </button>
        </div>
      }
    </div>
  `,
})
export class Toaster {
  protected readonly toasts = inject(Toasts);
  protected readonly CircleCheck = CircleCheck;
  protected readonly CircleAlert = CircleAlert;
  protected readonly Info = Info;
  protected readonly X = X;
}
