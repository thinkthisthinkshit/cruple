const express = require('express');
const cors = require('cors');
const router = require('./src/routes');

const app = express();

app.use(cors({
  origin: '*', // Разрешить все домены (для тестов). В продакшене укажи конкретный Ngrok-домен фронта
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'telegram-init-data', 'ngrok-skip-browser-warning']
}));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.headers['user-agent']}`);
  next();
});
app.use('/', router);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});





wallet.js:
const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const bip32 = require('bip32'); // Новый импорт
const { ethers } = require('ethers');
const TonWeb = require('tonweb');
require('dotenv').config();

const SEED_PHRASE = process.env.SEED_PHRASE;
console.log('SEED_PHRASE:', SEED_PHRASE); // Отладка

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
  try {
    const userIndex = parseInt(telegram_id, 10) % 1000000; // Уникальный индекс из telegram_id
    const seed = await bip39.mnemonicToSeed(SEED_PHRASE);

    if (['BTC', 'LTC'].includes(crypto)) {
      const network = crypto === 'BTC' ? bitcoin.networks.bitcoin : bitcoin.networks.litecoin;
      const root = bip32.fromSeed(seed, network); // Используем bip32 вместо bitcoin.BIP32
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
      // Заглушка для других криптовалют
      return `PlaceholderAddress_${crypto}_${telegram_id}`;
    }
  } catch (error) {
    console.error(`Error generating address for ${crypto}:`, error);
    throw new Error(`Failed to generate address for ${crypto}`);
  }
};

const getBalance = async (address) => {
  // Заглушка: реальный баланс требует API нод
  return 0;
};

module.exports = { generateAddress, getBalance };







Profile.jsx:
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
    if (!tg.user?.id) {
      console.error('Telegram user ID is undefined');
      tg?.showPopup({ message: 'Ошибка: Telegram ID не определён' });
      return;
    }
    console.log('Sending request for telegram_id:', tg.user.id, 'crypto:', selectedCrypto); // Отладка
    try {
      const res = await axios.post(
        `${API_URL}/generate-address/${tg.user.id}`,
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






