CREATE DATABASE crypto_signals;
\c crypto_signals
CREATE TABLE wallets (
  user_id VARCHAR(50) PRIMARY KEY,
  address VARCHAR(100),
  mnemonic TEXT,
  balance FLOAT DEFAULT 0
);




require('dotenv').config();
const fastify = require('fastify')({ logger: true });
const { Client } = require('pg');
const Redis = require('redis');
const { TonClient } = require('@ton/ton');

const client = new Client({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: 'crypto_signals',
  host: 'localhost',
  port: 5432,
});

const redis = Redis.createClient();
const tonClient = new TonClient({
  endpoint: 'https://toncenter.com/api/v2/jsonRPC',
  apiKey: process.env.TON_API_KEY,
});

async function start() {
  try {
    // Подключение к PostgreSQL
    await client.connect();
    console.log('Connected to PostgreSQL');

    // Подключение к Redis
    await redis.connect();
    console.log('Connected to Redis');

    // Маршруты
    fastify.get('/api/wallet/:userId', async (request, reply) => {
      const { userId } = request.params;
      try {
        const res = await client.query('SELECT * FROM wallets WHERE user_id = $1', [userId]);
        if (res.rows.length === 0) {
          return { error: 'Wallet not found' };
        }
        return res.rows[0];
      } catch (err) {
        fastify.log.error(err);
        reply.status(500).send({ error: 'Database error' });
      }
    });

    fastify.post('/signal/:userId/:symbol', async (request, reply) => {
      const { userId, symbol } = request.params;
      const exchange = new ccxt.binance();
      try {
        const ohlcv = await exchange.fetchOHLCV(symbol + '/USDT', '1h', undefined, 100);
        const closes = ohlcv.map(candle => candle[4]);

        // Простой сигнал
        const signal = closes[closes.length - 1] > closes[closes.length - 2] ? 'BUY' : 'SELL';

        // Обновление баланса
        await client.query('UPDATE wallets SET balance = balance + 0.1 WHERE user_id = $1', [userId]);
        const res = await client.query('SELECT balance FROM wallets WHERE user_id = $1', [userId]);

        return { signal, newBalance: res.rows[0].balance };
      } catch (err) {
        fastify.log.error(err);
        reply.status(500).send({ error: 'Signal processing error' });
      }
    });

    // Запуск сервера
    await fastify.listen({ port: 3000 });
    console.log('Server running at http://localhost:3000');
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start();
