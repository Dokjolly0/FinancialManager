import { TestBed } from '@angular/core/testing';

import { Markdown } from './markdown';

describe('Markdown', () => {
  async function render(text: string): Promise<HTMLElement> {
    const fixture = TestBed.createComponent(Markdown);
    fixture.componentRef.setInput('text', text);
    await fixture.whenStable();
    return fixture.nativeElement as HTMLElement;
  }

  it('renders headings, tables and lists', async () => {
    const el = await render('## Title\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- item');
    expect(el.querySelector('h2')?.textContent).toBe('Title');
    expect(el.querySelectorAll('td')).toHaveLength(2);
    expect(el.querySelector('li')?.textContent).toBe('item');
  });

  it('never lets model output run scripts', async () => {
    const el = await render(
      'Hi <script>window.x = 1</script><img src="x" onerror="window.x = 2"> [link](javascript:alert(1))',
    );
    expect(el.querySelector('script')).toBeNull();
    expect(el.querySelector('img')?.getAttribute('onerror')).toBeNull();
    // Angular neutralizes it as "unsafe:javascript:...", which can't run.
    expect(el.querySelector('a')?.getAttribute('href') ?? '').not.toMatch(/^javascript:/);
  });
});
