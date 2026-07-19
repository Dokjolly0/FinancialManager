-- Adds a user-editable display name for library search/rename. Direct
-- uploads default to their original filename; search-selected (Unsplash)
-- assets stay unnamed until the user renames them.
ALTER TABLE media_assets ADD COLUMN name TEXT NULL;
ALTER TABLE media_assets ADD COLUMN name_normalized TEXT NULL;

UPDATE media_assets SET name = original_filename WHERE original_filename IS NOT NULL;
UPDATE media_assets SET name_normalized = lower(name) WHERE name IS NOT NULL;
