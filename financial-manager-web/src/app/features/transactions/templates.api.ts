import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, query } from '../../core/api/api';
import { Direction } from './transaction.model';

/**
 * A reusable title/category/description bundle for frequent operations
 * (plan.md sections 4.1, 11.9), offered as title autocomplete (section 7.6).
 */
export interface TransactionTemplate {
  id: string;
  direction: Direction;
  title: string;
  default_category_id?: string | null;
  default_description?: string | null;
  usage_count: number;
}

/**
 * The backend's transactions.NormalizeTitle (section 4.4): trimmed, inner
 * spaces collapsed, case-insensitive. Tells when an edited title no longer
 * matches the template the user picked.
 */
export function normalizeTitle(title: string): string {
  return title.trim().replace(/\s+/g, ' ').toLowerCase();
}

/** /v1/transaction-templates. */
@Injectable({ providedIn: 'root' })
export class TemplatesApi {
  private readonly http = inject(HttpClient);

  async search(direction: Direction, q: string, limit = 8): Promise<TransactionTemplate[]> {
    const response = await firstValueFrom(
      this.http.get<{ templates: TransactionTemplate[] | null }>(api('/transaction-templates'), {
        params: query({ direction, q: q.trim(), limit }),
      }),
    );
    return response.templates ?? [];
  }

  create(body: {
    direction: Direction;
    title: string;
    default_category_id: string | null;
    default_description: string | null;
  }): Promise<TransactionTemplate> {
    return firstValueFrom(this.http.post<TransactionTemplate>(api('/transaction-templates'), body));
  }

  update(
    id: string,
    body: { title: string; default_category_id: string | null; default_description: string | null },
  ): Promise<TransactionTemplate> {
    return firstValueFrom(
      this.http.patch<TransactionTemplate>(api(`/transaction-templates/${id}`), body),
    );
  }
}
