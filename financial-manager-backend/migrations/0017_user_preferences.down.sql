ALTER TABLE users
    DROP CONSTRAINT users_first_day_of_week_check,
    DROP COLUMN first_day_of_week,
    DROP COLUMN balance_hidden_default;
