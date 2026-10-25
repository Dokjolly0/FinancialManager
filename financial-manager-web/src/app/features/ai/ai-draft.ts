import { Injectable, signal } from '@angular/core';

import { AiAnalysisRequest, AiPreview } from './ai.model';

/**
 * The analysis being prepared, from setup to preview to run (the app's
 * AiDraftController). Lives in memory: reloading the preview or run page
 * goes back to the setup.
 */
@Injectable({ providedIn: 'root' })
export class AiDraft {
  readonly request = signal<AiAnalysisRequest | null>(null);
  readonly preview = signal<AiPreview | null>(null);
  /** A provider label for "will be sent to", from the chosen account. */
  readonly target = signal<string>('');

  set(request: AiAnalysisRequest, preview: AiPreview, target: string): void {
    this.request.set(request);
    this.preview.set(preview);
    this.target.set(target);
  }

  clear(): void {
    this.request.set(null);
    this.preview.set(null);
  }
}
