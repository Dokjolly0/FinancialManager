import { Directive, ElementRef, effect, inject, input } from '@angular/core';

import { MediaImages } from '../../core/media/media-images';

/**
 * `<img [appMediaSrc]="mediaId">`: loads a stored image with the session's
 * token (MediaImages) and sets it as the src once ready.
 */
@Directive({ selector: 'img[appMediaSrc]' })
export class MediaSrc {
  readonly appMediaSrc = input<string | null | undefined>();

  private readonly images = inject(MediaImages);
  private readonly element = inject<ElementRef<HTMLImageElement>>(ElementRef);

  constructor() {
    effect(() => {
      const id = this.appMediaSrc();
      const img = this.element.nativeElement;
      img.removeAttribute('src');
      if (!id) return;
      this.images
        .url(id)
        .then((url) => {
          if (this.appMediaSrc() === id) img.src = url;
        })
        .catch(() => undefined);
    });
  }
}
