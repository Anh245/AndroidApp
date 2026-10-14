CREATE TABLE users (
 id UUID PRIMARY KEY,
 name VARCHAR(80) NOT NULL,
 email VARCHAR(254) NOT NULL UNIQUE,
 password_hash TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE sessions (
 token_hash CHAR(64) PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 expires_at TIMESTAMPTZ NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_idx ON sessions(user_id);
CREATE TABLE categories (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 name VARCHAR(60) NOT NULL,
 kind VARCHAR(7) NOT NULL CHECK (kind IN ('income','expense')),
 color CHAR(7) NOT NULL DEFAULT '#0F766E' CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(id,user_id,kind)
);
CREATE UNIQUE INDEX categories_name_idx ON categories(user_id,kind,lower(name));
CREATE TABLE transactions (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 category_id UUID NOT NULL,
 kind VARCHAR(7) NOT NULL CHECK (kind IN ('income','expense')),
 amount NUMERIC(15,0) NOT NULL CHECK (amount > 0 AND amount <= 1000000000000),
 occurred_on DATE NOT NULL,
 note VARCHAR(500) NOT NULL DEFAULT '',
 payment_method VARCHAR(10) NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash','bank','other')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 FOREIGN KEY(category_id,user_id,kind) REFERENCES categories(id,user_id,kind) ON DELETE RESTRICT
);
CREATE INDEX transactions_user_date_idx ON transactions(user_id,occurred_on DESC,created_at DESC,id DESC);
CREATE INDEX transactions_category_idx ON transactions(category_id);
CREATE TABLE budgets (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 category_id UUID NOT NULL,
 kind VARCHAR(7) NOT NULL DEFAULT 'expense' CHECK (kind='expense'),
 month DATE NOT NULL CHECK (EXTRACT(DAY FROM month)=1),
 amount NUMERIC(15,0) NOT NULL CHECK (amount>0 AND amount<=1000000000000),
 UNIQUE(user_id,category_id,month),
 FOREIGN KEY(category_id,user_id,kind) REFERENCES categories(id,user_id,kind) ON DELETE RESTRICT
);
