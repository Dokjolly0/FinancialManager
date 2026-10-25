import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import type { IconNode } from 'lucide';
import { CornerDownLeft, Search } from 'lucide';

import { Icon } from '../shared/ui/icon';
import { AddActions } from './add-actions';
import type { NavItem } from './app-shell';

interface Command {
  id: string;
  label: string;
  group: 'pages' | 'actions';
  icon: IconNode;
  run: () => void;
}

/** Ctrl+K: jump to a page or start an action by typing. */
@Component({
  selector: 'app-command-palette',
  imports: [Icon, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="flex flex-col">
      <label class="flex items-center gap-3 border-b border-border px-4">
        <app-icon [icon]="Search" [size]="18" class="text-fg-muted" />
        <input
          class="h-14 flex-1 bg-transparent text-base text-fg outline-none placeholder:text-fg-muted"
          [placeholder]="'webCommandPlaceholder' | transloco"
          [attr.aria-label]="'webCommandHint' | transloco"
          [value]="query()"
          (input)="setQuery($any($event.target).value)"
          (keydown)="onKey($event)"
          autocomplete="off"
          cdkFocusInitial
        />
      </label>
      <div class="max-h-96 overflow-y-auto p-2" role="listbox">
        @for (group of groups(); track group.key) {
          <p class="section-title px-3 pb-1 pt-3">{{ group.labelKey | transloco }}</p>
          @for (command of group.items; track command.id) {
            <button
              type="button"
              role="option"
              class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm text-fg"
              [class.bg-surface-2]="command === active()"
              [attr.aria-selected]="command === active()"
              (mouseenter)="activeIndex.set(filtered().indexOf(command))"
              (click)="run(command)"
            >
              <app-icon [icon]="command.icon" [size]="18" class="text-fg-muted" />
              <span class="flex-1">{{ command.label }}</span>
              @if (command === active()) {
                <app-icon [icon]="CornerDownLeft" [size]="14" class="text-fg-muted" />
              }
            </button>
          }
        } @empty {
          <p class="px-3 py-8 text-center text-sm text-fg-muted">
            {{ 'webCommandEmpty' | transloco }}
          </p>
        }
      </div>
    </div>
  `,
})
export class CommandPalette {
  private readonly ref = inject(DialogRef);
  private readonly router = inject(Router);
  private readonly transloco = inject(TranslocoService);
  private readonly data = inject<{ nav: NavItem[] }>(DIALOG_DATA);
  private readonly add = inject(AddActions);

  protected readonly Search = Search;
  protected readonly CornerDownLeft = CornerDownLeft;
  protected readonly query = signal('');
  protected readonly activeIndex = signal(0);

  private readonly commands = computed<Command[]>(() => [
    ...this.data.nav.map((item) => ({
      id: item.path,
      label: this.transloco.translate(item.labelKey),
      group: 'pages' as const,
      icon: item.icon,
      run: () => void this.router.navigateByUrl(item.path),
    })),
    ...this.add.actions().map((action) => ({
      id: `add:${action.id}`,
      label: this.transloco.translate(action.labelKey),
      group: 'actions' as const,
      icon: action.icon,
      run: action.run,
    })),
  ]);

  protected readonly filtered = computed(() => {
    const words = normalize(this.query()).split(/\s+/).filter(Boolean);
    return this.commands().filter((command) => {
      const label = normalize(command.label);
      return words.every((word) => label.includes(word));
    });
  });

  protected readonly groups = computed(() =>
    (['pages', 'actions'] as const)
      .map((key) => ({
        key,
        labelKey: key === 'pages' ? 'webCommandGroupPages' : 'webCommandGroupActions',
        items: this.filtered().filter((command) => command.group === key),
      }))
      .filter((group) => group.items.length > 0),
  );

  protected readonly active = computed(() => this.filtered()[this.activeIndex()]);

  protected setQuery(value: string): void {
    this.query.set(value);
    this.activeIndex.set(0);
  }

  protected onKey(event: KeyboardEvent): void {
    const count = this.filtered().length;
    if (event.key === 'ArrowDown' && count > 0) {
      event.preventDefault();
      this.activeIndex.update((index) => (index + 1) % count);
    } else if (event.key === 'ArrowUp' && count > 0) {
      event.preventDefault();
      this.activeIndex.update((index) => (index - 1 + count) % count);
    } else if (event.key === 'Enter') {
      const command = this.active();
      if (command) this.run(command);
    }
  }

  protected run(command: Command): void {
    this.ref.close();
    command.run();
  }
}

/** Lower case without accents: "Attività" matches "attivita". */
function normalize(text: string): string {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
}
