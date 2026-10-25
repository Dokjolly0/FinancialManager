import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, query } from '../../core/api/api';
import { MediaImages } from '../../core/media/media-images';

/** What an image is attached to (plan.md section 11.8); every kind is a 1:1 crop. */
export type MediaKind = 'profile' | 'transaction' | 'category';

/** A stored image, always shown through the authenticated /v1/media/{id}. */
export interface MediaAsset {
  id: string;
  kind: MediaKind;
  source: string;
  attribution?: string | null;
  name?: string | null;
  mime_type: string;
  width: number;
  height: number;
  created_at: string;
}

/** A result of the image search provider; nothing is stored until it is picked. */
export interface MediaSearchResult {
  external_id: string;
  thumb_url: string;
  attribution: string;
  width: number;
  height: number;
}

/** /v1/media* (plan.md sections 14.8, 16). */
@Injectable({ providedIn: 'root' })
export class MediaApi {
  private readonly http = inject(HttpClient);
  private readonly images = inject(MediaImages);

  async list(kind: MediaKind, recent: boolean, q = '', limit = 60): Promise<MediaAsset[]> {
    const response = await firstValueFrom(
      this.http.get<{ media: MediaAsset[] | null }>(api('/media'), {
        params: query({ kind, sort: recent ? 'recent' : undefined, limit, q: q.trim() }),
      }),
    );
    return response.media ?? [];
  }

  async search(q: string, page = 1, limit = 30): Promise<MediaSearchResult[]> {
    const response = await firstValueFrom(
      this.http.get<{ results: MediaSearchResult[] | null }>(api('/media/search'), {
        params: query({ q, page, limit }),
      }),
    );
    return response.results ?? [];
  }

  /** Uploads a cropped image (multipart: kind + file). */
  upload(kind: MediaKind, file: Blob, filename = 'image.jpg'): Promise<MediaAsset> {
    const form = new FormData();
    form.append('kind', kind);
    form.append('file', file, filename);
    return firstValueFrom(this.http.post<MediaAsset>(api('/media/uploads'), form));
  }

  /** Stores a search result as the user's own asset. */
  selectFromSearch(
    kind: MediaKind,
    externalId: string,
    provider = 'unsplash',
  ): Promise<MediaAsset> {
    return firstValueFrom(
      this.http.post<MediaAsset>(api('/media/uploads'), {
        kind,
        provider,
        external_id: externalId,
      }),
    );
  }

  rename(id: string, name: string): Promise<MediaAsset> {
    return firstValueFrom(this.http.patch<MediaAsset>(api(`/media/${id}`), { name }));
  }

  async delete(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(api(`/media/${id}`)));
    this.images.forget(id);
  }
}
