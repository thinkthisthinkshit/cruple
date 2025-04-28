App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountrySelector from './components/CountrySelector';
import ResourceSelector from './components/ResourceSelector';
import BalanceModal from './components/BalanceModal';
import Profile from './components/Profile';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [country, setCountry] = useState('');
  const [resource, setResource] = useState('');
  const [balance, setBalance] = useState(null);
  const [address, setAddress] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [showProfile, setShowProfile] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.MainButton.setText('Купить').show().onClick(handleBuy);
      tg.BackButton.onClick(() => setShowProfile(false));
      fetchBalance();
    }
  }, [tg, showProfile]);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user?.id}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance);
      setAddress(res.data.address);
    } catch (err) {
      console.error('Fetch balance error:', err);
      tg?.showPopup({ message: `Ошибка загрузки баланса: ${err.message}` });
    }
  };

  const handleBuy = async () => {
    if (!country || !resource) {
      tg?.showPopup({ message: 'Выберите страну и ресурс' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy`,
        { telegram_id: user?.id, country, resource },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (res.data.success) {
        tg?.showPopup({ message: `Код: ${res.data.code}` });
        fetchBalance();
      } else {
        setShowModal(true);
      }
    } catch (err) {
      console.error('Buy error:', err);
      tg?.showPopup({ message: `Ошибка покупки: ${err.message}` });
    }
  };

  const handleTopUp = async () => {
    try {
      const res = await axios.post(`${API_URL}/generate-address/${user?.id}`, null, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setAddress(res.data.address);
      setShowModal(true);
    } catch (err) {
      console.error('Generate address error:', err);
      tg?.showPopup({ message: `Ошибка генерации адреса: ${err.message}` });
    }
  };

  if (showProfile) {
    return (
      <Profile
        username={user?.username || 'Unknown'}
        selectedCrypto={selectedCrypto}
        setSelectedCrypto={setSelectedCrypto}
        balance={balance}
        onBack={() => setShowProfile(false)}
      />
    );
  }

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">SimCard Mini App</h1>
      <button
        className="mb-4 bg-blue-500 text-white px-4 py-2 rounded"
        onClick={() => setShowProfile(true)}
      >
        Profile
      </button>
      <CountrySelector onSelect={setCountry} />
      <ResourceSelector onSelect={setResource} />
      <div className="mt-4">
        <p className="text-lg">Баланс: {balance !== null ? `${balance} ${selectedCrypto}` : 'Загрузка...'}</p>
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






Profile.jsx:
import { useState } from 'react';
import CryptoModal from './CryptoModal';

const cryptoIcons = {
  BTC: '₿',
  ETH: 'Ξ',
  USDT: '₮',
};

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const [showCryptoModal, setShowCryptoModal] = useState(false);

  return (
    <div className="p-4 max-w-md mx-auto">
      <button
        className="mb-4 bg-gray-500 text-white px-4 py-2 rounded"
        onClick={onBack}
      >
        Назад
      </button>
      <h1 className="text-2xl font-bold mb-4 text-center">Профиль</h1>
      <p className="text-lg mb-4">Пользователь: @{username}</p>
      <button
        className="w-full bg-blue-500 text-white px-4 py-2 rounded flex items-center justify-center"
        onClick={() => setShowCryptoModal(true)}
      >
        <span>
          {balance !== null ? `${balance.toFixed(8)}` : '0.00000000'} {cryptoIcons[selectedCrypto]}
        </span>
      </button>
      {showCryptoModal && (
        <CryptoModal
          onSelect={(crypto) => {
            setSelectedCrypto(crypto);
            setShowCryptoModal(false);
          }}
          onClose={() => setShowCryptoModal(false)}
        />
      )}
    </div>
  );
}

export default Profile;







CryptoModal.jsx:
function CryptoModal({ onSelect, onClose }) {
  const cryptos = [
    { id: 'BTC', name: 'Bitcoin', icon: '₿' },
    { id: 'ETH', name: 'Ethereum', icon: 'Ξ' },
    { id: 'USDT', name: 'Tether', icon: '₮' },
  ];

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-4 rounded-lg max-w-sm w-full">
        <h2 className="text-xl font-bold mb-4">Выберите криптовалюту</h2>
        {cryptos.map((crypto) => (
          <button
            key={crypto.id}
            className="w-full mb-2 bg-gray-200 p-2 rounded flex items-center"
            onClick={() => onSelect(crypto.id)}
          >
            <span className="mr-2">{crypto.icon}</span>
            {crypto.name}
          </button>
        ))}
        <button
          className="w-full bg-red-500 text-white p-2 rounded"
          onClick={onClose}
        >
          Закрыть
        </button>
      </div>
    </div>
  );
}

export default CryptoModal;








db.js:
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('simcard.db');

db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      telegram_id TEXT PRIMARY KEY,
      wallet_index INTEGER,
      address TEXT,
      balance REAL,
      crypto TEXT DEFAULT 'BTC'
    );
  `);
  db.run(`
    CREATE TABLE IF NOT EXISTS purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      telegram_id TEXT,
      country TEXT,
      resource TEXT,
      code TEXT
    );
  `);
});

module.exports = {
  get: (query, params, callback) => db.get(query, params, callback),
  run: (query, params, callback) => db.run(query, params, callback),
};










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
        'INSERT INTO users (telegram_id, wallet_index, address, balance, crypto) VALUES (?, ?, ?, ?, ?)',
        [telegram_id, index, address, 0, 'BTC'],
        () => res.json({ address })
      );
    }
  });
});

router.get('/balance/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  db.get('SELECT address, crypto FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row) {
      return res.json({ balance: 0, address: '', crypto: 'BTC' });
    }
    const balance = await getBalance(row.address);
    db.run('UPDATE users SET balance = ? WHERE telegram_id = ?', [balance, telegram_id]);
    res.json({ balance, address: row.address, crypto: row.crypto });
  });
});

router.post('/buy', async (req, res) => {
  const { telegram_id, country, resource } = req.body;
  db.get('SELECT balance FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row || row.balance < 0.0001) {
      return res.json({ success: false });
    }
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

router.post('/select-crypto/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  db.run(
    'UPDATE users SET crypto = ? WHERE telegram_id = ?',
    [crypto, telegram_id],
    (err) => {
      if (err) return res.status(500).json({ error: 'DB error' });
      res.json({ success: true, crypto });
    }
  );
});

module.exports = router;




app.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountrySelector from './components/CountrySelector';
import ResourceSelector from './components/ResourceSelector';
import BalanceModal from './components/BalanceModal';
import Profile from './components/Profile';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [country, setCountry] = useState('');
  const [resource, setResource] = useState('');
  const [balance, setBalance] = useState(null);
  const [address, setAddress] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [showProfile, setShowProfile] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.MainButton.setText('Купить').show().onClick(handleBuy);
      tg.BackButton.onClick(() => setShowProfile(false));
      fetchBalance();
    }
  }, [tg, showProfile]);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user?.id}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance);
      setAddress(res.data.address);
      setSelectedCrypto(res.data.crypto);
    } catch (err) {
      console.error('Fetch balance error:', err);
      tg?.showPopup({ message: `Ошибка загрузки баланса: ${err.message}` });
    }
  };

  const handleBuy = async () => {
    if (!country || !resource) {
      tg?.showPopup({ message: 'Выберите страну и ресурс' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy`,
        { telegram_id: user?.id, country, resource },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (res.data.success) {
        tg?.showPopup({ message: `Код: ${res.data.code}` });
        fetchBalance();
      } else {
        setShowModal(true);
      }
    } catch (err) {
      console.error('Buy error:', err);
      tg?.showPopup({ message: `Ошибка покупки: ${err.message}` });
    }
  };

  const handleTopUp = async () => {
    try {
      const res = await axios.post(`${API_URL}/generate-address/${user?.id}`, null, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setAddress(res.data.address);
      setShowModal(true);
    } catch (err) {
      console.error('Generate address error:', err);
      tg?.showPopup({ message: `Ошибка генерации адреса: ${err.message}` });
    }
  };

  const handleSelectCrypto = async (crypto) => {
    try {
      await axios.post(
        `${API_URL}/select-crypto/${user?.id}`,
        { crypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setSelectedCrypto(crypto);
    } catch (err) {
      console.error('Select crypto error:', err);
      tg?.showPopup({ message: `Ошибка выбора криптовалюты: ${err.message}` });
    }
  };

  if (showProfile) {
    return (
      <Profile
        username={user?.username || 'Unknown'}
        selectedCrypto={selectedCrypto}
        setSelectedCrypto={handleSelectCrypto}
        balance={balance}
        onBack={() => setShowProfile(false)}
      />
    );
  }

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">SimCard Mini App</h1>
      <button
        className="mb-4 bg-blue-500 text-white px-4 py-2 rounded"
        onClick={() => setShowProfile(true)}
      >
        Profile
      </button>
      <CountrySelector onSelect={setCountry} />
      <ResourceSelector onSelect={setResource} />
      <div className="mt-4">
        <p className="text-lg">Баланс: {balance !== null ? `${balance} ${selectedCrypto}` : 'Загрузка...'}</p>
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








