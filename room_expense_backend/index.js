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

// GET /users/:userId/rooms  => list of rooms the user has joined
app.get('/users/:userId/rooms', async (req, res) => {
  try {
    const { userId } = req.params;
    const [rooms] = await pool.execute(
      `SELECT r.id, r.code, r.name FROM rooms r
       JOIN room_members rm ON rm.room_id = r.id
       WHERE rm.user_id = ?
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
    await pool.execute(
      'INSERT IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)',
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
      `SELECT u.id, u.name FROM users u
       JOIN room_members rm ON rm.user_id = u.id
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

// DELETE /rooms/:roomId/members/:userId  => leave room
app.delete('/rooms/:roomId/members/:userId', async (req, res) => {
  try {
    const { roomId, userId } = req.params;
    // Prevent admin from leaving without deleting (keep room alive)
    const [rooms] = await pool.execute('SELECT created_by FROM rooms WHERE id = ?', [roomId]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    if (rooms[0].created_by === userId)
      return res.status(400).json({ error: 'Admin cannot leave. Delete the room instead.' });

    await pool.execute('DELETE FROM room_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    // Also clean up their cart items for this room
    await pool.execute(
      'DELETE ci FROM cart_items ci JOIN items i ON i.id = ci.item_id WHERE ci.user_id = ? AND i.room_id = ?',
      [userId, roomId]
    );
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

// PUT /users/:userId/cart/:itemId  => body: { quantity }
app.put('/users/:userId/cart/:itemId', async (req, res) => {
  try {
    const { userId, itemId } = req.params;
    const { quantity } = req.body;
    if (quantity == null) return res.status(400).json({ error: 'quantity required' });

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
    await pool.execute('DELETE FROM cart_items WHERE user_id = ? AND item_id = ?', [userId, itemId]);
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Room Expense API listening on port ${PORT}`));
