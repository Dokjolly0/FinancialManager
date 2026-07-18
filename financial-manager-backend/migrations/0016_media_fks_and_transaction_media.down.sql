ALTER TABLE transactions DROP COLUMN IF EXISTS media_id;

ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_icon_media_id_fkey;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_avatar_media_id_fkey;
