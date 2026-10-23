import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { FormControl, ReactiveFormsModule } from '@angular/forms';

import { provideTestI18n } from '../../../testing/i18n';
import { AmountInput, Switch } from './form-controls';

@Component({
  imports: [AmountInput, Switch, ReactiveFormsModule],
  template: `
    <app-amount-input [formControl]="amount" />
    <app-switch label="Hide" [formControl]="hidden" />
  `,
})
class Host {
  readonly amount = new FormControl<number | null>(123450);
  readonly hidden = new FormControl(false);
}

describe('form controls', () => {
  beforeEach(() => TestBed.configureTestingModule({ providers: [provideTestI18n()] }));

  it('amount input reads and writes minor units', async () => {
    const fixture = TestBed.createComponent(Host);
    await fixture.whenStable();
    const input = (fixture.nativeElement as HTMLElement).querySelector('input')!;
    // jsdom's default language is en-US.
    expect(input.value).toMatch(/^1234[.,]50$/);

    input.value = '19,9';
    input.dispatchEvent(new Event('input'));
    expect(fixture.componentInstance.amount.value).toBe(1990);

    input.value = 'abc';
    input.dispatchEvent(new Event('input'));
    expect(fixture.componentInstance.amount.value).toBeNull();
  });

  it('switch toggles its value', async () => {
    const fixture = TestBed.createComponent(Host);
    await fixture.whenStable();
    const button = (fixture.nativeElement as HTMLElement).querySelector<HTMLButtonElement>(
      '[role="switch"]',
    )!;
    button.click();
    expect(fixture.componentInstance.hidden.value).toBe(true);
    await fixture.whenStable();
    expect(button.getAttribute('aria-checked')).toBe('true');
  });
});
