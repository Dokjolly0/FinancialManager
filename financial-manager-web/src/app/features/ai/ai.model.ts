/**
 * The AI analysis contract (plan.md section 32, financial-manager-backend
 * openapi/openapi.yaml). The dashboard only runs analyses in the cloud: the
 * on-device path (section 33) exists on Android alone.
 */

export type AiProvider = 'anthropic' | 'openai' | 'gemini' | 'openai_compatible';
export const AI_PROVIDERS: AiProvider[] = ['anthropic', 'openai', 'gemini', 'openai_compatible'];

/** Only OpenAI-compatible servers may run without a key; only they take a base URL. */
export const requiresApiKey = (provider: AiProvider) => provider !== 'openai_compatible';
export const requiresBaseUrl = (provider: AiProvider) => provider === 'openai_compatible';

/** The app's ai_provider_labels.dart; the compatible one comes from the ARB. */
export const PROVIDER_LABELS: Record<string, string> = {
  anthropic: 'Anthropic (Claude)',
  openai: 'OpenAI (ChatGPT)',
  gemini: 'Google Gemini',
};

/** Suggested base URLs for OpenAI-compatible providers (ai_provider_form.dart). */
export const COMPATIBLE_PRESETS = [
  { name: 'Mistral', baseUrl: 'https://api.mistral.ai/v1' },
  { name: 'Groq', baseUrl: 'https://api.groq.com/openai/v1' },
  { name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1' },
  { name: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1' },
  { name: 'Ollama', baseUrl: 'http://192.168.1.10:11434/v1' },
];

/** Backend limits (ai.MinMaxOutputTokens, MaxMaxOutputTokens, transactions, text). */
export const AI_MIN_OUTPUT_TOKENS = 256;
export const AI_MAX_OUTPUT_TOKENS = 32000;
export const AI_MAX_TRANSACTIONS = 500;
export const AI_DEFAULT_MAX_TRANSACTIONS = 200;
export const AI_COMPACT_DEFAULT_TRANSACTIONS = 60;
export const AI_COMPACT_MAX_TRANSACTIONS = 100;
export const AI_INSTRUCTIONS_MAX_LENGTH = 4000;
export const AI_QUESTION_MAX_LENGTH = 2000;
export const AI_CONTEXT_TEXT_MAX_LENGTH = 2000;

export interface AiCredential {
  id: string;
  provider: AiProvider;
  base_url?: string | null;
  model?: string | null;
  has_key: boolean;
  key_hint?: string | null;
  last_tested_at?: string | null;
  last_test_ok?: boolean | null;
}

export interface AiConsentState {
  accepted_version?: number | null;
  current_version: number;
  accepted_at?: string | null;
  required: boolean;
}

export interface AiSettings {
  /** The cloud path is configured on the server (AI_KEY_ENCRYPTION_KEY). */
  available: boolean;
  on_device_available: boolean;
  mode: 'cloud' | 'on_device';
  local_model?: string | null;
  active?: AiCredential | null;
  credentials: AiCredential[] | null;
  max_output_tokens: number;
  input_price_per_mtok?: number | null;
  output_price_per_mtok?: number | null;
  defaults: { include_transactions: boolean; anonymize_titles: boolean };
  consent: AiConsentState & { on_device?: AiConsentState };
  setup: {
    has_provider: boolean;
    has_model: boolean;
    has_context: boolean;
    wallets_total: number;
    wallets_with_purpose: number;
    analyses_count: number;
  };
  version: number;
}

export interface AiSettingsRequest {
  provider: AiProvider;
  base_url: string;
  model: string;
  /** Omitted or null keeps the stored key, "" removes it. */
  api_key: string | null;
  max_output_tokens: number;
  input_price_per_mtok: number | null;
  output_price_per_mtok: number | null;
  defaults: { include_transactions: boolean; anonymize_titles: boolean };
  version: number;
}

export interface AiProbeRequest {
  provider?: AiProvider;
  base_url?: string;
  api_key?: string;
  model?: string;
}

export interface AiProbeResult {
  ok: boolean;
  latency_ms: number;
  model?: string | null;
  error_code?: string | null;
  error_message?: string | null;
}

export type IncomeType =
  'EMPLOYEE' | 'SELF_EMPLOYED' | 'STUDENT' | 'RETIRED' | 'UNEMPLOYED' | 'MIXED' | 'OTHER';

export interface AiUserContext {
  household_size: number | null;
  income_type: IncomeType | null;
  about_me: string | null;
  goals: string | null;
  ignore_notes: string | null;
  response_style: 'CONCISE' | 'DETAILED' | null;
  version: number;
  updated_at?: string | null;
}

export type AiDataSection =
  'monthly' | 'categories' | 'titles' | 'transfers' | 'recurring' | 'personal_context';
export const AI_SECTIONS: AiDataSection[] = [
  'monthly',
  'categories',
  'titles',
  'transfers',
  'recurring',
  'personal_context',
];

/** ARB keys of the data sections. */
export const SECTION_KEYS: Record<AiDataSection, string> = {
  monthly: 'aiSectionMonthly',
  categories: 'aiSectionCategories',
  titles: 'aiSectionTitles',
  transfers: 'aiSectionTransfers',
  recurring: 'aiSectionRecurring',
  personal_context: 'aiSectionPersonalContext',
};

export interface AiPreset {
  id: string;
  title: string;
  description: string;
  default_instructions: string;
  default_sections: AiDataSection[];
  default_include_transactions: boolean;
  default_period_preset: string;
}

export interface AiFilters {
  direction?: 'DEBIT' | 'CREDIT';
  category_id?: string;
  title?: string;
  amount_min_minor?: number;
  amount_max_minor?: number;
}

export interface AiAnalysisRequest {
  preset: string;
  target: 'cloud';
  credential_id?: string;
  period: { preset: 'all_time' | 'custom'; from?: string; to?: string };
  wallet_ids: string[];
  options: {
    sections: AiDataSection[];
    include_transactions: boolean;
    max_transactions: number;
    anonymize_titles: boolean;
    include_adjustments: boolean;
    filters?: AiFilters;
    profile?: 'standard' | 'compact';
  };
  instructions: string | null;
}

export interface AiPreview {
  provider: AiProvider;
  model: string;
  prompt_version: string;
  system_prompt: string;
  instructions: string;
  data_block: string;
  data_fingerprint: string;
  estimated_input_tokens: number;
  max_output_tokens: number;
  estimated_cost?: { input_cost: number; max_output_cost: number } | null;
  period_from?: string | null;
  period_to: string;
  disclosure: {
    sections: AiDataSection[];
    wallet_count: number;
    transaction_count: number;
    transactions_omitted: number;
    anonymized: boolean;
    includes_personal_context: boolean;
    profile?: 'standard' | 'compact';
    compaction_steps?: string[] | null;
  };
}

export type AiStatus = 'STREAMING' | 'COMPLETED' | 'FAILED' | 'CANCELLED';

export interface AiAnalysisSummary {
  id: string;
  title: string;
  preset: string;
  period_from?: string | null;
  period_to: string;
  status: AiStatus;
  error_code?: string | null;
  provider: AiProvider | 'on_device';
  model: string;
  input_tokens: number;
  output_tokens: number;
  cost?: number | null;
  created_at: string;
  updated_at: string;
}

export interface AiMessage {
  id: string;
  seq: number;
  role: 'user' | 'assistant';
  kind: 'CONTEXT' | 'REPORT' | 'QUESTION' | 'ANSWER';
  content: string;
  status: AiStatus;
  error_code?: string | null;
  model?: string | null;
  input_tokens?: number | null;
  output_tokens?: number | null;
  truncated: boolean;
  created_at: string;
}

export interface AiAnalysisDetail extends AiAnalysisSummary {
  timezone: string;
  wallet_ids: string[];
  prompt_version: string;
  system_prompt: string;
  follow_ups_left: number;
  can_ask_follow_ups: boolean;
  messages: AiMessage[];
}

/** One event of an analysis or follow-up stream: meta, deltas, usage or error, done. */
export type AiStreamEvent =
  | { type: 'meta'; analysisId: string; messageId: string; kind: string }
  | { type: 'delta'; text: string }
  | { type: 'usage'; inputTokens: number; outputTokens: number; truncated: boolean }
  | { type: 'error'; code: string; message: string }
  | { type: 'done'; status: AiStatus };

/** A stored provider account that can run an analysis (the app's AiCloudChoice). */
export function usableCredentials(settings: AiSettings): AiCredential[] {
  const list = [...(settings.credentials ?? [])];
  if (settings.active && !list.some((c) => c.id === settings.active!.id))
    list.unshift(settings.active);
  return list.filter((c) => !!c.model && (c.has_key || !requiresApiKey(c.provider)));
}

/** Setup checklist steps done out of four: provider, context, purposes, first analysis. */
export function setupSteps(settings: AiSettings): { done: number; total: number } {
  const s = settings.setup;
  const steps = [
    s.has_provider && s.has_model,
    s.has_context,
    s.wallets_total > 0 && s.wallets_with_purpose === s.wallets_total,
    s.analyses_count > 0,
  ];
  return { done: steps.filter(Boolean).length, total: steps.length };
}

/** Ready to analyze in the cloud: server path on, provider with a model, consent given. */
export const isReady = (settings: AiSettings) =>
  settings.available &&
  settings.setup.has_provider &&
  settings.setup.has_model &&
  !settings.consent.required;
