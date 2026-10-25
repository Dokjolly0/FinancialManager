import {
  AI_CHAT_MAX_TRANSACTIONS,
  AI_CHAT_PRESET,
  aiStreamEvent,
  chatRequest,
  toolLabelKey,
} from './ai.model';

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

describe('AI stream events', () => {
  const map = (event: string, data: string) => aiStreamEvent({ event, data });

  it('maps the tool event without its data', () => {
    expect(map('tool', '{"name":"sum_transactions","query":"benzina","group_by":"month"}')).toEqual(
      {
        type: 'tool',
        name: 'sum_transactions',
        query: 'benzina',
        groupBy: 'month',
      },
    );
    expect(map('tool', '{"name":"search_transactions"}')).toEqual({
      type: 'tool',
      name: 'search_transactions',
    });
  });

  it('keeps the other events and skips unknown ones', () => {
    expect(map('delta', '{"text":"Ciao"}')).toEqual({ type: 'delta', text: 'Ciao' });
    expect(map('done', '{"status":"CANCELLED"}')).toEqual({ type: 'done', status: 'CANCELLED' });
    expect(map('something_new', '{}')).toBeNull();
  });

  it('labels a search by its tool and words', () => {
    expect(toolLabelKey('search_transactions', ' bollo ')).toEqual({
      key: 'aiChatToolSearch',
      query: 'bollo',
    });
    expect(toolLabelKey('sum_transactions')).toEqual({ key: 'aiChatToolSumAll' });
  });
});
