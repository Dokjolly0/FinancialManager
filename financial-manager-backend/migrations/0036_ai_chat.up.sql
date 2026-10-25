-- Chats, "Chiedi all'assistente" (plan.md section 34): a free-form
-- conversation stored as an analysis with preset CHAT. Its first question
-- is the instructions of the CONTEXT message (after the data block), its
-- first answer the REPORT message, and later questions the usual
-- QUESTION/ANSWER pairs, so history, export and replay work unchanged.
ALTER TABLE ai_analyses DROP CONSTRAINT ai_analyses_preset_check;
ALTER TABLE ai_analyses ADD CONSTRAINT ai_analyses_preset_check CHECK (preset IN
    ('MONTHLY_CHECKUP', 'ANOMALIES', 'SAVINGS', 'RECURRING', 'WALLET_PURPOSE', 'CUSTOM', 'CHAT'));
