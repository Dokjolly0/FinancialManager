import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  inject,
  input,
} from '@angular/core';
import type { IconNode } from 'lucide';

const SVG_NS = 'http://www.w3.org/2000/svg';

/**
 * A Lucide icon: `<app-icon [icon]="Plus" />` with the icon imported from
 * "lucide" where it's used, so only the icons in use are bundled. Built as
 * DOM nodes (no innerHTML), so it needs no sanitizer bypass.
 */
@Component({
  selector: 'app-icon',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: '',
  host: { class: 'inline-flex shrink-0', 'aria-hidden': 'true' },
})
export class Icon {
  readonly icon = input.required<IconNode>();
  readonly size = input(20);
  readonly strokeWidth = input(2);

  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  constructor() {
    effect(() => {
      const svg = document.createElementNS(SVG_NS, 'svg');
      const size = String(this.size());
      for (const [name, value] of Object.entries({
        width: size,
        height: size,
        viewBox: '0 0 24 24',
        fill: 'none',
        stroke: 'currentColor',
        'stroke-width': String(this.strokeWidth()),
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
      })) {
        svg.setAttribute(name, value);
      }
      for (const [tag, attrs] of this.icon()) {
        const child = document.createElementNS(SVG_NS, tag);
        for (const [name, value] of Object.entries(attrs)) {
          if (value !== undefined) child.setAttribute(name, String(value));
        }
        svg.appendChild(child);
      }
      this.host.nativeElement.replaceChildren(svg);
    });
  }
}
