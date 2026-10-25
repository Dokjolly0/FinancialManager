import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

/**
 * Generated avatar: initials of first and last name over the saved
 * background colour (plan.md section 7.14, the app's GeneratedAvatar).
 */
@Component({
  selector: 'app-avatar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `{{ initials() }}`,
  host: {
    class: 'inline-grid shrink-0 select-none place-items-center rounded-full font-semibold',
    '[style.width.px]': 'size()',
    '[style.height.px]': 'size()',
    '[style.font-size.px]': 'size() * 0.38',
    '[style.background-color]': 'background()',
    '[style.color]': 'foreground()',
    'aria-hidden': 'true',
  },
})
export class Avatar {
  readonly firstName = input('');
  readonly lastName = input('');
  readonly background = input('#176B5B');
  readonly foreground = input('#FFFFFF');
  readonly size = input(40);

  protected readonly initials = computed(() =>
    ((this.firstName().trim()[0] ?? '') + (this.lastName().trim()[0] ?? '')).toUpperCase(),
  );
}
