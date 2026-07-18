-- plan.md section 11.10: category_id/template_id, deferred from migration
-- 0006 until categories and transaction_templates existed (Fase 5).
ALTER TABLE transactions
    ADD COLUMN category_id UUID NULL REFERENCES categories(id),
    ADD COLUMN template_id UUID NULL REFERENCES transaction_templates(id);

CREATE INDEX transactions_user_category_occurred_idx
    ON transactions (user_id, category_id, occurred_at DESC) WHERE deleted_at IS NULL;

-- plan.md section 11.13, section 17.3: prefix search on the normalized title.
CREATE INDEX transactions_user_title_occurred_idx
    ON transactions (user_id, title_normalized, occurred_at DESC) WHERE deleted_at IS NULL;
