DROP INDEX IF EXISTS transactions_user_title_occurred_idx;
DROP INDEX IF EXISTS transactions_user_category_occurred_idx;

ALTER TABLE transactions
    DROP COLUMN IF EXISTS template_id,
    DROP COLUMN IF EXISTS category_id;
