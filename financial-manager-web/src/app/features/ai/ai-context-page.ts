import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Lock, Minus, Plus } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AiApi } from './ai.api';
import { AI_CONTEXT_TEXT_MAX_LENGTH, AiUserContext, IncomeType } from './ai.model';

const INCOME_TYPES: { value: IncomeType; key: string }[] = [
  { value: 'EMPLOYEE', key: 'aiIncomeEmployee' },
  { value: 'SELF_EMPLOYED', key: 'aiIncomeSelfEmployed' },
  { value: 'STUDENT', key: 'aiIncomeStudent' },
  { value: 'RETIRED', key: 'aiIncomeRetired' },
  { value: 'UNEMPLOYED', key: 'aiIncomeUnemployed' },
  { value: 'MIXED', key: 'aiIncomeMixed' },
  { value: 'OTHER', key: 'aiIncomeOther' },
];

/**
 * Personal context sent to the model (plan.md section 32.3): household,
 * income type, about me, goals, what to ignore, response style. All
 * optional; blank text is stored as nothing.
 */
@Component({
  selector: 'app-ai-context-page',
  imports: [Icon, InlineError, PageHeader, ReactiveFormsModule, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'aiContextMenuTitle' | transloco"
        [subtitle]="'aiContextIntro' | transloco"
        back="/app/account/ai"
        [backLabel]="'backAction' | transloco"
      />
      @if (loading()) {
        <div class="card card-pad space-y-4">
          <div class="skeleton h-11 w-full"></div>
          <div class="skeleton h-24 w-full"></div>
        </div>
      } @else if (loadError()) {
        <div class="card"><app-inline-error [message]="loadError()!" (retry)="load()" /></div>
      } @else {
        <form class="card card-pad space-y-6" [formGroup]="form" (ngSubmit)="save()" novalidate>
          <div class="grid gap-5 sm:grid-cols-2">
            <div>
              <p class="label">{{ 'aiHouseholdLabel' | transloco }}</p>
              <div class="flex items-center gap-3">
                <button
                  type="button"
                  class="btn btn-outline btn-icon"
                  [attr.aria-label]="'aiHouseholdLess' | transloco"
                  [disabled]="!household()"
                  (click)="changeHousehold(-1)"
                >
                  <app-icon [icon]="icons.Minus" [size]="16" />
                </button>
                <span class="min-w-24 text-center text-sm font-medium text-fg">
                  {{
                    household()
                      ? ('aiHouseholdValue' | transloco: { count: household() })
                      : ('aiNotSpecified' | transloco)
                  }}
                </span>
                <button
                  type="button"
                  class="btn btn-outline btn-icon"
                  [attr.aria-label]="'aiHouseholdMore' | transloco"
                  [disabled]="(household() ?? 0) >= 20"
                  (click)="changeHousehold(1)"
                >
                  <app-icon [icon]="icons.Plus" [size]="16" />
                </button>
              </div>
            </div>
            <div>
              <label class="label" for="ctx-income">{{ 'aiIncomeTypeLabel' | transloco }}</label>
              <select id="ctx-income" class="input" formControlName="income">
                <option value="">{{ 'aiNotSpecified' | transloco }}</option>
                @for (type of incomeTypes; track type.value) {
                  <option [value]="type.value">{{ type.key | transloco }}</option>
                }
              </select>
            </div>
          </div>
          @for (field of textFields; track field.name) {
            <div>
              <label class="label" [for]="'ctx-' + field.name">{{ field.label | transloco }}</label>
              <textarea
                class="input"
                rows="3"
                [id]="'ctx-' + field.name"
                [formControlName]="field.name"
                [maxlength]="maxLength"
                [placeholder]="field.hint | transloco"
              ></textarea>
              @if (errors.fields()[field.api]; as m) {
                <p class="field-error">{{ m }}</p>
              }
            </div>
          }
          <div>
            <p class="label">{{ 'aiResponseStyleLabel' | transloco }}</p>
            <div
              class="flex flex-wrap gap-2"
              role="radiogroup"
              [attr.aria-label]="'aiResponseStyleLabel' | transloco"
            >
              @for (style of styles; track style.value) {
                <button
                  type="button"
                  role="radio"
                  class="chip"
                  [class.chip-active]="form.controls.style.value === style.value"
                  [attr.aria-checked]="form.controls.style.value === style.value"
                  (click)="form.controls.style.setValue(style.value)"
                >
                  {{ style.key | transloco }}
                </button>
              }
            </div>
          </div>
          <p
            class="flex items-start gap-2 rounded-xl bg-surface-2 px-4 py-3 text-xs leading-relaxed text-fg-muted"
          >
            <app-icon [icon]="icons.Lock" [size]="14" class="mt-0.5" />
            {{ 'aiContextPrivacyNote' | transloco }}
          </p>
          @if (errors.message()) {
            <p class="field-error" role="alert">{{ errors.message() }}</p>
          }
          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary" [disabled]="saving()">
              @if (saving()) {
                <app-spinner />
              }
              {{ 'aiSaveContext' | transloco }}
            </button>
          </div>
        </form>
      }
    </div>
  `,
})
export class AiContextPage implements OnInit {
  private readonly ai = inject(AiApi);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly icons = { Lock, Minus, Plus };
  protected readonly incomeTypes = INCOME_TYPES;
  protected readonly maxLength = AI_CONTEXT_TEXT_MAX_LENGTH;
  protected readonly styles = [
    { value: '', key: 'aiStyleDefault' },
    { value: 'CONCISE', key: 'aiStyleConcise' },
    { value: 'DETAILED', key: 'aiStyleDetailed' },
  ];
  protected readonly textFields = [
    { name: 'aboutMe', api: 'about_me', label: 'aiAboutMeLabel', hint: 'aiAboutMeHint' },
    { name: 'goals', api: 'goals', label: 'aiGoalsLabel', hint: 'aiGoalsHint' },
    { name: 'ignore', api: 'ignore_notes', label: 'aiIgnoreLabel', hint: 'aiIgnoreHint' },
  ] as const;

  protected readonly form = inject(NonNullableFormBuilder).group({
    income: [''],
    aboutMe: [''],
    goals: [''],
    ignore: [''],
    style: [''],
  });
  protected readonly household = signal<number | null>(null);
  private version = 0;
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  ngOnInit(): void {
    void this.load();
  }

  protected async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const c = await this.ai.context();
      this.version = c.version;
      this.household.set(c.household_size);
      this.form.setValue({
        income: c.income_type ?? '',
        aboutMe: c.about_me ?? '',
        goals: c.goals ?? '',
        ignore: c.ignore_notes ?? '',
        style: c.response_style ?? '',
      });
    } catch (error) {
      this.loadError.set(this.errorText.message(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected changeHousehold(step: number): void {
    const next = (this.household() ?? 0) + step;
    this.household.set(next <= 0 ? null : Math.min(next, 20));
  }

  protected async save(): Promise<void> {
    const v = this.form.getRawValue();
    const text = (value: string) => value.trim() || null;
    const body: AiUserContext = {
      household_size: this.household(),
      income_type: (v.income || null) as IncomeType | null,
      about_me: text(v.aboutMe),
      goals: text(v.goals),
      ignore_notes: text(v.ignore),
      response_style: (v.style || null) as AiUserContext['response_style'],
      version: this.version,
    };
    this.saving.set(true);
    this.errors.clear();
    try {
      const saved = await this.ai.saveContext(body);
      this.version = saved.version;
      this.toasts.success(this.transloco.translate('webSaved'));
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
