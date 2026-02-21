require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

const app = express();
app.use(cors());
app.use(express.json());

// DB Pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'room_expense',
  waitForConnections: true,
  connectionLimit: 10,
});

// Run all DB migrations sequentially on startup
(async () => {
  const conn = await pool.getConnection();
  try {
    // 1. Add left_at to room_members
    await conn.execute('ALTER TABLE room_members ADD COLUMN left_at TIMESTAMP NULL DEFAULT NULL')
      .catch(e => { if (!e.message.includes('Duplicate column name')) console.error('Migration left_at:', e.message); });

    // 2. Create guest_users table (standalone — no FK to users.id)
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS guest_users (
        id          VARCHAR(36)  NOT NULL,
        username    VARCHAR(100) NOT NULL,
        name        VARCHAR(255) NOT NULL DEFAULT '',
        room_id     VARCHAR(36)  NOT NULL DEFAULT '',
        created_by  VARCHAR(36)  NOT NULL,
        created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
      )
    `).catch(e => console.error('guest_users create:', e.message));

    // 3. Drop legacy FK guest_users.id → users (old structure)
    const [guestFks] = await conn.execute(`
      SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'guest_users'
        AND COLUMN_NAME = 'id' AND REFERENCED_TABLE_NAME = 'users'
    `);
    for (const fk of guestFks) {
      await conn.execute(`ALTER TABLE guest_users DROP FOREIGN KEY \`${fk.CONSTRAINT_NAME}\``)
        .catch(e => console.error('Drop guest FK:', e.message));
    }

    // 4. Add name column to guest_users if missing
    await conn.execute(`ALTER TABLE guest_users ADD COLUMN name VARCHAR(255) NOT NULL DEFAULT ''`)
      .catch(e => { if (!e.message.includes('Duplicate column name')) console.error('guest_users name col:', e.message); });

    // 5. Copy existing names from users into guest_users (one-time backfill)
    await conn.execute(`UPDATE guest_users g JOIN users u ON u.id = g.id SET g.name = u.name WHERE g.name = ''`)
      .catch(e => console.error('guest_users name backfill:', e.message));

    // 5b. Add room_id column to guest_users if missing
    await conn.execute(`ALTER TABLE guest_users ADD COLUMN room_id VARCHAR(36) NOT NULL DEFAULT ''`)
      .catch(e => { if (!e.message.includes('Duplicate column name')) console.error('guest_users room_id col:', e.message); });

    // 5c. Drop old username-only UNIQUE constraint if it exists, then add (username, room_id) UNIQUE
    const [oldUniqs] = await conn.execute(`
      SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'guest_users'
        AND CONSTRAINT_TYPE = 'UNIQUE' AND CONSTRAINT_NAME != 'PRIMARY'
    `);
    for (const u of oldUniqs) {
      // Only drop the single-column username unique — leave any compound one alone
      const [cols] = await conn.execute(`
        SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'guest_users'
          AND CONSTRAINT_NAME = ?
      `, [u.CONSTRAINT_NAME]);
      if (cols.length === 1 && cols[0].COLUMN_NAME === 'username') {
        await conn.execute(`ALTER TABLE guest_users DROP INDEX \`${u.CONSTRAINT_NAME}\``)
          .catch(e => console.error('Drop username unique:', e.message));
      }
    }
    // Add compound unique (username, room_id) if not already present
    const [existingCompound] = await conn.execute(`
      SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'guest_users'
        AND CONSTRAINT_TYPE = 'UNIQUE' AND CONSTRAINT_NAME = 'uq_guest_username_room'
    `);
    if (existingCompound.length === 0) {
      await conn.execute(`ALTER TABLE guest_users ADD UNIQUE KEY uq_guest_username_room (username, room_id)`)
        .catch(e => console.error('Add compound unique:', e.message));
    }

    // 6. Drop user_id → users FK constraints so guest IDs can appear in those tables
    for (const table of ['room_members', 'deposits', 'cart_items', 'split_expense_assignments']) {
      const [fks] = await conn.execute(`
        SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
          AND COLUMN_NAME = 'user_id' AND REFERENCED_TABLE_NAME = 'users'
      `, [table]);
      for (const fk of fks) {
        await conn.execute(`ALTER TABLE \`${table}\` DROP FOREIGN KEY \`${fk.CONSTRAINT_NAME}\``)
          .catch(e => console.error(`Drop ${table} FK:`, e.message));
      }
    }
  } finally {
    conn.release();
  }
})().catch(e => console.error('Migration error:', e.message));

// Health Check
app.get('/', (req, res) => res.json({ status: 'Room Expense API running' }));

// POST /auth/signup  => body: { username, name, password }
app.post('/auth/signup', async (req, res) => {
  try {
    const { username, name, password } = req.body;
    if (!username || !name || !password)
      return res.status(400).json({ error: 'username, name and password required' });

    const [existing] = await pool.execute('SELECT id FROM users WHERE username = ?', [
      username.trim().toLowerCase(),
    ]);
    if (existing.length > 0)
      return res.status(409).json({ error: 'Username already taken' });

    const id = uuidv4();
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.execute(
      'INSERT INTO users (id, username, name, password_hash) VALUES (?, ?, ?, ?)',
      [id, username.trim().toLowerCase(), name.trim(), passwordHash]
    );
    res.status(201).json({ id, username: username.trim().toLowerCase(), name: name.trim() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /auth/login  => body: { username, password }
app.post('/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password)
      return res.status(400).json({ error: 'username and password required' });

    const [rows] = await pool.execute('SELECT * FROM users WHERE username = ?', [
      username.trim().toLowerCase(),
    ]);
    if (rows.length === 0)
      return res.status(401).json({ error: 'Invalid username or password' });

    const user = rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match)
      return res.status(401).json({ error: 'Invalid username or password' });

    res.json({ id: user.id, username: user.username, name: user.name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /users/:userId/rooms  => list of rooms the user has joined (and not left)
app.get('/users/:userId/rooms', async (req, res) => {
  try {
    const { userId } = req.params;
    const [rooms] = await pool.execute(
      `SELECT r.id, r.code, r.name FROM rooms r
       JOIN room_members rm ON rm.room_id = r.id
       WHERE rm.user_id = ? AND rm.left_at IS NULL
       ORDER BY rm.joined_at DESC`,
      [userId]
    );
    res.json(rooms);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms  => body: { name, userId }
app.post('/rooms', async (req, res) => {
  try {
    const { name, userId } = req.body;
    if (!name || !userId) return res.status(400).json({ error: 'name and userId required' });

    const id = uuidv4();
    let code;
    while (true) {
      code = Math.random().toString(36).substring(2, 8).toUpperCase();
      const [rows] = await pool.execute('SELECT id FROM rooms WHERE code = ?', [code]);
      if (rows.length === 0) break;
    }

    await pool.execute('INSERT INTO rooms (id, code, name, created_by) VALUES (?, ?, ?, ?)', [id, code, name.trim(), userId]);
    await pool.execute('INSERT INTO room_members (room_id, user_id) VALUES (?, ?)', [id, userId]);
    res.status(201).json({ id, code, name: name.trim(), createdBy: userId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/join  => body: { code, userId }
app.post('/rooms/join', async (req, res) => {
  try {
    const { code, userId } = req.body;
    if (!code || !userId) return res.status(400).json({ error: 'code and userId required' });

    const [rooms] = await pool.execute('SELECT * FROM rooms WHERE code = ?', [code.trim().toUpperCase()]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });

    const room = rooms[0];
    // If user previously left (soft-deleted), rejoin by clearing left_at
    await pool.execute(
      `INSERT INTO room_members (room_id, user_id, left_at) VALUES (?, ?, NULL)
       ON DUPLICATE KEY UPDATE left_at = NULL`,
      [room.id, userId]
    );
    res.json({ id: room.id, code: room.code, name: room.name, createdBy: room.created_by || null });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rooms/:roomId  => full room data
app.get('/rooms/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;

    const [rooms] = await pool.execute('SELECT * FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    const room = rooms[0];

    const [items] = await pool.execute(
      'SELECT * FROM items WHERE room_id = ? ORDER BY created_at',
      [roomId]
    );

    const [members] = await pool.execute(
      `SELECT rm.user_id AS id, COALESCE(u.name, g.name, 'Unknown (Guest)') AS name, rm.left_at
       FROM room_members rm
       LEFT JOIN users u ON u.id = rm.user_id
       LEFT JOIN guest_users g ON g.id = rm.user_id
       WHERE rm.room_id = ?`,
      [roomId]
    );

    const membersWithCart = await Promise.all(
      members.map(async (member) => {
        const [cartRows] = await pool.execute(
          `SELECT ci.item_id, ci.quantity, i.name AS item_name, i.unit_price
           FROM cart_items ci
           JOIN items i ON i.id = ci.item_id
           WHERE ci.user_id = ? AND i.room_id = ?`,
          [member.id, roomId]
        );
        return {
          id: member.id,
          name: member.name,
          left: member.left_at !== null,
          cart: cartRows.map((r) => ({
            itemId: r.item_id,
            itemName: r.item_name,
            unitPrice: parseFloat(r.unit_price),
            quantity: r.quantity,
          })),
        };
      })
    );

    res.json({
      id: room.id,
      code: room.code,
      name: room.name,
      createdBy: room.created_by || null,
      isConfirmed: room.is_confirmed === 1,
      items: items.map((i) => ({
        id: i.id,
        name: i.name,
        unitPrice: parseFloat(i.unit_price),
      })),
      members: membersWithCart,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId  => delete room (admin only)
app.delete('/rooms/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== userId)
      return res.status(403).json({ error: 'Only the room admin can delete this room' });

    await pool.execute('DELETE FROM rooms WHERE id = ?', [roomId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId/members/:userId  => leave room (self) or admin removes member
// body: { requesterId }  — if requesterId !== userId it is an admin removal (hard delete + data purge)
app.delete('/rooms/:roomId/members/:userId', async (req, res) => {
  try {
    const { roomId, userId } = req.params;
    const { requesterId } = req.body || {};

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by === userId)
      return res.status(400).json({ error: 'Admin cannot leave. Delete the room instead.' });

    const isAdminRemoving = requesterId && requesterId !== userId;

    if (isAdminRemoving) {
      // Admin removes member: keep financial history (deposits, split assignments),
      // only clear cart and remove from room
      await pool.execute(
        'DELETE ci FROM cart_items ci JOIN items i ON i.id = ci.item_id WHERE ci.user_id = ? AND i.room_id = ?',
        [userId, roomId]
      );
      await pool.execute('DELETE FROM room_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    } else {
      // Self-leave: soft delete — data stays, cart cleared
      await pool.execute(
        'UPDATE room_members SET left_at = NOW() WHERE room_id = ? AND user_id = ?',
        [roomId, userId]
      );
      await pool.execute(
        'DELETE ci FROM cart_items ci JOIN items i ON i.id = ci.item_id WHERE ci.user_id = ? AND i.room_id = ?',
        [userId, roomId]
      );
    }
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/:roomId/items  => body: { name, unitPrice }
app.post('/rooms/:roomId/items', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { name, unitPrice } = req.body;
    if (!name || unitPrice == null)
      return res.status(400).json({ error: 'name and unitPrice required' });

    const id = uuidv4();
    await pool.execute(
      'INSERT INTO items (id, room_id, name, unit_price) VALUES (?, ?, ?, ?)',
      [id, roomId, name.trim(), unitPrice]
    );
    res.status(201).json({ id, name: name.trim(), unitPrice: parseFloat(unitPrice) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId/items/:itemId
app.delete('/rooms/:roomId/items/:itemId', async (req, res) => {
  try {
    const { itemId } = req.params;
    await pool.execute('DELETE FROM items WHERE id = ?', [itemId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /rooms/:roomId/confirm  => body: { userId } — admin toggles confirmed state
app.patch('/rooms/:roomId/confirm', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const [rooms] = await pool.execute('SELECT created_by, is_confirmed FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== userId)
      return res.status(403).json({ error: 'Only admin can confirm' });

    const newState = rooms[0].is_confirmed ? 0 : 1;
    await pool.execute('UPDATE rooms SET is_confirmed = ? WHERE id = ?', [newState, roomId]);
    res.json({ isConfirmed: newState === 1 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/:roomId/new-session  => body: { userId } — save summary, clear carts, unconfirm
app.post('/rooms/:roomId/new-session', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== userId)
      return res.status(403).json({ error: 'Only admin can start new session' });

    // Build summary snapshot
    const [members] = await pool.execute(
      `SELECT rm.user_id AS id, COALESCE(u.name, g.name, 'Unknown (Guest)') AS name
       FROM room_members rm
       LEFT JOIN users u ON u.id = rm.user_id
       LEFT JOIN guest_users g ON g.id = rm.user_id
       WHERE rm.room_id = ?`,
      [roomId]
    );
    const membersData = await Promise.all(members.map(async (m) => {
      const [cart] = await pool.execute(
        `SELECT ci.quantity, i.name AS item_name, i.unit_price
         FROM cart_items ci JOIN items i ON i.id = ci.item_id
         WHERE ci.user_id = ? AND i.room_id = ?`,
        [m.id, roomId]
      );
      const total = cart.reduce((s, r) => s + parseFloat(r.unit_price) * r.quantity, 0);
      return { id: m.id, name: m.name, items: cart.map(r => ({ name: r.item_name, unitPrice: parseFloat(r.unit_price), quantity: r.quantity })), total };
    }));
    const grandTotal = membersData.reduce((s, m) => s + m.total, 0);

    // Count sessions for this room
    const [countRows] = await pool.execute('SELECT COUNT(*) AS cnt FROM session_summaries WHERE room_id = ?', [roomId]);
    const sessionNumber = (countRows[0].cnt || 0) + 1;

    // Save summary
    const summaryId = require('crypto').randomUUID();
    await pool.execute(
      'INSERT INTO session_summaries (id, room_id, session_number, summary_data, grand_total) VALUES (?, ?, ?, ?, ?)',
      [summaryId, roomId, sessionNumber, JSON.stringify({ members: membersData }), grandTotal]
    );

    // Clear all carts for this room and unconfirm
    await pool.execute(
      'DELETE ci FROM cart_items ci JOIN items i ON i.id = ci.item_id WHERE i.room_id = ?',
      [roomId]
    );
    await pool.execute('UPDATE rooms SET is_confirmed = 0 WHERE id = ?', [roomId]);

    res.json({ success: true, sessionNumber, grandTotal });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT /users/:userId/cart/:itemId  => body: { quantity }
app.put('/users/:userId/cart/:itemId', async (req, res) => {
  try {
    const { userId, itemId } = req.params;
    const { quantity } = req.body;
    if (quantity == null) return res.status(400).json({ error: 'quantity required' });

    // Block if room is confirmed
    const [itemRows] = await pool.execute('SELECT room_id FROM items WHERE id = ?', [itemId]);
    if (itemRows.length > 0) {
      const [roomRows] = await pool.execute('SELECT is_confirmed FROM rooms WHERE id = ?', [itemRows[0].room_id]);
      if (roomRows.length > 0 && roomRows[0].is_confirmed === 1)
        return res.status(403).json({ error: 'Room is confirmed. Cannot update cart.' });
    }

    if (quantity <= 0) {
      await pool.execute('DELETE FROM cart_items WHERE user_id = ? AND item_id = ?', [userId, itemId]);
    } else {
      await pool.execute(
        `INSERT INTO cart_items (user_id, item_id, quantity) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE quantity = ?`,
        [userId, itemId, quantity, quantity]
      );
    }
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /users/:userId/cart/:itemId
app.delete('/users/:userId/cart/:itemId', async (req, res) => {
  try {
    const { userId, itemId } = req.params;
    // Block if room is confirmed
    const [itemRows] = await pool.execute('SELECT room_id FROM items WHERE id = ?', [itemId]);
    if (itemRows.length > 0) {
      const [roomRows] = await pool.execute('SELECT is_confirmed FROM rooms WHERE id = ?', [itemRows[0].room_id]);
      if (roomRows.length > 0 && roomRows[0].is_confirmed === 1)
        return res.status(403).json({ error: 'Room is confirmed. Cannot update cart.' });
    }
    await pool.execute('DELETE FROM cart_items WHERE user_id = ? AND item_id = ?', [userId, itemId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rooms/:roomId/sessions  => list of session summaries newest first
app.get('/rooms/:roomId/sessions', async (req, res) => {
  try {
    const { roomId } = req.params;
    const [rows] = await pool.execute(
      'SELECT id, session_number, summary_data, grand_total, created_at FROM session_summaries WHERE room_id = ? ORDER BY session_number DESC',
      [roomId]
    );
    res.json(rows.map(r => ({
      id: r.id,
      sessionNumber: r.session_number,
      grandTotal: parseFloat(r.grand_total),
      createdAt: r.created_at,
      members: JSON.parse(r.summary_data).members || [],
    })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rooms/:roomId/balance  => per-member expense/deposit/balance summary
app.get('/rooms/:roomId/balance', async (req, res) => {
  try {
    const { roomId } = req.params;

    // Include left members too so their balance history is preserved; mark them with "(left)"
    const [members] = await pool.execute(
      `SELECT rm.user_id AS id, COALESCE(u.name, g.name, 'Unknown (Guest)') AS name, rm.left_at
       FROM room_members rm
       LEFT JOIN users u ON u.id = rm.user_id
       LEFT JOIN guest_users g ON g.id = rm.user_id
       WHERE rm.room_id = ?`,
      [roomId]
    );

    const [sessions] = await pool.execute(
      `SELECT session_number, summary_data, created_at FROM session_summaries WHERE room_id = ? ORDER BY session_number ASC`,
      [roomId]
    );

    const [splitRows] = await pool.execute(
      `SELECT sea.user_id, sea.amount, se.id AS split_expense_id, se.item_name, se.created_at
       FROM split_expense_assignments sea
       JOIN split_expenses se ON se.id = sea.split_expense_id
       WHERE se.room_id = ? ORDER BY se.created_at DESC`,
      [roomId]
    );

    const [depositRows] = await pool.execute(
      `SELECT d.id, d.user_id, d.amount, d.note, d.created_at,
              COALESCE(u2.name, g2.name) AS added_by_name
       FROM deposits d
       LEFT JOIN users u2 ON u2.id = d.added_by
       LEFT JOIN guest_users g2 ON g2.id = d.added_by
       WHERE d.room_id = ? ORDER BY d.created_at DESC`,
      [roomId]
    );

    const result = members.map(m => {
      const cartExpenses = sessions.map(s => {
        const data = JSON.parse(s.summary_data);
        const md = data.members?.find(x => (x.id && x.id === m.id) || (!x.id && x.name === m.name));
        if (!md || !md.total) return null;
        return { sessionNumber: s.session_number, amount: parseFloat(md.total), createdAt: s.created_at };
      }).filter(Boolean);

      const splitExpenses = splitRows
        .filter(r => r.user_id === m.id)
        .map(r => ({ splitExpenseId: r.split_expense_id, itemName: r.item_name, amount: parseFloat(r.amount), createdAt: r.created_at }));

      const deposits = depositRows
        .filter(r => r.user_id === m.id)
        .map(r => ({ id: r.id, amount: parseFloat(r.amount), note: r.note || '', createdAt: r.created_at, addedBy: r.added_by_name || '' }));

      const round2 = v => Math.round(v * 100) / 100;
      const totalCartExpense  = round2(cartExpenses.reduce((s, x) => s + x.amount, 0));
      const totalSplitExpense = round2(splitExpenses.reduce((s, x) => s + x.amount, 0));
      const totalExpense      = round2(totalCartExpense + totalSplitExpense);
      const totalDeposited    = round2(deposits.reduce((s, x) => s + x.amount, 0));
      const balance           = round2(totalDeposited - totalExpense);

      const displayName = m.left_at ? `${m.name} (left)` : m.name;
      return { userId: m.id, name: displayName, cartExpenses, splitExpenses, deposits,
        totalCartExpense, totalSplitExpense, totalExpense, totalDeposited, balance };
    });

    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/:roomId/deposits  => body: { userId, targetUserId, amount, note? }
app.post('/rooms/:roomId/deposits', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userId, targetUserId, amount, note } = req.body;
    if (!userId || !targetUserId || amount == null)
      return res.status(400).json({ error: 'userId, targetUserId, amount required' });
    if (parseFloat(amount) <= 0) return res.status(400).json({ error: 'Amount must be positive' });

    const [mRows] = await pool.execute('SELECT user_id FROM room_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    if (mRows.length === 0) return res.status(403).json({ error: 'Not a room member' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms[0].created_by !== userId && userId !== targetUserId)
      return res.status(403).json({ error: 'You can only add deposits for yourself' });

    const id = uuidv4();
    await pool.execute(
      'INSERT INTO deposits (id, room_id, user_id, added_by, amount, note) VALUES (?, ?, ?, ?, ?, ?)',
      [id, roomId, targetUserId, userId, parseFloat(amount), note?.trim() || null]
    );
    res.status(201).json({ id, success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/:roomId/split-expense  => body: { userId, itemName, totalAmount, memberIds? } — admin only
app.post('/rooms/:roomId/split-expense', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userId, itemName, totalAmount, memberIds } = req.body;
    if (!userId || !itemName || totalAmount == null)
      return res.status(400).json({ error: 'userId, itemName, totalAmount required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== userId) return res.status(403).json({ error: 'Only admin can add split expenses' });

    // Determine target members: use provided memberIds or all active (non-left) members
    let targetMembers;
    if (Array.isArray(memberIds) && memberIds.length > 0) {
      targetMembers = memberIds.map(id => ({ user_id: id }));
    } else {
      const [activeRows] = await pool.execute(
        'SELECT user_id FROM room_members WHERE room_id = ? AND left_at IS NULL',
        [roomId]
      );
      targetMembers = activeRows;
    }

    if (targetMembers.length === 0) return res.status(400).json({ error: 'No members to split among' });

    const memberCount = targetMembers.length;
    const perMember = parseFloat(totalAmount) / memberCount;
    const expenseId = uuidv4();

    await pool.execute(
      'INSERT INTO split_expenses (id, room_id, item_name, total_amount, per_member_amount, member_count, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [expenseId, roomId, itemName.trim(), parseFloat(totalAmount), perMember, memberCount, userId]
    );

    for (const m of targetMembers) {
      await pool.execute(
        'INSERT INTO split_expense_assignments (id, split_expense_id, user_id, amount) VALUES (?, ?, ?, ?)',
        [uuidv4(), expenseId, m.user_id, perMember]
      );
    }

    res.status(201).json({ success: true, perMember, memberCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /rooms/:roomId/finance-history  => flat list of all deposits & split expenses
app.get('/rooms/:roomId/finance-history', async (req, res) => {
  try {
    const { roomId } = req.params;

    const [depositRows] = await pool.execute(
      `SELECT d.id, d.user_id,
              COALESCE(u.name, g.name, 'Unknown (Guest)') AS user_name,
              d.amount, d.note, d.created_at,
              COALESCE(u2.name, g2.name) AS added_by_name,
              rm.left_at
       FROM deposits d
       LEFT JOIN users u ON u.id = d.user_id
       LEFT JOIN guest_users g ON g.id = d.user_id
       LEFT JOIN users u2 ON u2.id = d.added_by
       LEFT JOIN guest_users g2 ON g2.id = d.added_by
       LEFT JOIN room_members rm ON rm.user_id = d.user_id AND rm.room_id = d.room_id
       WHERE d.room_id = ? ORDER BY d.created_at DESC`,
      [roomId]
    );

    const [splitRows] = await pool.execute(
      `SELECT id, item_name, total_amount, per_member_amount, member_count, created_at
       FROM split_expenses WHERE room_id = ? ORDER BY created_at DESC`,
      [roomId]
    );

    // Fetch member assignments for each split expense
    const [assignRows] = await pool.execute(
      `SELECT sea.split_expense_id,
              COALESCE(u.name, g.name, 'Unknown (Guest)') AS user_name,
              sea.amount, rm.left_at
       FROM split_expense_assignments sea
       LEFT JOIN users u ON u.id = sea.user_id
       LEFT JOIN guest_users g ON g.id = sea.user_id
       LEFT JOIN room_members rm ON rm.user_id = sea.user_id AND rm.room_id = ?
       WHERE sea.split_expense_id IN (
         SELECT id FROM split_expenses WHERE room_id = ?
       )
       ORDER BY user_name ASC`,
      [roomId, roomId]
    );

    // Group assignments by split_expense_id
    const assignMap = {};
    for (const r of assignRows) {
      if (!assignMap[r.split_expense_id]) assignMap[r.split_expense_id] = [];
      assignMap[r.split_expense_id].push({
        name: r.left_at ? `${r.user_name} (left)` : r.user_name,
        amount: parseFloat(r.amount),
      });
    }

    res.json({
      deposits: depositRows.map(r => ({
        id: r.id,
        userId: r.user_id,
        userName: r.left_at ? `${r.user_name} (left)` : r.user_name,
        amount: parseFloat(r.amount),
        note: r.note || '',
        addedByName: r.added_by_name || '',
        createdAt: r.created_at,
      })),
      splitExpenses: splitRows.map(r => ({
        id: r.id,
        itemName: r.item_name,
        totalAmount: parseFloat(r.total_amount),
        perMemberAmount: parseFloat(r.per_member_amount),
        memberCount: r.member_count,
        members: assignMap[r.id] || [],
        createdAt: r.created_at,
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /rooms/:roomId/members  => body: { adminId, username } — admin adds member by username
app.post('/rooms/:roomId/members', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { adminId, username } = req.body;
    if (!adminId || !username) return res.status(400).json({ error: 'adminId and username required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== adminId) return res.status(403).json({ error: 'Only admin can add members' });

    const [users] = await pool.execute('SELECT id, name FROM users WHERE username = ?', [username.trim().toLowerCase()]);
    let newUser;
    if (users.length === 0) {
      // Not a signup user — check guest_users scoped to this room
      const [guestRows] = await pool.execute(
        'SELECT id, name FROM guest_users WHERE username = ? AND room_id = ?',
        [username.trim().toLowerCase(), roomId]
      );
      if (guestRows.length > 0) {
        newUser = guestRows[0];
      } else {
        // Guest doesn't exist in this room yet — create in guest_users only (NOT in users table)
        const guestId = uuidv4();
        const guestUsername = username.trim().toLowerCase();
        const trimmed = username.trim();
        const guestName = trimmed.charAt(0).toUpperCase() + trimmed.slice(1) + ' (Guest)';
        await pool.execute(
          'INSERT INTO guest_users (id, username, name, room_id, created_by) VALUES (?, ?, ?, ?, ?)',
          [guestId, guestUsername, guestName, roomId, adminId]
        );
        newUser = { id: guestId, name: guestName };
      }
    } else {
      newUser = users[0];
    }
    const [existing] = await pool.execute('SELECT user_id, left_at FROM room_members WHERE room_id = ? AND user_id = ?', [roomId, newUser.id]);
    if (existing.length > 0 && existing[0].left_at === null) {
      // Already an active member — return success (idempotent)
      return res.status(201).json({ success: true, userId: newUser.id, name: newUser.name, alreadyMember: true });
    }

    if (existing.length > 0 && existing[0].left_at !== null) {
      // Previously left — re-add by clearing left_at
      await pool.execute('UPDATE room_members SET left_at = NULL WHERE room_id = ? AND user_id = ?', [roomId, newUser.id]);
    } else {
      await pool.execute('INSERT INTO room_members (room_id, user_id) VALUES (?, ?)', [roomId, newUser.id]);
    }
    res.status(201).json({ success: true, userId: newUser.id, name: newUser.name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId/deposits/:depositId  => body: { adminId }
app.delete('/rooms/:roomId/deposits/:depositId', async (req, res) => {
  try {
    const { roomId, depositId } = req.params;
    const { adminId } = req.body;
    if (!adminId) return res.status(400).json({ error: 'adminId required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== adminId) return res.status(403).json({ error: 'Only admin can delete deposits' });

    await pool.execute('DELETE FROM deposits WHERE id = ? AND room_id = ?', [depositId, roomId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId/split-expenses/:expenseId  => body: { adminId }
app.delete('/rooms/:roomId/split-expenses/:expenseId', async (req, res) => {
  try {
    const { roomId, expenseId } = req.params;
    const { adminId } = req.body;
    if (!adminId) return res.status(400).json({ error: 'adminId required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== adminId) return res.status(403).json({ error: 'Only admin can delete split expenses' });

    await pool.execute('DELETE FROM split_expenses WHERE id = ? AND room_id = ?', [expenseId, roomId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /rooms/:roomId/sessions/:sessionId  => body: { adminId }
app.delete('/rooms/:roomId/sessions/:sessionId', async (req, res) => {
  try {
    const { roomId, sessionId } = req.params;
    const { adminId } = req.body;
    if (!adminId) return res.status(400).json({ error: 'adminId required' });

    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by !== adminId) return res.status(403).json({ error: 'Only admin can delete sessions' });

    await pool.execute('DELETE FROM session_summaries WHERE id = ? AND room_id = ?', [sessionId, roomId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Room Expense API listening on port ${PORT}`));
