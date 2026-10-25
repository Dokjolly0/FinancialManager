-- Transactions attached to a chat question (plan.md section 34.3): when a
-- chat's transaction list had to be cut to fit the budget, each later
-- question gets the older transactions matching its words. They are stored
-- with the question so every later turn replays exactly what was sent.
ALTER TABLE ai_messages ADD COLUMN attachment TEXT NULL;
