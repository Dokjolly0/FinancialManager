import { Injectable, inject } from '@angular/core';

import { AppErrorException, fromResponse } from '../errors/app-error';
import { TokenStore } from '../auth/token-store';

/** One Server-Sent Event; multi-line data fields are joined with "\n". */
export interface SseEvent {
  event: string;
  data: string;
}

/**
 * Incremental text/event-stream parser (the app's SseDecoder): feed it
 * chunks of text, it returns the events completed so far. Comment lines
 * (": ping") are skipped; an event ends at a blank line, and `end()`
 * returns a last event left without its blank line.
 */
export class SseParser {
  private buffer = '';
  private event = '';
  private data: string[] = [];

  push(chunk: string): SseEvent[] {
    this.buffer += chunk;
    const events: SseEvent[] = [];
    let newline: number;
    while ((newline = this.buffer.indexOf('\n')) >= 0) {
      let line = this.buffer.slice(0, newline);
      this.buffer = this.buffer.slice(newline + 1);
      if (line.endsWith('\r')) line = line.slice(0, -1);
      const event = this.line(line);
      if (event) events.push(event);
    }
    return events;
  }

  end(): SseEvent[] {
    const events: SseEvent[] = [];
    if (this.buffer.length > 0) {
      const event = this.line(this.buffer.replace(/\r$/, ''));
      if (event) events.push(event);
      this.buffer = '';
    }
    const last = this.flush();
    if (last) events.push(last);
    return events;
  }

  private line(line: string): SseEvent | null {
    if (line === '') return this.flush();
    if (line.startsWith(':')) return null;
    const colon = line.indexOf(':');
    const field = colon < 0 ? line : line.slice(0, colon);
    let value = colon < 0 ? '' : line.slice(colon + 1);
    if (value.startsWith(' ')) value = value.slice(1);
    if (field === 'event') this.event = value;
    else if (field === 'data') this.data.push(value);
    return null;
  }

  private flush(): SseEvent | null {
    const event =
      this.data.length > 0 ? { event: this.event || 'message', data: this.data.join('\n') } : null;
    this.event = '';
    this.data = [];
    return event;
  }
}

/** The event's data decoded as a JSON object (the backend always sends objects). */
export function sseJson<T = Record<string, unknown>>(event: SseEvent): T {
  try {
    const decoded: unknown = JSON.parse(event.data);
    return (typeof decoded === 'object' && decoded !== null ? decoded : {}) as T;
  } catch {
    return {} as T;
  }
}

/**
 * POSTs a JSON body and yields the response's events (AI analyses,
 * plan.md section 32.4). HttpClient can't stream a POST response, so this
 * uses fetch with the session's token, refreshing it once on a 401 like the
 * interceptor. An error the server reports before streaming (a JSON
 * envelope) is thrown as an AppErrorException. Aborting `signal` closes the
 * connection, which the backend treats as "stop": it cancels the model call
 * and keeps the partial text.
 */
@Injectable({ providedIn: 'root' })
export class SseClient {
  private readonly tokens = inject(TokenStore);

  async *post(url: string, body: unknown, signal?: AbortSignal): AsyncGenerator<SseEvent> {
    let response = await this.send(url, body, this.tokens.accessToken, signal);
    if (response.status === 401 && (await isTokenRejection(response.clone()))) {
      const token = await this.tokens.refresh();
      if (token === null) {
        this.tokens.expire();
      } else {
        response = await this.send(url, body, token, signal);
      }
    }
    if (!response.ok || response.body === null) {
      const text = await response.text().catch(() => '');
      let json: unknown;
      try {
        json = JSON.parse(text);
      } catch {
        json = null;
      }
      throw new AppErrorException(
        fromResponse(response.status, json, response.headers.get('Retry-After')),
      );
    }

    const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
    const parser = new SseParser();
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        yield* parser.push(value);
      }
      yield* parser.end();
    } finally {
      reader.releaseLock();
    }
  }

  private send(
    url: string,
    body: unknown,
    token: string | null,
    signal?: AbortSignal,
  ): Promise<Response> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
      'X-Request-Id': crypto.randomUUID(),
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    return fetch(url, { method: 'POST', headers, body: JSON.stringify(body), signal });
  }
}

async function isTokenRejection(response: Response): Promise<boolean> {
  try {
    const json = (await response.json()) as { error?: { code?: unknown } };
    return typeof json?.error?.code !== 'string' || json.error.code === 'UNAUTHORIZED';
  } catch {
    return true;
  }
}
