import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  inject,
  input,
  signal,
  viewChild,
} from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';

import { GoogleIdentity } from '../../core/auth/google-identity';
import { LocaleService } from '../../core/formatting/locale.service';
import { ThemeService } from '../../core/theme/theme.service';
import { Spinner } from './states';

/**
 * Google's rendered "Continue with Google" button. The ID token of a
 * sign-in arrives on GoogleIdentity.credentials; the page listening there
 * decides whether it is a login or a link.
 */
@Component({
  selector: 'app-google-button',
  host: { class: 'block' },
  imports: [Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="flex min-h-11 items-center justify-center">
      @if (busy()) {
        <app-spinner [size]="22" class="text-primary" />
      }
      <!-- Google's button is an iframe whose page declares no color-scheme:
           under the dark theme's color-scheme the browser paints an opaque
           white backdrop behind it. "light" matches that page, so the
           iframe stays transparent around the filled_black button. -->
      <div #slot class="w-full max-w-[400px] [color-scheme:light]" [class.hidden]="busy()"></div>
    </div>
    @if (failed()) {
      <p class="hint text-center">{{ 'webGoogleUnavailable' | transloco }}</p>
    }
  `,
})
export class GoogleButton {
  /** Shows a spinner instead, while the token is being exchanged. */
  readonly busy = input(false);

  private readonly google = inject(GoogleIdentity);
  private readonly locale = inject(LocaleService);
  private readonly theme = inject(ThemeService);
  private readonly slot = viewChild.required<ElementRef<HTMLElement>>('slot');
  protected readonly failed = signal(false);

  constructor() {
    effect(() => {
      const element = this.slot().nativeElement;
      const language = this.locale.language();
      const dark = this.theme.dark();
      this.google
        .renderButton(element, language, dark)
        .then(() => this.failed.set(false))
        .catch(() => this.failed.set(true));
    });
  }
}
