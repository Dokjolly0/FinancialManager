-- What a chat answer looked up (plan.md section 34.7): on a cloud provider
-- the model may call search tools on the user's transactions before it
-- answers. Each call, its arguments and the data returned to the model are
-- stored with the answer, for the user to see and for the export; later
-- turns replay only the final texts.
ALTER TABLE ai_messages ADD COLUMN tool_trace JSONB NULL;
