const express = require('express');
const cors = require('cors');
const routes = require('./src/routes');
const axios = require('axios');

const app = express();

app.use(cors());
app.use(express.json());
app.use('/', routes);

// Настройка команды /start для открытия Mini App
const BOT_TOKEN = process.env.BOT_TOKEN;
const WEB_APP_URL = 'https://frontend-abc123.ngrok.io'; // Замени на твой фронт-URL

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands`, {
  commands: [{ command: 'start', description: 'Открыть SimCard Mini App' }],
}).catch(err => console.error('Ошибка настройки команд:', err));

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setChatMenuButton`, {
  menu_button: {
    type: 'web_app',
    text: 'Открыть Mini App',
    web_app: { url: WEB_APP_URL },
  },
}).catch(err => console.error('Ошибка настройки кнопки:', err));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));





App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountrySelector from './components/CountrySelector';
import ResourceSelector from './components/ResourceSelector';
import BalanceModal from './components/BalanceModal';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [country, setCountry] = useState('');
  const [resource, setResource] = useState('');
  const [balance, setBalance] = useState(null);
  const [address, setAddress] = useState('');
  const [showModal, setShowModal] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    tg.ready();
    tg.MainButton.setText('Купить').show().onClick(handleBuy);
    fetchBalance();
  }, []);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user?.id}`, {
        headers: { 'telegram-init-data': tg.initData },
      });
      setBalance(res.data.balance);
      setAddress(res.data.address);
    } catch (err) {
      tg.showPopup({ message: 'Ошибка загрузки баланса' });
    }
  };

  const handleBuy = async () => {
    if (!country || !resource) {
      tg.showPopup({ message: 'Выберите страну и ресурс' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy`,
        { telegram_id: user?.id, country, resource },
        { headers: { 'telegram-init-data': tg.initData } }
      );
      if (res.data.success) {
        tg.showPopup({ message: `Код: ${res.data.code}` });
        fetchBalance();
      } else {
        setShowModal(true);
      }
    } catch (err) {
      tg.showPopup({ message: 'Ошибка покупки' });
    }
  };

  const handleTopUp = async () => {
    try {
      const res = await axios.post(`${API_URL}/generate-address/${user?.id}`, null, {
        headers: { 'telegram-init-data': tg.initData },
      });
      setAddress(res.data.address);
      setShowModal(true);
    } catch (err) {
      tg.showPopup({ message: 'Ошибка генерации адреса' });
    }
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">SimCard Mini App</h1>
      <CountrySelector onSelect={setCountry} />
      <ResourceSelector onSelect={setResource} />
      <div className="mt-4">
        <p className="text-lg">Баланс: {balance !== null ? `${balance} BTC` : 'Загрузка...'}</p>
      </div>
      {showModal && (
        <BalanceModal
          address={address}
          onClose={() => setShowModal(false)}
          onCopy={() => navigator.clipboard.writeText(address)}
        />
      )}
    </div>
  );
}

export default App;





routes:
const express = require('express');
const db = require('./db');
const { generateAddress, getBalance } = require('./wallet');
const crypto = require('crypto');

const router = express.Router();

// Middleware для проверки initData
const verifyTelegramInitData = (req, res, next) => {
  const initData = req.headers['telegram-init-data'];
  if (!initData) return res.status(401).json({ error: 'No initData' });

  const data = new URLSearchParams(initData);
  const hash = data.get('hash');
  data.delete('hash');
  const dataCheckString = Array.from(data.entries())
    .sort()
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
  
  const secretKey = crypto
    .createHmac('sha256', 'WebAppData')
    .update(process.env.BOT_TOKEN)
    .digest();
  const calculatedHash = crypto
    .createHmac('sha256', secretKey)
    .update(dataCheckString)
    .digest('hex');

  if (calculatedHash === hash) {
    req.telegram_id = data.get('user') ? JSON.parse(data.get('user')).id : null;
    next();
  } else {
    res.status(401).json({ error: 'Invalid initData' });
  }
};

router.get('/countries', (req, res) => {
  res.json([
    { id: 'us', name: 'США' },
    { id: 'ru', name: 'Россия' },
    { id: 'uk', name: 'Великобритания' },
  ]);
});

router.get('/resources', (req, res) => {
  res.json([
    { id: 'whatsapp', name: 'WhatsApp' },
    { id: 'telegram', name: 'Telegram' },
    { id: 'other', name: 'Другой' },
  ]);
});

router.post('/generate-address/:telegram_id', verifyTelegramInitData, async (req, res) => {
  const { telegram_id } = req;
  db.get('SELECT wallet_index FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (row) {
      db.get('SELECT address FROM users WHERE telegram_id = ?', [telegram_id], (err, row) => {
        res.json({ address: row.address });
      });
    } else {
      const index = Math.floor(Math.random() * 1000000);
      const address = await generateAddress(index);
      db.run(
        'INSERT INTO users (telegram_id, wallet_index, address, balance) VALUES (?, ?, ?, ?)',
        [telegram_id, index, address, 0],
        () => res.json({ address })
      );
    }
  });
});

router.get('/balance/:telegram_id', verifyTelegramInitData, async (req, res) => {
  const { telegram_id } = req;
  db.get('SELECT address FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row) {
      return res.json({ balance: 0, address: '' });
    }
    const balance = await getBalance(row.address);
    db.run('UPDATE users SET balance = ? WHERE telegram_id = ?', [balance, telegram_id]);
    res.json({ balance, address: row.address });
  });
});

router.post('/buy', verifyTelegramInitData, async (req, res) => {
  const { telegram_id, country, resource } = req.body;
  db.get('SELECT balance FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row || row.balance < 0.0001) {
      return res.json({ success: false });
    }
    // Mock SMS code (replace with SMS-Activate API)
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    db.run(
      'INSERT INTO purchases (telegram_id, country, resource, code) VALUES (?, ?, ?, ?)',
      [telegram_id, country, resource, code]
    );
    db.run(
      'UPDATE users SET balance = balance - 0.0001 WHERE telegram_id = ?',
      [telegram_id]
    );
    res.json({ success: true, code });
  });
});

module.exports = router;

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SimCard Mini App</title>
  <script src="https://telegram.org/js/telegram-web-app.js"></script>
</head>
<body>
  <div id="root"></div>
</body>
</html>




App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountrySelector from './components/CountrySelector';
import ResourceSelector from './components/ResourceSelector';
import BalanceModal from './components/BalanceModal';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [country, setCountry] = useState('');
  const [resource, setResource] = useState('');
  const [balance, setBalance] = useState(null);
  const [address, setAddress] = useState('');
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    tg.ready();
    tg.MainButton.setText('Купить').show().onClick(handleBuy);
    fetchBalance();
  }, []);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`http://localhost:5000/balance/${user?.id}`);
      setBalance(res.data.balance);
      setAddress(res.data.address);
    } catch (err) {
      tg.showPopup({ message: 'Ошибка загрузки баланса' });
    }
  };

  const handleBuy = async () => {
    if (!country || !resource) {
      tg.showPopup({ message: 'Выберите страну и ресурс' });
      return;
    }
    try {
      const res = await axios.post('http://localhost:5000/buy', {
        telegram_id: user?.id,
        country,
        resource,
      });
      if (res.data.success) {
        tg.showPopup({ message: `Код: ${res.data.code}` });
        fetchBalance();
      } else {
        setShowModal(true);
      }
    } catch (err) {
      tg.showPopup({ message: 'Ошибка покупки' });
    }
  };

  const handleTopUp = async () => {
    try {
      const res = await axios.post(`http://localhost:5000/generate-address/${user?.id}`);
      setAddress(res.data.address);
      setShowModal(true);
    } catch (err) {
      tg.showPopup({ message: 'Ошибка генерации адреса' });
    }
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">SimCard Mini App</h1>
      <CountrySelector onSelect={setCountry} />
      <ResourceSelector onSelect={setResource} />
      <div className="mt-4">
        <p className="text-lg">Баланс: {balance !== null ? `${balance} BTC` : 'Загрузка...'}</p>
      </div>
      {showModal && (
        <BalanceModal
          address={address}
          onClose={() => setShowModal(false)}
          onCopy={() => navigator.clipboard.writeText(address)}
        />
      )}
    </div>
  );
}

export default App;




index.js:
import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';

ReactDOM.render(<App />, document.getElementById('root'));


index.css:
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
}



telegram.js:
import { useEffect } from 'react';

export const useTelegram = () => {
  const tg = window.Telegram.WebApp;

  useEffect(() => {
    tg.expand();
  }, []);

  return {
    tg,
    user: tg.initDataUnsafe?.user,
  };
};




CountrySelector.jsx:
import { useState, useEffect } from 'react';
import axios from 'axios';

const countries = [
  { id: 'us', name: 'США' },
  { id: 'ru', name: 'Россия' },
  { id: 'uk', name: 'Великобритания' },
];

function CountrySelector({ onSelect }) {
  const [selected, setSelected] = useState('');

  useEffect(() => {
    onSelect(selected);
  }, [selected]);

  return (
    <div className="mb-4">
      <label className="block text-lg mb-2">Страна</label>
      <select
        className="w-full p-2 border rounded bg-white dark:bg-gray-800 dark:text-white"
        value={selected}
        onChange={(e) => setSelected(e.target.value)}
      >
        <option value="">Выберите страну</option>
        {countries.map((country) => (
          <option key={country.id} value={country.id}>
            {country.name}
          </option>
        ))}
      </select>
    </div>
  );
}

export default CountrySelector;



ResourceSelector.jsx:
import { useState, useEffect } from 'react';
import axios from 'axios';

const resources = [
  { id: 'whatsapp', name: 'WhatsApp' },
  { id: 'telegram', name: 'Telegram' },
  { id: 'other', name: 'Другой' },
];

function ResourceSelector({ onSelect }) {
  const [selected, setSelected] = useState('');

  useEffect(() => {
    onSelect(selected);
  }, [selected]);

  return (
    <div className="mb-4">
      <label className="block text-lg mb-2">Ресурс</label>
      <select
        className="w-full p-2 border rounded bg-white dark:bg-gray-800 dark:text-white"
        value={selected}
        onChange={(e) => setSelected(e.target.value)}
      >
        <option value="">Выберите ресурс</option>
        {resources.map((resource) => (
          <option key={resource.id} value={resource.id}>
            {resource.name}
          </option>
        ))}
      </select>
    </div>
  );
}

export default ResourceSelector;




BalanceModal.jsx:
import QRCode from 'qrcode.react';

function BalanceModal({ address, onClose, onCopy }) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg max-w-sm w-full">
        <h2 className="text-lg font-bold mb-4">Пополнить баланс</h2>
        <QRCode value={`bitcoin:${address}`} className="mx-auto mb-4" />
        <p className="text-sm text-center mb-4 break-all">{address}</p>
        <div className="flex justify-between">
          <button
            className="bg-blue-500 text-white px-4 py-2 rounded"
            onClick={onCopy}
          >
            Скопировать
          </button>
          <button
            className="bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
          >
            Закрыть
          </button>
        </div>
      </div>
    </div>
  );
}

export default BalanceModal;






client/package.json:
{
  "name": "simcard-mini-app-client",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@vkruglikov/react-telegram-web-app": "^2.1.10",
    "axios": "^1.7.2",
    "qrcode.react": "^3.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "devDependencies": {
    "tailwindcss": "^3.4.10",
    "react-scripts": "5.0.1"
  }
}





client/tailwind.js:
module.exports = {
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
  darkMode: 'class',
};




BACKEND:



server.js:
const express = require('express');
const cors = require('cors');
const routes = require('./src/routes');

const app = express();

app.use(cors());
app.use(express.json());
app.use('/', routes);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));



db.js:
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database(':memory:');

db.serialize(() => {
  db.run(`
    CREATE TABLE users (
      telegram_id TEXT PRIMARY KEY,
      wallet_index INTEGER,
      address TEXT,
      balance REAL
    )
  `);
  db.run(`
    CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      telegram_id TEXT,
      country TEXT,
      resource TEXT,
      code TEXT
    )
  `);
});

module.exports = db;




wallet.js:
const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const axios = require('axios');

const mnemonic = process.env.SEED_PHRASE;
const seed = bip39.mnemonicToSeedSync(mnemonic);
const root = bitcoin.bip32.fromSeed(seed);

async function generateAddress(index) {
  const path = `m/44'/0'/0'/0/${index}`;
  const keyPair = root.derivePath(path);
  const { address } = bitcoin.payments.p2pkh({ pubkey: keyPair.publicKey });
  return address;
}

async function getBalance(address) {
  try {
    const res = await axios.get(`https://api.blockcypher.com/v1/btc/main/addrs/${address}/balance`);
    return res.data.final_balance / 1e8; // Convert satoshis to BTC
  } catch (err) {
    console.error('Balance fetch error:', err);
    return 0;
  }
}

module.exports = { generateAddress, getBalance };





routes.js:
const express = require('express');
const db = require('./db');
const { generateAddress, getBalance } = require('./wallet');

const router = express.Router();

router.get('/countries', (req, res) => {
  res.json([
    { id: 'us', name: 'США' },
    { id: 'ru', name: 'Россия' },
    { id: 'uk', name: 'Великобритания' },
  ]);
});

router.get('/resources', (req, res) => {
  res.json([
    { id: 'whatsapp', name: 'WhatsApp' },
    { id: 'telegram', name: 'Telegram' },
    { id: 'other', name: 'Другой' },
  ]);
});

router.post('/generate-address/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  db.get('SELECT wallet_index FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (row) {
      db.get('SELECT address FROM users WHERE telegram_id = ?', [telegram_id], (err, row) => {
        res.json({ address: row.address });
      });
    } else {
      const index = Math.floor(Math.random() * 1000000);
      const address = await generateAddress(index);
      db.run(
        'INSERT INTO users (telegram_id, wallet_index, address, balance) VALUES (?, ?, ?, ?)',
        [telegram_id, index, address, 0],
        () => res.json({ address })
      );
    }
  });
});

router.get('/balance/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  db.get('SELECT address FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row) {
      return res.json({ balance: 0, address: '' });
    }
    const balance = await getBalance(row.address);
    db.run('UPDATE users SET balance = ? WHERE telegram_id = ?', [balance, telegram_id]);
    res.json({ balance, address: row.address });
  });
});

router.post('/buy', async (req, res) => {
  const { telegram_id, country, resource } = req.body;
  db.get('SELECT balance FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row || row.balance < 0.0001) {
      return res.json({ success: false });
    }
    // Mock SMS code (replace with SMS-Activate API)
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    db.run(
      'INSERT INTO purchases (telegram_id, country, resource, code) VALUES (?, ?, ?, ?)',
      [telegram_id, country, resource, code]
    );
    db.run(
      'UPDATE users SET balance = balance - 0.0001 WHERE telegram_id = ?',
      [telegram_id]
    );
    res.json({ success: true, code });
  });
});

module.exports = router;




.env:
SEED_PHRASE=your_secure_seed_phrase_here





server.json:
{
  "name": "simcard-mini-app-server",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "bip39": "^3.1.0",
    "bitcoinjs-lib": "^6.1.5",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "sqlite3": "^5.1.7"
  }
}









