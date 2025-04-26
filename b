assoc .cmd=batfile
ftype batfile="%SystemRoot%\System32\cmd.exe" /c "%1" %*



assoc .js=JSFile
ftype JSFile="C:\Program Files\nodejs\node.exe" "%1" %*





where node




$Env:Path

notepad $PROFILE

New-Item -Path $PROFILE -ItemType File -Force


$Env:Path += ";C:\Program Files\nodejs;C:\Users\DIMA$\AppData\Roaming\npm"



Get-ExecutionPolicy

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned







index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Crypto Signals</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://telegram.org/js/telegram-web-app.js"></script>
</head>
<body>
  <div id="root"></div>
  <script type="module">
    const { createRoot } = ReactDOM;
    const { useState, useEffect } = React;

    function App() {
      const [userId, setUserId] = useState(null);
      const [address, setAddress] = useState('');
      const [balance, setBalance] = useState(0);
      const [selectedCoin, setSelectedCoin] = useState('BTC');
      const [signal, setSignal] = useState('');

      useEffect(() => {
        // Инициализация Telegram Web App
        window.Telegram.WebApp.ready();
        window.Telegram.WebApp.expand();
        setUserId(window.Telegram.WebApp.initDataUnsafe.user?.id);

        // Получение адреса и баланса
        if (userId) {
          fetch(`https://your-backend.com/api/wallet/${userId}`)
            .then(res => res.json())
            .then(data => {
              setAddress(data.address);
              setBalance(data.balance);
            });
        }
      }, [userId]);

      const topUp = () => {
        // Открываем Telegram Wallet для пополнения
        window.Telegram.WebApp.openTelegramLink(
          `https://t.me/wallet?start=send&address=${address}&amount=1`
        );
      };

      const getSignal = () => {
        fetch(`https://your-backend.com/api/signal/${userId}/${selectedCoin}`, { method: 'POST' })
          .then(res => res.json())
          .then(data => {
            setSignal(data.signal);
            setBalance(data.newBalance);
          });
      };

      return (
        <div className="p-4 max-w-md mx-auto">
          <h1 className="text-2xl font-bold mb-4">Crypto Signals</h1>
          <div className="mb-4">
            <p className="text-lg">Balance: {balance} TON</p>
            <p className="text-sm break-all">Address: {address}</p>
            <button
              className="bg-blue-500 text-white p-2 rounded mt-2"
              onClick={topUp}
            >
              Top Up via Telegram Wallet
            </button>
          </div>
          <div className="mb-4">
            <label className="block mb-1">Select Cryptocurrency:</label>
            <select
              className="border p-2 w-full"
              value={selectedCoin}
              onChange={e => setSelectedCoin(e.target.value)}
            >
              <option value="BTC">Bitcoin (BTC)</option>
              <option value="ETH">Ethereum (ETH)</option>
              <option value="DOGE">Dogecoin (DOGE)</option>
            </select>
          </div>
          <button
            className="bg-green-500 text-white p-2 rounded w-full"
            onClick={getSignal}
          >
            Get Signal (0.1 TON)
          </button>
          {signal && (
            <div className="mt-4 p-4 bg-gray-100 rounded">
              <p>Signal: {signal}</p>
            </div>
          )}
        </div>
      );
    }

    const root = createRoot(document.getElementById('root'));
    root.render(<App />);
  </script>
</body>
</html>



server.js:
const fastify = require('fastify')();
const { TonClient, WalletContractV4, mnemonicNew } = require('@ton/ton');
const { mnemonicToPrivateKey } = require('@ton/crypto');
const ccxt = require('ccxt');
const talib = require('talib');
const { Pool } = require('pg');
const crypto = require('crypto');

// Подключение к базе данных
const pool = new Pool({
  user: 'your_db_user',
  host: 'localhost',
  database: 'crypto_signals',
  password: 'your_db_password',
  port: 5432,
});

// TON клиент
const client = new TonClient({
  endpoint: 'https://toncenter.com/api/v2/jsonRPC',
});

// Генерация нового кошелька для пользователя
async function createWallet(userId) {
  const mnemonic = await mnemonicNew();
  const keyPair = await mnemonicToPrivateKey(mnemonic);
  const wallet = WalletContractV4.create({ publicKey: keyPair.publicKey, workchain: 0 });
  const address = wallet.address.toString();

  // Шифрование seed-фразы
  const encryptedMnemonic = crypto.createCipher('aes-256-cbc', 'your_secret_key')
    .update(mnemonic.join(' '), 'utf8', 'hex') + crypto.createCipher('aes-256-cbc', 'your_secret_key').final('hex');

  // Сохранение в базе
  await pool.query(
    'INSERT INTO wallets (user_id, address, mnemonic) VALUES ($1, $2, $3) ON CONFLICT (user_id) DO NOTHING',
    [userId, address, encryptedMnemonic]
  );

  return { address, mnemonic };
}

// Получение кошелька пользователя
fastify.get('/api/wallet/:userId', async (request, reply) => {
  const { userId } = request.params;
  const result = await pool.query('SELECT address, balance FROM wallets WHERE user_id = $1', [userId]);

  if (result.rows.length === 0) {
    const { address } = await createWallet(userId);
    return { address, balance: 0 };
  }

  const { address } = result.rows[0];
  const balance = await client.getBalance(address);
  return { address, balance: Number(balance) / 1e9 }; // Конвертация из нанотонов
});

// Пополнение (отслеживание транзакций)
fastify.get('/api/check-transactions/:userId', async (request, reply) => {
  const { userId } = request.params;
  const result = await pool.query('SELECT address FROM wallets WHERE user_id = $1', [userId]);
  if (result.rows.length === 0) return { error: 'Wallet not found' };

  const { address } = result.rows[0];
  const transactions = await client.getTransactions(address, { limit: 10 });
  let balance = 0;

  for (const tx of transactions) {
    if (tx.in_msg.value) {
      balance += tx.in_msg.value / 1e9;
    }
  }

  await pool.query('UPDATE wallets SET balance = $1 WHERE user_id = $2', [balance, userId]);
  return { balance };
});

// Генерация сигнала
fastify.post('/api/signal/:userId/:symbol', async (request, reply) => {
  const { userId, symbol } = request.params;
  const result = await pool.query('SELECT balance FROM wallets WHERE user_id = $1', [userId]);
  if (result.rows.length === 0 || result.rows[0].balance < 0.1) {
    return { error: 'Insufficient balance' };
  }

  // Списание 0.1 TON
  const newBalance = result.rows[0].balance - 0.1;
  await pool.query('UPDATE wallets SET balance = $1 WHERE user_id = $2', [newBalance, userId]);

  // Генерация сигнала (упрощённый пример)
  const exchange = new ccxt.binance();
  const ohlcv = await exchange.fetchOHLCV(`${symbol}/USDT`, '1h', undefined, 100);
  const closes = ohlcv.map(candle => candle[4]);
  const rsi = talib.execute({
    name: 'RSI',
    startIdx: 0,
    endIdx: closes.length - 1,
    inReal: closes,
    optInTimePeriod: 14,
  });

  const lastRSI = rsi.result.outReal[rsi.result.outReal.length - 1];
  const signal = lastRSI < 30 ? 'BUY' : lastRSI > 70 ? 'SELL' : 'HOLD';

  return { signal, newBalance };
});

fastify.listen({ port: 3000 }, (err) => {
  if (err) throw err;
  console.log('Server running on port 3000');
});





bot.js:
const { Telegraf } = require('telegraf');

const bot = new Telegraf('YOUR_BOT_TOKEN');

bot.start((ctx) => {
  ctx.reply('Welcome to Crypto Signals!', {
    reply_markup: {
      inline_keyboard: [[
        { text: 'Open App', web_app: { url: 'https://your-tma-url.vercel.app' } }
      ]]
    }
  });
});

bot.launch();


DEPENDENCIES:
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@twa-dev/sdk": "^7.0.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}



BACKEND:


{
  "dependencies": {
    "fastify": "^4.0.0",
    "pg": "^8.0.0",
    "redis": "^4.0.0",
    "@ton/ton": "^13.0.0",
    "@ton/crypto": "^3.0.0",
    "ccxt": "^4.0.0",
    "talib": "^1.0.0"
  }
}


BOT:
{
  "dependencies": {
    "telegraf": "^4.0.0"
  }
}
