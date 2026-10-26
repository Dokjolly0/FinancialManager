-- plan.md section 11.7: system categories are shared by every user, so a
-- user can't edit or archive them — but they can hide the ones they never
-- use from their own pickers. One row per (user, hidden system category);
-- transactions already filed under a hidden category keep it.
CREATE TABLE user_hidden_categories (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (user_id, category_id)
);
