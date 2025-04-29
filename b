telegram.js:
import { useEffect } from 'react';

export const useTelegram = () => {
  const tg = window.Telegram?.WebApp;

  useEffect(() => {
    if (tg) {
      tg.ready();
      console.log('Telegram WebApp initialized:', tg.initDataUnsafe);
    }
  }, []);

  return {
    tg,
    user: tg?.initDataUnsafe?.user, // Возвращаем user из initDataUnsafe
  };
};





Profile.js:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const { tg, user } = useTelegram();
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);
  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositAddress, setDepositAddress] = useState('');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    console.log('Profile user:', user); // Отладка
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
    if (!user?.id) {
      console.error('Telegram user ID is undefined');
      tg?.showPopup({ message: 'Ошибка: Telegram ID не определён' });
      return;
    }
    console.log('Sending request for telegram_id:', user.id, 'crypto:', selectedCrypto);
    try {
      const res = await axios.post(
        `${API_URL}/generate-address/${user.id}`,
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







App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import axios from 'axios';
import Profile from './components/Profile';

function App() {
  const { tg, user } = useTelegram();
  const [username, setUsername] = useState('');
  const [balance, setBalance] = useState(0);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [currentPage, setCurrentPage] = useState('home');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    console.log('App user:', user); // Отладка
    if (user?.id) {
      setUsername(user.first_name || user.username || 'User');
      fetchBalance(user.id);
    } else {
      console.error('User ID is undefined');
    }
  }, [user]);

  const fetchBalance = async (telegram_id) => {
    try {
      const res = await axios.get(`${API_URL}/balance/${telegram_id}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance);
    } catch (err) {
      console.error('Fetch balance error:', err);
    }
  };

  const handleBack = () => {
    setCurrentPage('home');
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {currentPage === 'home' && (
        <div className="p-4">
          <h1 className="text-2xl font-bold">Welcome, {username}</h1>
          <p>Balance: {balance}</p>
          <button
            className="mt-4 bg-blue-500 text-white px-4 py-2 rounded"
            onClick={() => setCurrentPage('profile')}
          >
            Go to Profile
          </button>
        </div>
      )}
      {currentPage === 'profile' && (
        <Profile
          username={username}
          selectedCrypto={selectedCrypto}
          setSelectedCrypto={setSelectedCrypto}
          balance={balance}
          onBack={handleBack}
        />
      )}
    </div>
  );
}

export default App;







server.js:
const express = require('express');
const cors = require('cors');
const routes = require('./src/routes');
const axios = require('axios');
require('dotenv').config();

const app = express();

app.use(cors({ origin: '*' }));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.headers['user-agent']}`);
  next();
});
app.use('/', routes);

const BOT_TOKEN = process.env.BOT_TOKEN;
const WEB_APP_URL = process.env.WEB_APP_URL;

if (!BOT_TOKEN || !WEB_APP_URL) {
  console.error('BOT_TOKEN or WEB_APP_URL not set in .env');
  process.exit(1);
}

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands`, {
  commands: [{ command: '/start', description: 'Открыть SimCard Mini App' }],
}).then(() => {
  console.log('Telegram commands set successfully');
}).catch(err => {
  console.error('Ошибка настройки команд:', err.message);
});

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setChatMenuButton`, {
  menu_button: {
    type: 'web_app',
    text: 'OPEN',
    web_app: { url: WEB_APP_URL },
  },
}).then(() => {
  console.log('Telegram menu button set successfully');
}).catch(err => {
  console.error('Ошибка настройки кнопки:', err.message);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));







index.js:
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);




