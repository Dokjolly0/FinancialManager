-- Multi-wallet support, part 1: a user may now have any number of active
-- wallets (plan.md section 11.6 already called this out as the reason the
-- old index was partial). No replacement unique index — the application
-- layer, not the schema, now decides how many wallets a user may create.
DROP INDEX wallets_one_active_per_user_idx;
