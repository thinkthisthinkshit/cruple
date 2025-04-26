import { defineConfig } from 'vite';
   import react from '@vitejs/plugin-react';
   import fs from 'fs';

   export default defineConfig({
     plugins: [react()],
     server: {
       https: {
         key: fs.readFileSync('localhost-key.pem'),
         cert: fs.readFileSync('localhost.pem'),
       },
       port: 5173,
     },
   });







server.js:
const fastify = require('fastify')({ logger: true });
require('dotenv').config();

fastify.register(require('./routes/signal'));

fastify.get('/api/wallet/:userId', async (request, reply) => {
  const { userId } = request.params;
  const client = await fastify.pg.connect();
  try {
    const { rows } = await client.query('SELECT address, balance FROM wallets WHERE user_id = $1', [userId]);
    if (rows.length === 0) {
      return { error: 'Wallet not found' };
    }
    return rows[0];
  } finally {
    client.release();
  }
});

const start = async () => {
  try {
    await fastify.listen({ port: 3000 });
    console.log('Server running at http://localhost:3000');
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();




signal.js:
const { Pool } = require('pg');
const ccxt = require('ccxt');
const { RSI } = require('technicalindicators');

const pool = new Pool({
  user: process.env.DB_USER,
  host: 'localhost',
  database: 'crypto_signals',
  password: process.env.DB_PASSWORD,
  port: 5432,
});

module.exports = async function (fastify, opts) {
  fastify.post('/signal/:userId/:symbol', async (request, reply) => {
    const { userId, symbol } = request.params;
    const result = await pool.query('SELECT balance FROM wallets WHERE user_id = $1', [userId]);
    if (result.rows.length === 0 || result.rows[0].balance < 0.1) {
      return { error: 'Insufficient balance' };
    }

    const newBalance = result.rows[0].balance - 0.1;
    await pool.query('UPDATE wallets SET balance = $1 WHERE user_id = $2', [newBalance, userId]);

    const exchange = new ccxt.binance();
    const ohlcv = await exchange.fetchOHLCV(`${symbol}/USDT`, '1h', undefined, 100);
    const closes = ohlcv.map(candle => candle[4]);

    const rsi = RSI.calculate({ period: 14, values: closes });
    const lastRSI = rsi[rsi.length - 1];
    const signal = lastRSI < 30 ? 'BUY' : lastRSI > 70 ? 'SELL' : 'HOLD';

    return { signal, newBalance };
  });
};


backend/.env:
DB_USER=your_db_user
DB_PASSWORD=your_db_password
TON_API_KEY=your_toncenter_api_key



frontend package.json:
{
  "name": "btc-signals-frontend",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "qrcode.react": "^3.1.0",
    "tailwindcss": "^3.3.0"
  },
  "devDependencies": {
    "vite": "^4.0.0",
    "@vitejs/plugin-react": "^4.0.0"
  }
}




WalletForm:
import { useState, useEffect } from 'react';
import QRCode from 'qrcode.react';

function WalletForm({ userId }) {
  const [address, setAddress] = useState('');
  const [balance, setBalance] = useState(0);

  useEffect(() => {
    fetch(`http://localhost:3000/api/wallet/${userId}`)
      .then(res => res.json())
      .then(data => {
        setAddress(data.address);
        setBalance(data.balance);
      });
  }, [userId]);

  const topUp = () => {
    window.Telegram.WebApp.openTelegramLink(
      `https://t.me/wallet?start=send&address=${address}&amount=1`
    );
  };

  return (
    <div className="mb-4">
      <p className="text-lg">Balance: {balance} TON</p>
      <p className="text-sm break-all">Address: {address}</p>
      {address && (
        <div className="mt-2">
          <QRCode value={address} size={128} />
        </div>
      )}
      <button
        className="bg-blue-500 text-white p-2 rounded mt-2"
        onClick={topUp}
      >
        Top Up via Telegram Wallet
      </button>
    </div>
  );
}

export default WalletForm;




bot/package.json:
{
  "name": "btc-signals-bot",
  "version": "1.0.0",
  "main": "src/bot.js",
  "scripts": {
    "start": "node src/bot.js"
  },
  "dependencies": {
    "telegraf": "^4.0.0"
  }
}




bot.js:
const { Telegraf } = require('telegraf');

const bot = new Telegraf('YOUR_BOT_TOKEN');

bot.start((ctx) => {
  ctx.reply('Welcome to BTC Signals! Open the app:', {
    reply_markup: {
      inline_keyboard: [
        [{ text: 'Open App', web_app: { url: 'http://localhost:5173' } }]
      ]
    }
  });
});

bot.launch();
console.log('Bot running...');





PostgreSQL:
CREATE DATABASE crypto_signals;

\c crypto_signals

CREATE TABLE wallets (
  user_id VARCHAR(50) PRIMARY KEY,
  address VARCHAR(100),
  mnemonic TEXT,
  balance FLOAT DEFAULT 0
);






