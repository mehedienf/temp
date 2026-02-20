require('dotenv').config();
const mysql = require('mysql2/promise');
(async () => {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'room_expense',
  });
  try {
    await conn.execute('ALTER TABLE rooms ADD COLUMN is_confirmed TINYINT(1) NOT NULL DEFAULT 0 AFTER created_by');
    console.log('Added is_confirmed column');
  } catch(e) { console.log('is_confirmed:', e.message); }
  try {
    const sql = 'CREATE TABLE IF NOT EXISTS session_summaries (id VARCHAR(36) PRIMARY KEY, room_id VARCHAR(36) NOT NULL, session_number INT NOT NULL DEFAULT 1, summary_data JSON NOT NULL, grand_total DECIMAL(10,2) NOT NULL DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE)';
    await conn.execute(sql);
    console.log('Created session_summaries table');
  } catch(e) { console.log('session_summaries:', e.message); }

  // Finance tables
  try {
    await conn.execute(`CREATE TABLE IF NOT EXISTS deposits (
      id VARCHAR(36) PRIMARY KEY,
      room_id VARCHAR(36) NOT NULL,
      user_id VARCHAR(36) NOT NULL,
      added_by VARCHAR(36) DEFAULT NULL,
      amount DECIMAL(10,2) NOT NULL,
      note VARCHAR(255) DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
    console.log('Created deposits table');
  } catch(e) { console.log('deposits:', e.message); }

  try {
    await conn.execute(`CREATE TABLE IF NOT EXISTS split_expenses (
      id VARCHAR(36) PRIMARY KEY,
      room_id VARCHAR(36) NOT NULL,
      item_name VARCHAR(255) NOT NULL,
      total_amount DECIMAL(10,2) NOT NULL,
      per_member_amount DECIMAL(10,2) NOT NULL,
      member_count INT NOT NULL,
      created_by VARCHAR(36) DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`);
    console.log('Created split_expenses table');
  } catch(e) { console.log('split_expenses:', e.message); }

  try {
    await conn.execute(`CREATE TABLE IF NOT EXISTS split_expense_assignments (
      id VARCHAR(36) PRIMARY KEY,
      split_expense_id VARCHAR(36) NOT NULL,
      user_id VARCHAR(36) NOT NULL,
      amount DECIMAL(10,2) NOT NULL,
      FOREIGN KEY (split_expense_id) REFERENCES split_expenses(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
    console.log('Created split_expense_assignments table');
  } catch(e) { console.log('split_expense_assignments:', e.message); }

  await conn.end();
  console.log('Done');
})();
