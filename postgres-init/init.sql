CREATE TABLE people (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255),
  state CHAR(2),
  birth_date DATE
);

INSERT INTO people (name, email, state, birth_date) VALUES
('Alice Johnson', 'alice.johnson@example.com', 'TX', '1985-03-12'),
('Bob Smith',     'bob.smith@example.com',     'CA', '1990-07-22'),
('Carol Lee',     'carol.lee@example.com',     'NY', '1978-11-05'),
('David Kim',     'david.kim@example.com',     'GA', '1995-01-30'),
('Erin Davis',    'erin.davis@example.com',    'MT', '1988-09-14'),
('Frank Moore',   'frank.moore@example.com',   'IA', '1992-04-18'),
('Grace Chen',    'grace.chen@example.com',    'MN', '1983-06-25'),
('Henry Wilson',  'henry.wilson@example.com',  'WI', '1975-12-02'),
('Ivy Martinez',  'ivy.martinez@example.com',  'FL', '1991-08-19'),
('Jack Brown',    'jack.brown@example.com',    'OH', '1987-02-27');

CREATE TABLE accounts (
  id SERIAL PRIMARY KEY,
  account_name VARCHAR(255),
  balance NUMERIC(12, 2)
);

INSERT INTO accounts (account_name, balance) VALUES
('Acme Corp', 125000.00),
('Globex Inc', 84200.50);
