import { Injectable, inject, signal } from '@angular/core';

import { SessionService } from '../../core/session/session.service';

/**
 * Whether balances are masked. Starts from the profile's "hide balance on
 * open" (plan.md section 7.13) and then follows the eye toggle for the rest
 * of the session; a later profile change never overrides a manual toggle.
 */
@Injectable({ providedIn: 'root' })
export class BalancePrivacy {
  readonly hidden = signal(inject(SessionService).profile()?.balance_hidden_default ?? false);

  toggle(): void {
    this.hidden.update((hidden) => !hidden);
  }
}
