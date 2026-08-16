CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS payment_intents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_address VARCHAR(42) NOT NULL,
  to_address VARCHAR(42) NOT NULL,
  amount_wei NUMERIC(78,0) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  batch_id INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS batches (
  id SERIAL PRIMARY KEY,
  batch_index INTEGER UNIQUE,
  old_state_root VARCHAR(66),
  new_state_root VARCHAR(66) NOT NULL,
  batch_hash VARCHAR(66) NOT NULL,
  tx_count INTEGER NOT NULL,
  relayer_address VARCHAR(42) NOT NULL,
  committed_at TIMESTAMPTZ,
  tx_hash VARCHAR(66),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deposits (
  id SERIAL PRIMARY KEY,
  user_address VARCHAR(42) NOT NULL,
  amount_wei NUMERIC(78,0) NOT NULL,
  tx_hash VARCHAR(66) UNIQUE NOT NULL,
  block_number INTEGER NOT NULL,
  indexed_at TIMESTAMPTZ DEFAULT NOW(),
  batch_id INTEGER
);

CREATE TABLE IF NOT EXISTS withdrawals (
  id SERIAL PRIMARY KEY,
  user_address VARCHAR(42) NOT NULL,
  amount_wei NUMERIC(78,0) NOT NULL,
  tx_hash VARCHAR(66) UNIQUE NOT NULL,
  block_number INTEGER NOT NULL,
  indexed_at TIMESTAMPTZ DEFAULT NOW(),
  batch_id INTEGER
);

ALTER TABLE deposits ADD COLUMN IF NOT EXISTS batch_id INTEGER;
ALTER TABLE withdrawals ADD COLUMN IF NOT EXISTS batch_id INTEGER;
CREATE UNIQUE INDEX IF NOT EXISTS deposits_tx_hash_idx ON deposits (tx_hash);
CREATE UNIQUE INDEX IF NOT EXISTS withdrawals_tx_hash_idx ON withdrawals (tx_hash);
