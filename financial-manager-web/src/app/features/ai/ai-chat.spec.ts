import { AI_CHAT_MAX_TRANSACTIONS, AI_CHAT_PRESET, chatRequest } from './ai.model';

describe('AI chat request', () => {
  it('asks a CHAT on the whole history and lets the server pick the data', () => {
    expect(chatRequest('  Quando ho pagato l’assicurazione?  ', 'c1')).toEqual({
      preset: AI_CHAT_PRESET,
      target: 'cloud',
      credential_id: 'c1',
      period: { preset: 'all_time' },
      wallet_ids: [],
      options: {
        sections: [],
        include_transactions: true,
        max_transactions: AI_CHAT_MAX_TRANSACTIONS,
        anonymize_titles: false,
        include_adjustments: false,
      },
      instructions: 'Quando ho pagato l’assicurazione?',
    });
  });

  it('runs on the active account when none is chosen', () => {
    expect('credential_id' in chatRequest('Quanto spendo?', null)).toBe(false);
  });
});
