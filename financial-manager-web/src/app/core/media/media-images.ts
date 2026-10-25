import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api } from '../api/api';

/**
 * Images stored by the backend (GET /v1/media/{id}) need the Bearer header,
 * which an <img src> can't send: they are fetched as blobs and shown through
 * object URLs, cached for the life of the page (one account per page, see
 * SessionService).
 */
@Injectable({ providedIn: 'root' })
export class MediaImages {
  private readonly http = inject(HttpClient);
  private readonly cache = new Map<string, Promise<string>>();

  url(mediaId: string): Promise<string> {
    let url = this.cache.get(mediaId);
    if (!url) {
      url = firstValueFrom(this.http.get(api(`/media/${mediaId}`), { responseType: 'blob' })).then(
        (blob) => URL.createObjectURL(blob),
      );
      // A failed load is retried next time instead of being cached.
      url.catch(() => this.cache.delete(mediaId));
      this.cache.set(mediaId, url);
    }
    return url;
  }

  /** Drops a deleted image. */
  forget(mediaId: string): void {
    const url = this.cache.get(mediaId);
    this.cache.delete(mediaId);
    void url?.then((objectUrl) => URL.revokeObjectURL(objectUrl)).catch(() => undefined);
  }
}
