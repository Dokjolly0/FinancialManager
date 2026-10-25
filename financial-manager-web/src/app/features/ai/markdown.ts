import {
  ChangeDetectionStrategy,
  Component,
  ViewEncapsulation,
  computed,
  input,
} from '@angular/core';
import { Marked } from 'marked';

const marked = new Marked({ gfm: true, breaks: false, async: false });

/**
 * A model's Markdown answer as HTML. The HTML goes through Angular's
 * sanitizer ([innerHTML]), which strips scripts, event handlers and unsafe
 * URLs: model output is never trusted.
 */
@Component({
  selector: 'app-markdown',
  changeDetection: ChangeDetectionStrategy.OnPush,
  // Emulated styles never reach [innerHTML] content; every rule is scoped
  // under .markdown instead.
  encapsulation: ViewEncapsulation.None,
  template: `<div class="markdown" [innerHTML]="html()"></div>`,
  styles: `
    .markdown {
      font-size: 0.9375rem;
      line-height: 1.7;
      color: var(--c-fg);
      overflow-wrap: anywhere;
    }
    .markdown :is(h1, h2, h3, h4) {
      margin: 1.4em 0 0.5em;
      font-weight: 700;
      line-height: 1.3;
    }
    .markdown h1 {
      font-size: 1.35rem;
    }
    .markdown h2 {
      font-size: 1.15rem;
    }
    .markdown h3 {
      font-size: 1rem;
    }
    .markdown > :first-child {
      margin-top: 0;
    }
    .markdown p {
      margin: 0.6em 0;
    }
    .markdown :is(ul, ol) {
      margin: 0.6em 0;
      padding-left: 1.4em;
    }
    .markdown ul {
      list-style: disc;
    }
    .markdown ol {
      list-style: decimal;
    }
    .markdown li {
      margin: 0.25em 0;
    }
    .markdown strong {
      font-weight: 650;
    }
    .markdown a {
      color: var(--c-primary);
      text-decoration: underline;
    }
    .markdown code {
      border-radius: 0.35rem;
      background: var(--c-surface-2);
      padding: 0.1em 0.35em;
      font-size: 0.85em;
    }
    .markdown pre {
      overflow-x: auto;
      border-radius: 0.75rem;
      background: var(--c-surface-2);
      padding: 0.9em 1em;
    }
    .markdown pre code {
      background: none;
      padding: 0;
    }
    .markdown blockquote {
      margin: 0.8em 0;
      border-left: 3px solid var(--c-border);
      padding-left: 1em;
      color: var(--c-fg-muted);
    }
    .markdown table {
      display: block;
      margin: 0.8em 0;
      max-width: 100%;
      overflow-x: auto;
      border-collapse: collapse;
      font-size: 0.875rem;
    }
    .markdown :is(th, td) {
      border-bottom: 1px solid var(--c-border);
      padding: 0.45em 0.8em;
      text-align: left;
    }
    .markdown th {
      font-weight: 600;
    }
    .markdown hr {
      margin: 1.2em 0;
      border-color: var(--c-border);
    }
  `,
})
export class Markdown {
  readonly text = input('');
  protected readonly html = computed(() => marked.parse(this.text()) as string);
}
