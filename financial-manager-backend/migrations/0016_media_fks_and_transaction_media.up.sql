-- plan.md section 11.2/11.7/11.10: wire up the FK/columns deferred until
-- media_assets existed (Fase 6).
ALTER TABLE users
    ADD CONSTRAINT users_avatar_media_id_fkey FOREIGN KEY (avatar_media_id) REFERENCES media_assets(id);

ALTER TABLE categories
    ADD CONSTRAINT categories_icon_media_id_fkey FOREIGN KEY (icon_media_id) REFERENCES media_assets(id);

ALTER TABLE transactions
    ADD COLUMN media_id UUID NULL REFERENCES media_assets(id);
