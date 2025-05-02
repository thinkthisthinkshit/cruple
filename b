db.js:
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  telegram_id: { type: String, required: true, unique: true },
  wallet_index: { type: Number, required: true },
  addresses: { type: Map, of: String, default: {} },
  balance: { type: Number, default: 0 },
  crypto: { type: String, default: 'BTC' },
  language: { type: String, default: 'ru' },
  display_currency: { type: String, default: 'RUB' },
  last_selected_resource: { type: String, default: 'other' },
});

const purchaseSchema = new mongoose.Schema({
  telegram_id: { type: String, required: true },
  country: { type: String, required: true },
  resource: { type: String, required: true },
  code: { type: String },
  number: { type: String },
  price: { type: String },
  service_type: { type: String, required: true },
  status: { type: String, default: 'active' },
  created_at: { type: Date, default: Date.now },
});

const transactionSchema = new mongoose.Schema({
  telegram_id: { type: String, required: true },
  crypto: { type: String, required: true },
  address: { type: String, required: true },
  amount: { type: Number, required: true },
  txid: { type: String, required: true },
  status: { type: String, default: 'pending' }, // pending, confirmed, failed
  created_at: { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);
const Purchase = mongoose.model('Purchase', purchaseSchema);
const Transaction = mongoose.model('Transaction', transactionSchema);

async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 10000,
    });
    console.log('MongoDB connected');
  } catch (err) {
    console.error('MongoDB connection error:', err.message);
    process.exit(1);
  }
}

module.exports = { connectDB, mongoose, User, Purchase, Transaction };








wallet.js:
const { BIP32Factory } = require('bip32');
const ecc = require('@bitcoin-js/tiny-secp256k1-asmjs');
const bitcoin = require('bitcoinjs-lib');
const { mnemonicToSeedSync } = require('bip39');
const { ethers } = require('ethers');

const bip32 = BIP32Factory(ecc);

// Поддерживаемые криптовалюты и их пути деривации (BIP-44)
const COIN_TYPES = {
  BTC: 0,
  ETH: 60,
  USDT: 60, // USDT на Ethereum
  LTC: 2,
  BNB: 60, // BNB на Binance Smart Chain
  AVAX: 60, // AVAX на Avalanche C-Chain
  ADA: 1815,
  SOL: 501,
};

// Функция для генерации адреса
async function generateAddress(telegram_id, crypto) {
  try {
    const seed = mnemonicToSeedSync(process.env.SEED_PHRASE);
    const root = bip32.fromSeed(seed);
    const coinType = COIN_TYPES[crypto] || 0;
    const walletIndex = parseInt(telegram_id, 10) % 1000000; // Уникальный индекс на основе telegram_id
    const path = `m/44'/${coinType}'/0'/0/${walletIndex}`;

    if (crypto === 'BTC') {
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2wpkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin,
      });
      console.log(`Generated BTC address for ${telegram_id}: ${address}`);
      return address;
    } else if (crypto === 'ETH' || crypto === 'USDT' || crypto === 'BNB' || crypto === 'AVAX') {
      const child = root.derivePath(path);
      const wallet = new ethers.Wallet(child.privateKey);
      const address = wallet.address;
      console.log(`Generated ${crypto} address for ${telegram_id}: ${address}`);
      return address;
    } else if (crypto === 'LTC') {
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2wpkh({
        pubkey: child.publicKey,
        network: {
          messagePrefix: '\x19Litecoin Signed Message:\n',
          bech32: 'ltc',
          bip32: { public: 0x019da462, private: 0x019d9cfe },
          pubKeyHash: 0x30,
          scriptHash: 0x32,
          wif: 0xb0,
        },
      });
      console.log(`Generated LTC address for ${telegram_id}: ${address}`);
      return address;
    } else if (crypto === 'ADA' || crypto === 'SOL') {
      console.warn(`Address generation for ${crypto} not fully implemented`);
      return `mock-${crypto}-address-${telegram_id}`;
    } else {
      throw new Error(`Unsupported cryptocurrency: ${crypto}`);
    }
  } catch (err) {
    console.error(`Generate address error for ${crypto}:`, err.message);
    throw err;
  }
}

// Функция для получения баланса (заглушка)
async function getBalance(address) {
  console.log(`Fetching balance for address: ${address}`);
  return 0; // Заменить на реальный вызов API
}

module.exports = { generateAddress, getBalance };









routes.js:
const express = require('express');
const { User, Purchase, Transaction } = require('./db');
const { generateAddress, getBalance } = require('./wallet');
const axios = require('axios');

const router = express.Router();

const SUPPORTED_CRYPTOS = ['BTC', 'USDT', 'LTC', 'ETH', 'BNB', 'AVAX', 'ADA', 'SOL'];

let ratesCache = {
  timestamp: 0,
  rates: {
    btc: { usd: 0, rub: 0 },
    usdt: { usd: 0, rub: 0 },
    ltc: { usd: 0, rub: 0 },
    eth: { usd: 0, rub: 0 },
    bnb: { usd: 0, rub: 0 },
    avax: { usd: 0, rub: 0 },
    ada: { usd: 0, rub: 0 },
    sol: { usd: 0, rub: 0 },
  },
};

const fetchCryptoRates = async () => {
  const start = Date.now();
  const now = Date.now();
  if (now - ratesCache.timestamp < 3600000) {
    console.log('Using cached rates, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  }
  try {
    const res = await axios.get(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,tether,litecoin,ethereum,binancecoin,avalanche-2,cardano,solana&vs_currencies=usd,rub'
    );
    ratesCache = {
      timestamp: now,
      rates: {
        btc: res.data.bitcoin,
        usdt: res.data.tether,
        ltc: res.data.litecoin,
        eth: res.data.ethereum,
        bnb: res.data['binancecoin'],
        avax: res.data['avalanche-2'],
        ada: res.data.cardano,
        sol: res.data.solana,
      },
    };
    console.log('Fetched rates from CoinGecko, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  } catch (err) {
    console.error('Fetch crypto rates error:', err.message);
    console.log('Fetch rates failed, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  }
};

router.post('/generate-address/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  try {
    if (!crypto || !SUPPORTED_CRYPTOS.includes(crypto)) {
      res.status(400).json({ error: `Invalid cryptocurrency: ${crypto || 'undefined'}` });
      console.log('Invalid crypto error, time:', Date.now() - start, 'ms');
      return;
    }
    let user = await User.findOne({ telegram_id });
    let addresses = user?.addresses || {};
    const rates = await fetchCryptoRates();
    const rate = rates[crypto.toLowerCase()]?.[user?.display_currency.toLowerCase() || 'rub'] || 0;

    if (!user || !addresses[crypto]) {
      const address = await generateAddress(telegram_id, crypto);
      addresses[crypto] = address;
      if (!user) {
        user = await User.create({
          telegram_id,
          wallet_index: parseInt(telegram_id, 10) % 1000000,
          addresses: { [crypto]: address },
          balance: 0,
          crypto,
          language: 'ru',
          display_currency: 'RUB',
          last_selected_resource: 'other',
        });
      } else {
        user.addresses = addresses;
        user.crypto = crypto;
        await user.save();
      }
      res.json({ address, rate });
      console.log('New address generated:', { address, crypto, rate });
    } else {
      res.json({ address: addresses[crypto], rate });
      console.log('Returning cached address:', { address: addresses[crypto], crypto, rate });
    }
    console.log('Generate address completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Generate address error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Generate address failed, time:', Date.now() - start, 'ms');
  }
});

router.get('/balance/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.query;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user) {
      res.json({
        balance: '0.00000000',
        address: '',
        crypto: crypto || 'BTC',
        display_balance: '0.00',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
      console.log('Balance fetched (no user), time:', Date.now() - start, 'ms');
      return;
    }
    const addresses = user.addresses || {};
    const address = addresses[crypto || user.crypto] || '';
    const balance = user.balance || 0;
    const rates = await fetchCryptoRates();
    const rate = rates[crypto?.toLowerCase() || user.crypto?.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
    const display_balance = (balance * rate).toFixed(2);
    res.json({
      balance: balance.toFixed(8),
      address,
      crypto: crypto || user.crypto || 'BTC',
      display_balance,
      display_currency: user.display_currency,
      language: user.language,
      last_selected_resource: user.last_selected_resource,
    });
    console.log('Balance fetched, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Fetch balance error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Balance fetch failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/set-language/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { language } = req.body;
  try {
    let user = await User.findOne({ telegram_id });
    const display_currency = language === 'ru' ? 'RUB' : 'USD';
    if (!user) {
      user = await User.create({
        telegram_id,
        wallet_index: parseInt(telegram_id, 10) % 1000000,
        addresses: {},
        balance: 0,
        crypto: 'BTC',
        language,
        display_currency,
        last_selected_resource: 'other',
      });
    } else {
      user.language = language;
      user.display_currency = display_currency;
      await user.save();
    }
    res.json({ success: true, language, display_currency });
    console.log('Set language completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Set language error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Set language failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/set-currency/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { currency } = req.body;
  try {
    if (!['RUB', 'USD'].includes(currency)) {
      res.status(400).json({ error: `Invalid currency: ${currency}` });
      console.log('Set currency failed (invalid currency), time:', Date.now() - start, 'ms');
      return;
    }
    let user = await User.findOne({ telegram_id });
    if (!user) {
      user = await User.create({
        telegram_id,
        wallet_index: parseInt(telegram_id, 10) % 1000000,
        addresses: {},
        balance: 0,
        crypto: 'BTC',
        language: 'ru',
        display_currency: currency,
        last_selected_resource: 'other',
      });
    } else {
      user.display_currency = currency;
      await user.save();
    }
    res.json({ success: true, display_currency: currency });
    console.log('Set currency completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Set currency error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Set currency failed, time:', Date.now() - start, 'ms');
  }
});

router.get('/check-transaction/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.query;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user || !user.addresses[crypto]) {
      res.json({ status: 'No address found' });
      console.log('Check transaction failed (no address), time:', Date.now() - start, 'ms');
      return;
    }
    if (crypto === 'BTC') {
      const address = user.addresses[crypto];
      try {
        const response = await axios.get(`https://blockchain.info/rawaddr/${address}`);
        const transactions = response.data.txs || [];
        for (const tx of transactions) {
          let amount = 0;
          for (const output of tx.out) {
            if (output.addr === address) {
              amount += output.value / 100000000; // Конвертация из сатоши в BTC
            }
          }
          if (amount > 0) {
            const existingTx = await Transaction.findOne({ txid: tx.hash });
            if (!existingTx) {
              await Transaction.create({
                telegram_id,
                crypto,
                address,
                amount,
                txid: tx.hash,
                status: tx.block_height ? 'confirmed' : 'pending',
              });
              user.balance = (user.balance || 0) + amount;
              await user.save();
              console.log(`New transaction recorded: ${tx.hash}, amount: ${amount} ${crypto}`);
            }
          }
        }
        const pendingTxs = await Transaction.find({ telegram_id, crypto, status: 'pending' });
        const confirmedTxs = await Transaction.find({ telegram_id, crypto, status: 'confirmed' });
        res.json({
          status: pendingTxs.length > 0 ? 'Pending transactions found' : 'No pending transactions',
          transactions: [...pendingTxs, ...confirmedTxs].map(tx => ({
            txid: tx.txid,
            amount: tx.amount,
            status: tx.status,
            created_at: tx.created_at,
          })),
        });
      } catch (apiErr) {
        console.error('Blockchain API error:', apiErr.message);
        res.json({ status: 'Error checking transactions' });
      }
    } else {
      res.json({ status: `Transaction check not implemented for ${crypto}` });
    }
    console.log('Check transaction completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Check transaction error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Check transaction failed, time:', Date.now() - start, 'ms');
  }
});

// Другие маршруты (countries, resources, buy, buy-number, purchases, complete-purchase)
// остаются без изменений из предыдущей версии

module.exports = router;








BalanceModal.js:
import { useState, useEffect } from 'react';
import axios from 'axios';
import { QRCodeCanvas } from 'qrcode.react';
import { useTelegram } from '../telegram';

function BalanceModal({ balance, displayCurrency, onClose, language }) {
  const { tg, user } = useTelegram();
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [address, setAddress] = useState('');
  const [transactionStatus, setTransactionStatus] = useState('');
  const [transactions, setTransactions] = useState([]);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  const cryptos = ['BTC', 'USDT', 'LTC', 'ETH', 'BNB', 'AVAX', 'ADA', 'SOL'];

  useEffect(() => {
    if (user?.id) {
      fetchAddress();
      checkTransaction();
    }
  }, [selectedCrypto, user]);

  const fetchAddress = async () => {
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
      console.log('Generate address response:', res.data);
      setAddress(res.data.address);
    } catch (err) {
      console.error('Fetch address error:', err.response?.data || err.message);
      setAddress('');
    }
  };

  const checkTransaction = async () => {
    try {
      const res = await axios.get(`${API_URL}/check-transaction/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setTransactionStatus(res.data.status || 'No transactions found');
      setTransactions(res.data.transactions || []);
    } catch (err) {
      console.error('Check transaction error:', err.response?.data || err.message);
      setTransactionStatus('Error checking transaction');
    }
  };

  const copyAddress = () => {
    navigator.clipboard.writeText(address);
    tg?.showAlert(language === 'ru' ? 'Адрес скопирован!' : 'Address copied!');
  };

  const texts = {
    ru: {
      title: 'Пополнить баланс',
      selectCrypto: 'Выберите криптовалюту',
      address: 'Адрес для пополнения',
      copy: 'Скопировать адрес',
      check: 'Проверить транзакцию',
      close: 'Закрыть',
      transactions: 'Транзакции',
      amount: 'Сумма',
      status: 'Статус',
      date: 'Дата',
    },
    en: {
      title: 'Top Up Balance',
      selectCrypto: 'Select Cryptocurrency',
      address: 'Deposit Address',
      copy: 'Copy Address',
      check: 'Check Transaction',
      close: 'Close',
      transactions: 'Transactions',
      amount: 'Amount',
      status: 'Status',
      date: 'Date',
    },
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-4 rounded-lg max-w-sm w-full">
        <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
        <p className="mb-2">{texts[language].selectCrypto}:</p>
        <select
          className="w-full bg-gray-200 p-2 rounded mb-4"
          value={selectedCrypto}
          onChange={(e) => setSelectedCrypto(e.target.value)}
        >
          {cryptos.map((crypto) => (
            <option key={crypto} value={crypto}>
              {crypto}
            </option>
          ))}
        </select>
        {address ? (
          <div className="text-center">
            <p className="mb-2">{texts[language].address}:</p>
            <p className="text-sm break-all mb-4">{address}</p>
            <div className="flex justify-center mb-4">
              <QRCodeCanvas value={address} size={128} />
            </div>
            <button
              className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
              onClick={copyAddress}
            >
              {texts[language].copy}
            </button>
            <button
              className="w-full bg-gray-500 text-white px-4 py-2 rounded mb-2"
              onClick={checkTransaction}
            >
              {texts[language].check}
            </button>
          </div>
        ) : (
          <p className="text-center mb-4">
            {language === 'ru' ? 'Загрузка адреса...' : 'Loading address...'}
          </p>
        )}
        <p className="text-center mb-4">
          {language === 'ru' ? 'Баланс' : 'Balance'}: {balance} {displayCurrency}
        </p>
        <p className="text-center mb-4">{transactionStatus}</p>
        {transactions.length > 0 && (
          <div className="mb-4">
            <h3 className="text-lg font-semibold">{texts[language].transactions}</h3>
            <ul className="text-sm">
              {transactions.map((tx) => (
                <li key={tx.txid} className="mb-2">
                  <p>
                    {texts[language].amount}: {tx.amount} {selectedCrypto}
                  </p>
                  <p>
                    {texts[language].status}: {tx.status}
                  </p>
                  <p>
                    {texts[language].date}: {new Date(tx.created_at).toLocaleString()}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        )}
        <button
          className="w-full bg-red-500 text-white px-4 py-2 rounded"
          onClick={onClose}
        >
          {texts[language].close}
        </button>
      </div>
    </div>
  );
}

export default BalanceModal;








Setting.js:
import { useEffect } from 'react';
import { useTelegram } from '../telegram';

function Settings({ language, onBack, onSelectLanguage, onSelectCurrency }) {
  const { tg } = useTelegram();

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const texts = {
    ru: {
      title: 'Настройки',
      languageLabel: 'Язык',
      currencyLabel: 'Валюта',
    },
    en: {
      title: 'Settings',
      languageLabel: 'Language',
      currencyLabel: 'Currency',
    },
  };

  const languages = [
    { id: 'ru', name: 'Русский' },
    { id: 'en', name: 'English' },
  ];

  const currencies = [
    { id: 'RUB', name: 'RUB' },
    { id: 'USD', name: 'USD' },
  ];

  const handleLanguageChange = (e) => {
    onSelectLanguage(e.target.value);
  };

  const handleCurrencyChange = (e) => {
    onSelectCurrency(e.target.value);
  };

  return (
    <div className="p-4 max-w-md mx-auto pb-16">
      <h1 className="text-2xl font-bold mb-4">{texts[language].title}</h1>
      <div className="flex flex-col gap-4">
        <div>
          <label className="block text-lg font-semibold mb-2">
            {texts[language].languageLabel}
          </label>
          <select
            className="w-full bg-gray-200 p-2 rounded"
            value={language}
            onChange={handleLanguageChange}
          >
            {languages.map((lang) => (
              <option key={lang.id} value={lang.id}>
                {lang.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-lg font-semibold mb-2">
            {texts[language].currencyLabel}
          </label>
          <select
            className="w-full bg-gray-200 p-2 rounded"
            value={language === 'ru' ? 'RUB' : 'USD'}
            onChange={handleCurrencyChange}
          >
            {currencies.map((currency) => (
              <option key={currency.id} value={currency.id}>
                {currency.name}
              </option>
            ))}
          </select>
        </div>
      </div>
    </div>
  );
}

export default Settings;









