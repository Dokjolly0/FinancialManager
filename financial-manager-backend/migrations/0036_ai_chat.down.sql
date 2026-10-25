-- Chats can't exist without their preset: they are deleted with it.
DELETE FROM ai_analyses WHERE preset = 'CHAT';
ALTER TABLE ai_analyses DROP CONSTRAINT ai_analyses_preset_check;
ALTER TABLE ai_analyses ADD CONSTRAINT ai_analyses_preset_check CHECK (preset IN
    ('MONTHLY_CHECKUP', 'ANOMALIES', 'SAVINGS', 'RECURRING', 'WALLET_PURPOSE', 'CUSTOM'));
