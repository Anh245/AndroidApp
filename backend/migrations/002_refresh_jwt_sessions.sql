ALTER TABLE sessions
  ADD COLUMN session_id UUID,
  ADD COLUMN revoked_at TIMESTAMPTZ;

UPDATE sessions
SET session_id = gen_random_uuid(),
    revoked_at = now();

ALTER TABLE sessions
  ALTER COLUMN session_id SET NOT NULL;

CREATE UNIQUE INDEX sessions_session_id_key ON sessions(session_id);
CREATE INDEX sessions_user_revoked_idx ON sessions(user_id, revoked_at);