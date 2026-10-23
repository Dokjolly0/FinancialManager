import { Directive, ElementRef, OnDestroy, OnInit, inject, output } from '@angular/core';

/** Emits when the element scrolls into view (infinite lists load the next page). */
@Directive({ selector: '[appInView]' })
export class InView implements OnInit, OnDestroy {
  readonly appInView = output<void>();
  private readonly element = inject<ElementRef<HTMLElement>>(ElementRef);
  private observer?: IntersectionObserver;

  ngOnInit(): void {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.appInView.emit();
      },
      { rootMargin: '400px' },
    );
    this.observer.observe(this.element.nativeElement);
  }

  ngOnDestroy(): void {
    this.observer?.disconnect();
  }
}
