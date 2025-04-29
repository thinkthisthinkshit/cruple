server/src/db.js:
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database(':memory:');

db.serialize(() => {
  db.run(`
    CREATE TABLE users (
      telegram_id TEXT PRIMARY KEY,
      wallet_index INTEGER,
      address TEXT,
      addresses TEXT,
      balance REAL,
      crypto TEXT
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





server/src/wallet.js:
const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const { ethers } = require('ethers');
const TonWeb = require('tonweb');
require('dotenv').config();

const SEED_PHRASE = process.env.SEED_PHRASE;

if (!SEED_PHRASE) {
  throw new Error('SEED_PHRASE not set in .env');
}

const getDerivationPath = (coinType, userIndex) => {
  return `m/44'/${coinType}'/0'/0/${userIndex}`;
};

const cryptoCoinTypes = {
  BTC: 0,
  ETH: 60,
  USDT: 60, // USDT на Ethereum
  BNB: 60, // BNB на BSC
  ADA: 1815, // Cardano
  SOL: 501, // Solana
  XRP: 144,
  DOT: 354,
  LTC: 2,
  XMR: 128, // Monero (упрощённо)
  TRX: 195,
  AVAX: 60, // Avalanche C-Chain
  ATOM: 118,
  XTZ: 1729,
  ALGO: 283,
  NOT: 607, // Notcoin на TON
  HMSTR: 607, // Hamster Kombat на TON
};

const generateAddress = async (telegram_id, crypto) => {
  const userIndex = parseInt(telegram_id, 10) % 1000000; // Уникальный индекс из telegram_id
  const seed = await bip39.mnemonicToSeed(SEED_PHRASE);

  if (['BTC', 'LTC'].includes(crypto)) {
    const network = crypto === 'BTC' ? bitcoin.networks.bitcoin : bitcoin.networks.litecoin;
    const root = bitcoin.bip32.fromSeed(seed, network);
    const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
    const child = root.derivePath(path);
    const { address } = bitcoin.payments.p2pkh({ pubkey: child.publicKey, network });
    return address;
  } else if (['ETH', 'USDT', 'BNB', 'AVAX'].includes(crypto)) {
    const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
    const wallet = ethers.Wallet.fromMnemonic(SEED_PHRASE, path);
    return wallet.address;
  } else if (['NOT', 'HMSTR'].includes(crypto)) {
    const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
    const wallet = ethers.Wallet.fromMnemonic(SEED_PHRASE, path);
    const keyPair = TonWeb.utils.nacl.sign.keyPair.fromSeed(wallet.signingKey.privateKey.slice(0, 32));
    const tonWallet = new TonWeb.Wallets.WalletV4({ publicKey: keyPair.publicKey });
    const { address } = await tonWallet.getAddress();
    return address.toString(true, true, true); // Формат TON-адреса (user-friendly)
  } else {
    // Заглушка для других криптовалют (ADA, SOL, XRP, DOT, XMR, TRX, ATOM, XTZ, ALGO)
    return `PlaceholderAddress_${crypto}_${telegram_id}`;
  }
};

const getBalance = async (address) => {
  // Заглушка: реальный баланс требует API нод
  return 0;
};

module.exports = { generateAddress, getBalance };





server/src/routes.js:
const express = require('express');
const db = require('./db');
const { generateAddress, getBalance } = require('./wallet');

const router = express.Router();

router.get('/countries', (req, res) => {
  const countries = [
    { id: 'us', name_en: 'United States', name_ru: 'США' },
    { id: 'ru', name_en: 'Russia', name_ru: 'Россия' },
    { id: 'uk', name_en: 'United Kingdom', name_ru: 'Великобритания' },
    { id: 'fr', name_en: 'France', name_ru: 'Франция' },
    { id: 'de', name_en: 'Germany', name_ru: 'Германия' },
    { id: 'it', name_en: 'Italy', name_ru: 'Италия' },
    { id: 'es', name_en: 'Spain', name_ru: 'Испания' },
    { id: 'cn', name_en: 'China', name_ru: 'Китай' },
    { id: 'jp', name_en: 'Japan', name_ru: 'Япония' },
    { id: 'in', name_en: 'India', name_ru: 'Индия' },
    { id: 'br', name_en: 'Brazil', name_ru: 'Бразилия' },
    { id: 'ca', name_en: 'Canada', name_ru: 'Канада' },
    { id: 'au', name_en: 'Australia', name_ru: 'Австралия' },
    { id: 'za', name_en: 'South Africa', name_ru: 'Южная Африка' },
    { id: 'mx', name_en: 'Mexico', name_ru: 'Мексика' },
    { id: 'ar', name_en: 'Argentina', name_ru: 'Аргентина' },
    { id: 'cl', name_en: 'Chile', name_ru: 'Чили' },
    { id: 'co', name_en: 'Colombia', name_ru: 'Колумбия' },
    { id: 'pe', name_en: 'Peru', name_ru: 'Перу' },
    { id: 've', name_en: 'Venezuela', name_ru: 'Венесуэла' },
    { id: 'eg', name_en: 'Egypt', name_ru: 'Египет' },
    { id: 'ng', name_en: 'Nigeria', name_ru: 'Нигерия' },
    { id: 'ke', name_en: 'Kenya', name_ru: 'Кения' },
    { id: 'gh', name_en: 'Ghana', name_ru: 'Гана' },
    { id: 'dz', name_en: 'Algeria', name_ru: 'Алжир' },
    { id: 'ma', name_en: 'Morocco', name_ru: 'Марокко' },
    { id: 'sa', name_en: 'Saudi Arabia', name_ru: 'Саудовская Аравия' },
    { id: 'ae', name_en: 'United Arab Emirates', name_ru: 'ОАЭ' },
    { id: 'tr', name_en: 'Turkey', name_ru: 'Турция' },
    { id: 'pl', name_en: 'Poland', name_ru: 'Польша' },
    { id: 'ua', name_en: 'Ukraine', name_ru: 'Украина' },
    { id: 'by', name_en: 'Belarus', name_ru: 'Беларусь' },
    { id: 'kz', name_en: 'Kazakhstan', name_ru: 'Казахстан' },
    { id: 'uz', name_en: 'Uzbekistan', name_ru: 'Узбекистан' },
    { id: 'ge', name_en: 'Georgia', name_ru: 'Грузия' },
    { id: 'am', name_en: 'Armenia', name_ru: 'Армения' },
    { id: 'az', name_en: 'Azerbaijan', name_ru: 'Азербайджан' },
    { id: 'id', name_en: 'Indonesia', name_ru: 'Индонезия' },
    { id: 'th', name_en: 'Thailand', name_ru: 'Таиланд' },
    { id: 'vn', name_en: 'Vietnam', name_ru: 'Вьетнам' },
    { id: 'ph', name_en: 'Philippines', name_ru: 'Филиппины' },
    { id: 'my', name_en: 'Malaysia', name_ru: 'Малайзия' },
    { id: 'sg', name_en: 'Singapore', name_ru: 'Сингапур' },
    { id: 'kr', name_en: 'South Korea', name_ru: 'Южная Корея' },
    { id: 'pk', name_en: 'Pakistan', name_ru: 'Пакистан' },
    { id: 'bd', name_en: 'Bangladesh', name_ru: 'Бангладеш' },
    { id: 'lk', name_en: 'Sri Lanka', name_ru: 'Шри-Ланка' },
    { id: 'np', name_en: 'Nepal', name_ru: 'Непал' },
    { id: 'mm', name_en: 'Myanmar', name_ru: 'Мьянма' },
    { id: 'kh', name_en: 'Cambodia', name_ru: 'Камбоджа' },
    { id: 'la', name_en: 'Laos', name_ru: 'Лаос' },
    { id: 'se', name_en: 'Sweden', name_ru: 'Швеция' },
    { id: 'no', name_en: 'Norway', name_ru: 'Норвегия' },
    { id: 'fi', name_en: 'Finland', name_ru: 'Финляндия' },
    { id: 'dk', name_en: 'Denmark', name_ru: 'Дания' },
    { id: 'nl', name_en: 'Netherlands', name_ru: 'Нидерланды' },
    { id: 'be', name_en: 'Belgium', name_ru: 'Бельгия' },
    { id: 'at', name_en: 'Austria', name_ru: 'Австрия' },
    { id: 'ch', name_en: 'Switzerland', name_ru: 'Швейцария' },
    { id: 'gr', name_en: 'Greece', name_ru: 'Греция' },
    { id: 'pt', name_en: 'Portugal', name_ru: 'Португалия' },
    { id: 'ie', name_en: 'Ireland', name_ru: 'Ирландия' },
    { id: 'cz', name_en: 'Czech Republic', name_ru: 'Чехия' },
    { id: 'sk', name_en: 'Slovakia', name_ru: 'Словакия' },
    { id: 'hu', name_en: 'Hungary', name_ru: 'Венгрия' },
    { id: 'ro', name_en: 'Romania', name_ru: 'Румыния' },
    { id: 'bg', name_en: 'Bulgaria', name_ru: 'Болгария' },
    { id: 'hr', name_en: 'Croatia', name_ru: 'Хорватия' },
    { id: 'rs', name_en: 'Serbia', name_ru: 'Сербия' },
    { id: 'ba', name_en: 'Bosnia and Herzegovina', name_ru: 'Босния и Герцеговина' },
  ];
  res.json(countries);
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
  const { crypto } = req.body;
  db.get('SELECT addresses, wallet_index FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'DB error' });
    }
    let addresses = row?.addresses ? JSON.parse(row.addresses) : {};
    if (row && addresses[crypto]) {
      return res.json({ address: addresses[crypto] });
    }
    const address = await generateAddress(telegram_id, crypto);
    addresses[crypto] = address;
    if (row) {
      db.run(
        'UPDATE users SET addresses = ? WHERE telegram_id = ?',
        [JSON.stringify(addresses), telegram_id],
        (err) => {
          if (err) return res.status(500).json({ error: 'DB error' });
          res.json({ address });
        }
      );
    } else {
      const index = Math.floor(Math.random() * 1000000);
      db.run(
        'INSERT INTO users (telegram_id, wallet_index, address, addresses, balance, crypto) VALUES (?, ?, ?, ?, ?, ?)',
        [telegram_id, index, address, JSON.stringify({ [crypto]: address }), 0, crypto],
        (err) => {
          if (err) return res.status(500).json({ error: 'DB error' });
          res.json({ address });
        }
      );
    }
  });
});

router.get('/balance/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  db.get('SELECT addresses, crypto FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row) {
      return res.json({ balance: 0, address: '', crypto: 'BTC' });
    }
    const addresses = row.addresses ? JSON.parse(row.addresses) : {};
    const address = addresses[row.crypto] || '';
    const balance = await getBalance(address);
    db.run('UPDATE users SET balance = ? WHERE telegram_id = ?', [balance, telegram_id]);
    res.json({ balance, address, crypto: row.crypto });
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

router.post('/buy-number', async (req, res) => {
  const { telegram_id, country, service } = req.body;
  db.get('SELECT balance FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row || row.balance < 0.0001) {
      return res.json({ success: false, error: 'Недостаточно средств' });
    }
    const number = `+${Math.floor(10000000000 + Math.random() * 90000000000)}`;
    const code = service === 'sms' ? `CODE-${Math.random().toString(36).slice(2, 8)}` : null;
    const last4 = service === 'call' ? number.slice(-4) : null;
    const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const price = service === 'sms' ? '0.012 €' : service === 'call' ? '0.020 €' : '5$ в месяц';
    db.run(
      'INSERT INTO purchases (telegram_id, country, resource, code) VALUES (?, ?, ?, ?)',
      [telegram_id, country, service, code || number]
    );
    db.run(
      'UPDATE users SET balance = balance - 0.0001 WHERE telegram_id = ?',
      [telegram_id]
    );
    res.json({
      success: true,
      number,
      code,
      last4,
      expiry,
      price,
    });
  });
});

module.exports = router;




client/src/components/Profile.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const { tg } = useTelegram();
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);
  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositAddress, setDepositAddress] = useState('');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin' },
    { id: 'ETH', name: 'Ethereum' },
    { id: 'USDT', name: 'Tether' },
    { id: 'BNB', name: 'Binance Coin' },
    { id: 'ADA', name: 'Cardano' },
    { id: 'SOL', name: 'Solana' },
    { id: 'XRP', name: 'Ripple' },
    { id: 'DOT', name: 'Polkadot' },
    { id: 'LTC', name: 'Litecoin' },
    { id: 'XMR', name: 'Monero' },
    { id: 'TRX', name: 'Tron' },
    { id: 'AVAX', name: 'Avalanche' },
    { id: 'ATOM', name: 'Cosmos' },
    { id: 'XTZ', name: 'Tezos' },
    { id: 'ALGO', name: 'Algorand' },
    { id: 'NOT', name: 'Notcoin' },
    { id: 'HMSTR', name: 'Hamster Kombat' },
  ];

  const toggleCryptoDropdown = () => {
    setShowCryptoDropdown(!showCryptoDropdown);
  };

  const handleDeposit = async () => {
    try {
      const res = await axios.post(
        `${API_URL}/generate-address/${tg.user?.id}`,
        { crypto: selectedCrypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setDepositAddress(res.data.address);
      setShowDepositModal(true);
    } catch (err) {
      console.error('Generate address error:', err);
      tg?.showPopup({ message: `Ошибка генерации адреса: ${err.message}` });
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(depositAddress);
    tg?.showPopup({ message: 'Адрес скопирован!' });
  };

  const selectedCryptoData = cryptos.find((c) => c.id === selectedCrypto);

  return (
    <div className="p-4 max-w-md mx-auto">
      <div className="flex justify-center items-center mb-4 gap-2">
        <div className="relative max-w-xs w-full">
          <button
            className="w-full bg-gray-200 bg-opacity-50 text-gray-800 border border-gray-600 border-opacity-50 px-4 py-2 rounded flex justify-between items-center"
            onClick={toggleCryptoDropdown}
          >
            <span>{selectedCryptoData ? selectedCryptoData.name : 'Select Crypto'}</span>
            <svg
              className={`w-4 h-4 transform ${showCryptoDropdown ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          {showCryptoDropdown && (
            <div className="absolute z-10 w-full bg-white border border-gray-300 rounded shadow-lg mt-1 max-h-64 overflow-y-auto">
              {cryptos.map((crypto) => (
                <button
                  key={crypto.id}
                  className="w-full text-left px-4 py-2 hover:bg-gray-100"
                  onClick={() => {
                    setSelectedCrypto(crypto.id);
                    setShowCryptoDropdown(false);
                  }}
                >
                  {crypto.name}
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded"
          onClick={handleDeposit}
        >
          Пополнить
        </button>
      </div>
      <h1 className="text-2xl font-bold text-center mb-4">{username}</h1>
      {showDepositModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
          onClick={() => setShowDepositModal(false)}
        >
          <div
            className="bg-white p-4 rounded-lg max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold mb-4">
              {cryptos.find((c) => c.id === selectedCrypto)?.name || 'Crypto'} Адрес
            </h2>
            <div className="flex items-center">
              <p className="text-gray-600 break-all flex-1">{depositAddress}</p>
              <button
                className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                onClick={copyToClipboard}
              >
                Копировать
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Profile;








