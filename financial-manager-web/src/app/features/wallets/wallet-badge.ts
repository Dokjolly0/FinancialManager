import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

import { Icon } from '../../shared/ui/icon';
import { walletIcon } from './wallet-icons';

/** A wallet's icon on its colour, as every wallet row shows it. */
@Component({
  selector: 'app-wallet-badge',
  imports: [Icon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<app-icon [icon]="glyph()" [size]="Math.round(size() * 0.5)" />`,
  host: {
    class: 'inline-grid shrink-0 place-items-center rounded-xl text-white',
    '[style.width.px]': 'size()',
    '[style.height.px]': 'size()',
    '[style.background-color]': 'color()',
    'aria-hidden': 'true',
  },
})
export class WalletBadge {
  readonly icon = input.required<string>();
  readonly color = input.required<string>();
  readonly size = input(40);
  protected readonly glyph = computed(() => walletIcon(this.icon()));
  protected readonly Math = Math;
}
