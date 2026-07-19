-- plan.md section 7.13 "Preferenze": visibilita saldo all'apertura e
-- primo giorno della settimana, aggiunti alle preferenze gia esistenti
-- (locale/timezone/theme, Fase 1).
ALTER TABLE users
    ADD COLUMN balance_hidden_default BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN first_day_of_week VARCHAR(10) NOT NULL DEFAULT 'monday',
    ADD CONSTRAINT users_first_day_of_week_check CHECK (first_day_of_week IN ('monday', 'sunday'));
