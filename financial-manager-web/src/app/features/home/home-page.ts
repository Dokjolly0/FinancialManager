import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';

import { SessionService } from '../../core/session/session.service';
import { PageHeader } from '../../shared/ui/page-header';

/** Home (plan.md section 7.5). */
@Component({
  selector: 'app-home-page',
  imports: [PageHeader, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-page-header
      [title]="'webGreeting' | transloco: { name: session.profile()?.first_name ?? '' }"
    />
  `,
})
export class HomePage {
  protected readonly session = inject(SessionService);
}
