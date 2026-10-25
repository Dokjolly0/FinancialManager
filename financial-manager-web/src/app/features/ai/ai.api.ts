import { HttpClient, httpResource } from '@angular/common/http';
import { Injectable, computed, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, query } from '../../core/api/api';
import { SseClient, sseJson } from '../../core/api/sse';
import {
  AiAnalysisDetail,
  AiAnalysisRequest,
  AiAnalysisSummary,
  AiHistoryType,
  AiPreset,
  AiPreview,
  AiProbeRequest,
  AiProbeResult,
  AiSettings,
  AiSettingsRequest,
  AiStatus,
  AiStreamEvent,
  AiUserContext,
  isReady,
  usableCredentials,
} from './ai.model';

/** /v1/ai/* for the cloud analyses (plan.md section 32.4). */
@Injectable({ providedIn: 'root' })
export class AiApi {
  private readonly http = inject(HttpClient);
  private readonly sse = inject(SseClient);

  /** The settings, shared by every AI page and reloaded after changes. */
  readonly settings = httpResource<AiSettings>(() => api('/ai/settings'));
  readonly ready = computed(() => {
    const settings = this.settings.value();
    return !!settings && isReady(settings);
  });
  readonly credentials = computed(() => {
    const settings = this.settings.value();
    return settings ? usableCredentials(settings) : [];
  });

  async saveSettings(body: AiSettingsRequest): Promise<AiSettings> {
    const settings = await firstValueFrom(this.http.put<AiSettings>(api('/ai/settings'), body));
    this.settings.set(settings);
    return settings;
  }

  test(body: AiProbeRequest): Promise<AiProbeResult> {
    return firstValueFrom(this.http.post<AiProbeResult>(api('/ai/settings/test'), body));
  }

  async models(body: AiProbeRequest): Promise<{ id: string; display_name: string }[]> {
    const response = await firstValueFrom(
      this.http.post<{ models: { id: string; display_name: string }[] | null }>(
        api('/ai/models'),
        body,
      ),
    );
    return response.models ?? [];
  }

  async deleteCredential(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(api(`/ai/credentials/${id}`)));
    this.settings.reload();
  }

  async acceptConsent(version: number): Promise<void> {
    await firstValueFrom(
      this.http.put(api('/ai/consent'), { consent_version: version, scope: 'cloud' }),
    );
    this.settings.reload();
  }

  async revokeConsent(): Promise<void> {
    await firstValueFrom(this.http.delete(api('/ai/consent'), { params: { scope: 'cloud' } }));
    this.settings.reload();
  }

  context(): Promise<AiUserContext> {
    return firstValueFrom(this.http.get<AiUserContext>(api('/ai/context')));
  }

  async saveContext(body: AiUserContext): Promise<AiUserContext> {
    const context = await firstValueFrom(this.http.put<AiUserContext>(api('/ai/context'), body));
    this.settings.reload();
    return context;
  }

  async presets(): Promise<AiPreset[]> {
    const response = await firstValueFrom(
      this.http.get<{ presets: AiPreset[] | null }>(api('/ai/presets')),
    );
    return response.presets ?? [];
  }

  preview(request: AiAnalysisRequest): Promise<AiPreview> {
    return firstValueFrom(this.http.post<AiPreview>(api('/ai/analyses/preview'), request));
  }

  /** Runs the previewed analysis; the report streams back. */
  run(
    request: AiAnalysisRequest & { data_fingerprint: string; client_request_id: string },
    signal: AbortSignal,
  ): AsyncGenerator<AiStreamEvent> {
    return this.stream(api('/ai/analyses'), request, signal);
  }

  /** A follow-up question on a finished report. */
  ask(analysisId: string, content: string, signal: AbortSignal): AsyncGenerator<AiStreamEvent> {
    return this.stream(api(`/ai/analyses/${analysisId}/messages`), { content }, signal);
  }

  /** `type` keeps only reports or only chats; null lists both. */
  list(
    cursor: string | null,
    limit = 20,
    type: AiHistoryType | null = null,
  ): Promise<{ items: AiAnalysisSummary[] | null; next_cursor?: string | null }> {
    return firstValueFrom(
      this.http.get<{ items: AiAnalysisSummary[] | null; next_cursor?: string | null }>(
        api('/ai/analyses'),
        { params: query({ cursor, limit, type }) },
      ),
    );
  }

  get(id: string): Promise<AiAnalysisDetail> {
    return firstValueFrom(this.http.get<AiAnalysisDetail>(api(`/ai/analyses/${id}`)));
  }

  rename(id: string, title: string): Promise<AiAnalysisDetail> {
    return firstValueFrom(this.http.patch<AiAnalysisDetail>(api(`/ai/analyses/${id}`), { title }));
  }

  async delete(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(api(`/ai/analyses/${id}`)));
    this.settings.reload();
  }

  async deleteAll(): Promise<void> {
    await firstValueFrom(this.http.delete(api('/ai/analyses')));
    this.settings.reload();
  }

  /** Maps the SSE events; unknown event names are skipped (a newer backend may add some). */
  private async *stream(
    url: string,
    body: unknown,
    signal: AbortSignal,
  ): AsyncGenerator<AiStreamEvent> {
    for await (const event of this.sse.post(url, body, signal)) {
      const json = sseJson<Record<string, unknown>>(event);
      switch (event.event) {
        case 'meta':
          yield {
            type: 'meta',
            analysisId: String(json['analysis_id'] ?? ''),
            messageId: String(json['message_id'] ?? ''),
            kind: String(json['kind'] ?? ''),
          };
          break;
        case 'delta':
          yield { type: 'delta', text: typeof json['text'] === 'string' ? json['text'] : '' };
          break;
        case 'usage':
          yield {
            type: 'usage',
            inputTokens: Number(json['input_tokens'] ?? 0),
            outputTokens: Number(json['output_tokens'] ?? 0),
            truncated: json['truncated'] === true,
          };
          break;
        case 'error':
          yield {
            type: 'error',
            code: typeof json['code'] === 'string' ? json['code'] : 'AI_PROVIDER_ERROR',
            message: typeof json['message'] === 'string' ? json['message'] : '',
          };
          break;
        case 'done':
          yield { type: 'done', status: (json['status'] as AiStatus) ?? 'COMPLETED' };
          break;
      }
    }
  }
}
