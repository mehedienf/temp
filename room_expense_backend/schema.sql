-- Run this file once to set up the database

CREATE DATABASE IF NOT EXISTS room_expense CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE room_expense;

CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(36)   PRIMARY KEY,
  username      VARCHAR(50)   UNIQUE NOT NULL,
  name          VARCHAR(100)  NOT NULL,
  password_hash VARCHAR(255)  NOT NULL,
  created_at    DATETIME      DEFAULT CURRENT_TIMESTAMP
);

-- Migration: run these if the table already exists without the new columns
-- ALTER TABLE users ADD COLUMN username VARCHAR(50) UNIQUE NOT NULL AFTER id;
-- ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NOT NULL AFTER name;

CREATE TABLE IF NOT EXISTS rooms (
  id         VARCHAR(36)  PRIMARY KEY,
  code       VARCHAR(6)   UNIQUE NOT NULL,
  name       VARCHAR(100) NOT NULL,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS room_members (
  room_id    VARCHAR(36) NOT NULL,
  user_id    VARCHAR(36) NOT NULL,
  joined_at  DATETIME    DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (room_id, user_id),
  FOREIGN KEY (room_id) REFERENCES rooms(id)  ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id)  ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS items (
  id         VARCHAR(36)    PRIMARY KEY,
  room_id    VARCHAR(36)    NOT NULL,
  name       VARCHAR(100)   NOT NULL,
  unit_price DECIMAL(10,2)  NOT NULL,
  created_at DATETIME       DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cart_items (
  user_id    VARCHAR(36) NOT NULL,
  item_id    VARCHAR(36) NOT NULL,
  quantity   INT         NOT NULL DEFAULT 1,
  updated_at DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, item_id),
  FOREIGN KEY (user_id) REFERENCES users(id)  ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES items(id)  ON DELETE CASCADE
);
