db.js:
const mongoose = require('mongoose');
require('dotenv').config();

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connected');
  } catch (err) {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  }
};

const userSchema = new mongoose.Schema({
  telegram_id: { type: String, required: true, unique: true },
  wallet_index: Number,
  address: String,
  addresses: Object,
  balance: { type: Number, default: 1.0 },
  crypto: String,
  language: { type: String, default: 'ru' },
  display_currency: { type: String, default: 'RUB' },
  last_selected_resource: { type: String, default: 'other' },
});

const purchaseSchema = new mongoose.Schema({
  telegram_id: String,
  country: String,
  resource: String,
  code: String,
  number: String,
  price: String,
  service_type: { type: String, enum: ['sms', 'call', 'rent'], default: 'sms' },
  status: { type: String, enum: ['active', 'completed'], default: 'active' },
  created_at: { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);
const Purchase = mongoose.model('Purchase', purchaseSchema);

module.exports = { connectDB, User, Purchase };





routes.js:
const express = require('express');
const { User, Purchase } = require('./db');
const { generateAddress, getBalance } = require('./wallet');
const axios = require('axios');

const router = express.Router();

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

const resources = [
  { id: 'other', name_en: 'Other', name_ru: 'Другой' },
  { id: 'whatsapp', name_en: 'WhatsApp', name_ru: 'WhatsApp' },
  { id: 'telegram', name_en: 'Telegram', name_ru: 'Telegram' },
  { id: 'instagram', name_en: 'Instagram', name_ru: 'Instagram' },
  { id: 'facebook', name_en: 'Facebook', name_ru: 'Facebook' },
  { id: 'viber', name_en: 'Viber', name_ru: 'Viber' },
  { id: 'skype', name_en: 'Skype', name_ru: 'Skype' },
  { id: 'wechat', name_en: 'WeChat', name_ru: 'WeChat' },
  { id: 'snapchat', name_en: 'Snapchat', name_ru: 'Snapchat' },
  { id: 'tiktok', name_en: 'TikTok', name_ru: 'TikTok' },
  { id: 'discord', name_en: 'Discord', name_ru: 'Discord' },
  { id: 'twitter', name_en: 'Twitter', name_ru: 'Twitter' },
  { id: 'linkedin', name_en: 'LinkedIn', name_ru: 'LinkedIn' },
  { id: 'vk', name_en: 'VK', name_ru: 'ВКонтакте' },
  { id: 'gmail', name_en: 'Gmail', name_ru: 'Gmail' },
];

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
  const now = Date.now();
  if (now - ratesCache.timestamp < 3600000) {
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
    return ratesCache.rates;
  } catch (err) {
    console.error('Fetch crypto rates error:', err);
    return ratesCache.rates;
  }
};

router.get('/countries', (req, res) => {
  res.json(countries);
});

router.get('/resources', (req, res) => {
  const language = req.query.language || 'ru';
  res.json(
    resources.map((resource) => ({
      id: resource.id,
      name: language === 'ru' ? resource.name_ru : resource.name_en,
    }))
  );
});

router.post('/generate-address/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  try {
    let user = await User.findOne({ telegram_id });
    let addresses = user?.addresses || {};
    if (user && addresses[crypto]) {
      return res.json({ address: addresses[crypto] });
    }
    const address = await generateAddress(telegram_id, crypto);
    addresses[crypto] = address;
    if (user) {
      user.addresses = addresses;
      await user.save();
      res.json({ address });
    } else {
      const index = Math.floor(Math.random() * 1000000);
      await User.create({
        telegram_id,
        wallet_index: index,
        address,
        addresses: { [crypto]: address },
        balance: 1.0,
        crypto: crypto || 'BTC',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
      res.json({ address });
    }
  } catch (err) {
    console.error('Generate address error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/balance/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { crypto } = req.query;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user) {
      return res.json({
        balance: '0.00000000',
        address: '',
        crypto: crypto || 'BTC',
        display_balance: '0.00',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
    }
    const addresses = user.addresses || {};
    const address = addresses[crypto || user.crypto] || '';
    const balance = user.balance !== undefined ? user.balance : (await getBalance(address)) || 0;
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
  } catch (err) {
    console.error('Fetch balance error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/buy', async (req, res) => {
  const { telegram_id, country, resource } = req.body;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user || (user.balance !== undefined && user.balance < 0.0001)) {
      return res.json({ success: false, error: user?.language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds' });
    }
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    await Purchase.create({
      telegram_id,
      country,
      resource,
      code,
      status: 'active',
      service_type: 'sms',
    });
    user.balance = (user.balance || 1.0) - 0.0001;
    user.last_selected_resource = resource;
    await user.save();
    res.json({ success: true, code });
  } catch (err) {
    console.error('Buy error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/select-crypto/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  try {
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto,
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
    } else {
      user.crypto = crypto;
      await user.save();
    }
    res.json({ success: true, crypto });
  } catch (err) {
    console.error('Select crypto error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/set-language/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { language } = req.body;
  try {
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto: 'BTC',
        language,
        display_currency: language === 'ru' ? 'RUB' : 'USD',
        last_selected_resource: 'other',
      });
    } else {
      user.language = language;
      user.display_currency = language === 'ru' ? 'RUB' : 'USD';
      await user.save();
    }
    res.json({ success: true, language, display_currency: user.display_currency });
  } catch (err) {
    console.error('Set language error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/buy-number', async (req, res) => {
  const { telegram_id, country, service, currency, resource } = req.body;
  console.log('Buy number request:', { telegram_id, country, service, currency, resource });
  try {
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto: currency || 'BTC',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: resource || 'other',
      });
    }
    user.last_selected_resource = resource || user.last_selected_resource;
    await user.save();
    await processPurchase(user, telegram_id, country, service, currency, resource, res);
  } catch (err) {
    console.error('Buy number error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/purchases/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  try {
    const user = await User.findOne({ telegram_id });
    const purchases = await Purchase.find({ telegram_id }).sort({ created_at: -1 });
    console.log('Purchases fetched:', purchases);
    const rates = await fetchCryptoRates();
    const formattedPurchases = purchases.map((purchase) => {
      console.log('Formatting purchase:', purchase);
      const [priceValue, crypto] = purchase.price.split(' ');
      const rate = rates[crypto?.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
      const display_price = (parseFloat(priceValue) * rate).toFixed(2);
      return {
        id: purchase._id,
        telegram_id: purchase.telegram_id,
        country: countries.find((c) => c.id === purchase.country) || {
          id: purchase.country,
          name_en: purchase.country,
          name_ru: purchase.country,
        },
        service: purchase.resource,
        service_type: purchase.service_type,
        code: purchase.code,
        number: purchase.number || `+${Math.floor(10000000000 + Math.random() * 90000000000)}`,
        price: purchase.price,
        display_price: `${display_price} ${user.display_currency}`,
        created_at: purchase.created_at.toISOString(),
        status: purchase.status,
      };
    });
    res.json(formattedPurchases);
  } catch (err) {
    console.error('Fetch purchases error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/complete-purchase/:purchase_id', async (req, res) => {
  const { purchase_id } = req.params;
  try {
    const purchase = await Purchase.findById(purchase_id);
    if (!purchase) {
      return res.status(404).json({ error: 'Purchase not found' });
    }
    if (purchase.status === 'completed') {
      return res.json({ success: false, error: 'Purchase already completed' });
    }
    purchase.status = 'completed';
    await purchase.save();
    console.log('Purchase completed:', purchase);
    res.json({ success: true });
  } catch (err) {
    console.error('Complete purchase error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

async function processPurchase(user, telegram_id, country, service, currency, resource, res) {
  console.log('Processing purchase:', { telegram_id, country, service, currency, resource });
  const addresses = user.addresses || {};
  const address = addresses[currency] || '';
  const balance = user.balance !== undefined ? user.balance : (await getBalance(address)) || 0;
  const priceInCrypto = {
    sms: 0.012,
    call: 0.020,
    rent: 5,
  }[service] || 0.012;
  const rates = {
    USDT: 1,
    BTC: 0.000015,
    LTC: 0.012,
    ETH: 0.00033,
    BNB: 0.0017,
    AVAX: 0.028,
    ADA: 2.2,
    SOL: 0.0067,
  };
  const cryptoPrice = (priceInCrypto * (rates[currency] || 1)).toFixed(8);
  const cryptoRates = await fetchCryptoRates();
  const fiatRate = cryptoRates[currency.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
  const displayPrice = (parseFloat(cryptoPrice) * fiatRate).toFixed(2);
  if (isNaN(balance) || balance < parseFloat(cryptoPrice)) {
    console.log('Insufficient funds:', { balance, cryptoPrice });
    return res.json({ success: false, error: user.language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds' });
  }
  const number = `+${Math.floor(10000000000 + Math.random() * 90000000000)}`;
  const code = service === 'sms' ? `CODE-${Math.random().toString(36).slice(2, 8)}` : null;
  const last4 = service === 'call' ? number.slice(-4) : null;
  const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  try {
    const purchase = await Purchase.create({
      telegram_id,
      country,
      resource: resource || service,
      code: code || number,
      number,
      price: `${cryptoPrice} ${currency}`,
      service_type: service,
      status: 'active',
      created_at: new Date(),
    });
    console.log('Purchase created:', purchase);
    user.balance = (user.balance || 1.0) - parseFloat(cryptoPrice);
    user.last_selected_resource = resource || user.last_selected_resource;
    await user.save();
    console.log('Balance updated:', { telegram_id, newBalance: user.balance });
    res.json({
      success: true,
      number,
      last4,
      expiry,
      price: `${cryptoPrice} ${currency}`,
      display_price: `${displayPrice} ${user.display_currency}`,
      country: countries.find((c) => c.id === country) || { id: country, name_en: country, name_ru: country },
      service,
      resource,
      purchase_id: purchase._id,
    });
  } catch (err) {
    console.error('Process purchase error:', err);
    res.status(500).json({ error: 'Server error' });
  }
}

module.exports = router;









app.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountryList from './components/CountryList';
import Profile from './components/Profile';
import PurchaseResult from './components/PurchaseResult';
import PurchaseHistory from './components/PurchaseHistory';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [language, setLanguage] = useState('ru');
  const [displayCurrency, setDisplayCurrency] = useState('RUB');
  const [showCountryList, setShowCountryList] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [showLanguageModal, setShowLanguageModal] = useState(false);
  const [showPurchaseResult, setShowPurchaseResult] = useState(false);
  const [showPurchaseHistory, setShowPurchaseHistory] = useState(false);
  const [purchaseData, setPurchaseData] = useState(null);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [balance, setBalance] = useState('0.00000000');
  const [displayBalance, setDisplayBalance] = useState('0.00');
  const [refreshPurchases, setRefreshPurchases] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [lastSelectedResource, setLastSelectedResource] = useState('other');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      console.log('Telegram user:', user);
      tg.BackButton.onClick(() => {
        if (showProfile) setShowProfile(false);
        else if (showCountryList) setShowCountryList(false);
        else if (showPurchaseResult) {
          setShowPurchaseResult(false);
          setRefreshPurchases(true);
        } else if (showPurchaseHistory) setShowPurchaseHistory(false);
      });
      if (showCountryList || showProfile || showPurchaseResult || showPurchaseHistory) {
        tg.BackButton.show();
      } else {
        tg.BackButton.hide();
      }
      if (user?.id) {
        checkUser();
      }
    }
  }, [tg, showCountryList, showProfile, showPurchaseResult, showPurchaseHistory, selectedCrypto, user]);

  const checkUser = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      if (res.data.balance === '0.00000000' && !res.data.address) {
        setIsNewUser(true);
        setShowLanguageModal(true);
      } else {
        setLanguage(res.data.language || 'ru');
        setDisplayCurrency(res.data.display_currency || 'RUB');
        setBalance(res.data.balance || '0.00000000');
        setDisplayBalance(res.data.display_balance || '0.00');
        setLastSelectedResource(res.data.last_selected_resource || 'other');
      }
    } catch (err) {
      console.error('Check user error:', err);
    }
  };

  const handleSelectLanguage = async (lang) => {
    try {
      const res = await axios.post(
        `${API_URL}/set-language/${user.id}`,
        { language: lang },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setLanguage(lang);
      setDisplayCurrency(res.data.display_currency);
      setShowLanguageModal(false);
      setIsNewUser(false);
    } catch (err) {
      console.error('Set language error:', err);
    }
  };

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
      setDisplayBalance(res.data.display_balance || '0.00');
      setLastSelectedResource(res.data.last_selected_resource || 'other');
    } catch (err) {
      console.error('Fetch balance error:', err);
    }
  };

  const handleSelectCrypto = async (crypto) => {
    if (!user?.id) return;
    try {
      await axios.post(
        `${API_URL}/select-crypto/${user.id}`,
        { crypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setSelectedCrypto(crypto);
      fetchBalance();
    } catch (err) {
      console.error('Select crypto error:', err);
    }
  };

  const handleViewPurchase = (purchase) => {
    console.log('Viewing purchase:', purchase);
    setPurchaseData({
      ...purchase,
      purchase_id: purchase.id,
      country: purchase.country,
      service: purchase.service_type,
      resource: purchase.service,
      number: purchase.number,
      price: purchase.display_price || purchase.price,
      code: purchase.code,
      expiry: purchase.expiry || new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    });
    setShowPurchaseResult(true);
    setShowPurchaseHistory(false);
  };

  const handleGoToPurchases = () => {
    setShowPurchaseResult(false);
    setShowPurchaseHistory(true);
    setRefreshPurchases(true);
  };

  const texts = {
    ru: {
      title: 'Виртуальные сим-карты',
      subtitle: 'Более 70 стран от 0.01 €',
      buy: 'Купить',
      purchases: 'Мои покупки',
      selectLanguage: 'Выберите язык',
    },
    en: {
      title: 'Virtual SIM Cards',
      subtitle: 'Over 70 countries from 0.01 €',
      buy: 'Buy',
      purchases: 'My Purchases',
      selectLanguage: 'Select Language',
    },
  };

  if (showPurchaseResult) {
    return (
      <PurchaseResult
        language={language}
        purchaseData={purchaseData}
        onBack={() => {
          setShowPurchaseResult(false);
          setRefreshPurchases(true);
        }}
        balance={displayBalance}
        selectedCrypto={selectedCrypto}
        displayCurrency={displayCurrency}
        onGoToPurchases={handleGoToPurchases}
      />
    );
  }

  if (showPurchaseHistory) {
    return (
      <PurchaseHistory
        language={language}
        onBack={() => setShowPurchaseHistory(false)}
        refresh={refreshPurchases}
        setRefresh={setRefreshPurchases}
        onViewPurchase={handleViewPurchase}
      />
    );
  }

  if (showProfile) {
    return (
      <Profile
        username={user?.first_name || 'User'}
        selectedCrypto={selectedCrypto}
        setSelectedCrypto={handleSelectCrypto}
        balance={displayBalance}
        displayCurrency={displayCurrency}
        onBack={() => setShowProfile(false)}
      />
    );
  }

  if (showCountryList) {
    return (
      <CountryList
        language={language}
        onBack={() => setShowCountryList(false)}
        selectedCrypto={selectedCrypto}
        displayCurrency={displayCurrency}
        setShowPurchaseResult={setShowPurchaseResult}
        setPurchaseData={setPurchaseData}
        lastSelectedResource={lastSelectedResource}
      />
    );
  }

  return (
    <div className="p-4 max-w-md mx-auto">
      <div className="flex justify-between mb-4">
        <button
          className="bg-gray-200 px-3 py-1 rounded"
          onClick={() => setShowLanguageModal(true)}
        >
          {language.toUpperCase()}
        </button>
        <button
          className="text-lg font-semibold text-blue-500"
          onClick={() => setShowProfile(true)}
        >
          {user?.first_name || 'User'}
        </button>
      </div>
      <h1 className="text-2xl font-bold text-center mb-2">
        {texts[language].title}
      </h1>
      <p className="text-center text-gray-600 mb-6">
        {texts[language].subtitle}
      </p>
      <div className="flex flex-col gap-4">
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded"
          onClick={() => setShowCountryList(true)}
        >
          {texts[language].buy}
        </button>
        <button
          className="bg-gray-500 text-white px-4 py-2 rounded"
          onClick={() => setShowPurchaseHistory(true)}
        >
          {texts[language].purchases}
        </button>
      </div>
      {showLanguageModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
          onClick={() => !isNewUser && setShowLanguageModal(false)}
        >
          <div
            className="bg-white p-4 rounded-lg max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold mb-4">
              {texts[language].selectLanguage}
            </h2>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => handleSelectLanguage('ru')}
            >
              Русский (RUB)
            </button>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => handleSelectLanguage('en')}
            >
              English (USD)
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;







countrylist.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import NumberModal from './NumberModal';
import axios from 'axios';

function CountryList({ language, onBack, selectedCrypto, displayCurrency, setShowPurchaseResult, setPurchaseData, lastSelectedResource }) {
  const { tg } = useTelegram();
  const [countries, setCountries] = useState([]);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    const fetchCountries = async () => {
      try {
        const res = await axios.get(`${API_URL}/countries`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setCountries(res.data);
      } catch (err) {
        console.error('Fetch countries error:', err);
      }
    };
    fetchCountries();
  }, [API_URL]);

  const filteredCountries = countries.filter((country) =>
    language === 'ru'
      ? country.name_ru.toLowerCase().includes(search.toLowerCase())
      : country.name_en.toLowerCase().includes(search.toLowerCase())
  );

  const texts = {
    ru: {
      title: 'Выберите страну',
      search: 'Поиск...',
    },
    en: {
      title: 'Select Country',
      search: 'Search...',
    },
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      <input
        type="text"
        className="w-full p-2 mb-4 border rounded"
        placeholder={texts[language].search}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="space-y-2">
        {filteredCountries.map((country) => (
          <button
            key={country.id}
            className="w-full p-2 text-left bg-gray-100 rounded hover:bg-gray-200"
            onClick={() => setSelectedCountry(country)}
          >
            {language === 'ru' ? country.name_ru : country.name_en}
          </button>
        ))}
      </div>
      {selectedCountry && (
        <NumberModal
          language={language}
          country={selectedCountry}
          selectedCrypto={selectedCrypto}
          displayCurrency={displayCurrency}
          onClose={() => setSelectedCountry(null)}
          setShowPurchaseResult={setShowPurchaseResult}
          setPurchaseData={setPurchaseData}
          lastSelectedResource={lastSelectedResource}
        />
      )}
    </div>
  );
}

export default CountryList;







NumberModal.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ language, country, selectedCrypto, displayCurrency, onClose, setShowPurchaseResult, setPurchaseData, lastSelectedResource }) {
  const { tg, user } = useTelegram();
  const [services, setServices] = useState([]);
  const [search, setSearch] = useState('');
  const [selectedService, setSelectedService] = useState(null);
  const [step, setStep] = useState('select_service');
  const [error, setError] = useState('');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchServices = async () => {
      try {
        const res = await axios.get(`${API_URL}/resources?language=${language}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setServices(res.data);
        if (lastSelectedResource) {
          const lastService = res.data.find((s) => s.id === lastSelectedResource);
          if (lastService) setSelectedService(lastService);
        }
      } catch (err) {
        console.error('Fetch services error:', err);
        setError(language === 'ru' ? 'Ошибка загрузки сервисов' : 'Error loading services');
      }
    };
    fetchServices();
  }, [API_URL, language, lastSelectedResource]);

  const filteredServices = services.filter((service) =>
    service.name.toLowerCase().includes(search.toLowerCase())
  );

  const handleServiceSelect = (service) => {
    setSelectedService(service);
    setStep('select_type');
  };

  const handleBuy = async (serviceType) => {
    if (!user?.id || !selectedService) return;
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        {
          telegram_id: user.id,
          country: country.id,
          service: serviceType,
          currency: selectedCrypto,
          resource: selectedService.id,
        },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (res.data.success) {
        setPurchaseData({
          ...res.data,
          number: res.data.number,
          price: res.data.display_price || res.data.price,
          expiry: res.data.expiry,
          country,
          service: serviceType,
          resource: selectedService.id,
          purchase_id: res.data.purchase_id,
        });
        setShowPurchaseResult(true);
        onClose();
      } else {
        tg?.showPopup({
          message: res.data.error || (language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds'),
        });
      }
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({
        message: language === 'ru' ? 'Ошибка покупки' : 'Purchase error',
      });
    }
  };

  const texts = {
    ru: {
      title: 'Выберите сервис',
      search: 'Поиск сервиса...',
      selectType: 'Выберите тип услуги',
      sms: 'SMS',
      call: 'Звонки',
      rent: 'Аренда номера',
      back: 'Назад',
      close: 'Закрыть',
      error: 'Ошибка покупки',
    },
    en: {
      title: 'Select Service',
      search: 'Search service...',
      selectType: 'Select Service Type',
      sms: 'SMS',
      call: 'Calls',
      rent: 'Number Rental',
      back: 'Back',
      close: 'Close',
      error: 'Purchase error',
    },
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-4 rounded-lg max-w-sm w-full">
        {step === 'select_service' ? (
          <>
            <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
            <input
              type="text"
              className="w-full p-2 mb-4 border rounded"
              placeholder={texts[language].search}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <div className="max-h-64 overflow-y-auto space-y-2">
              {filteredServices.map((service) => (
                <div
                  key={service.id}
                  className={`p-2 border rounded cursor-pointer ${
                    selectedService?.id === service.id ? 'bg-blue-100' : ''
                  }`}
                  onClick={() => handleServiceSelect(service)}
                >
                  <p>{service.name}</p>
                </div>
              ))}
            </div>
            {error && <p className="text-red-500 mt-2">{error}</p>}
            <button
              className="mt-4 w-full bg-gray-500 text-white px-4 py-2 rounded"
              onClick={onClose}
            >
              {texts[language].close}
            </button>
          </>
        ) : (
          <>
            <h2 className="text-xl font-bold mb-4">{texts[language].selectType}</h2>
            <p className="mb-4">{texts[language].title}: {selectedService.name}</p>
            <button
              className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
              onClick={() => handleBuy('sms')}
            >
              {texts[language].sms}
            </button>
            <button
              className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
              onClick={() => handleBuy('call')}
            >
              {texts[language].call}
            </button>
            <button
              className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
              onClick={() => handleBuy('rent')}
            >
              {texts[language].rent}
            </button>
            {error && <p className="text-red-500 mt-2">{error}</p>}
            <div className="flex gap-2 mt-4">
              <button
                className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
                onClick={() => setStep('select_service')}
              >
                {texts[language].back}
              </button>
              <button
                className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
                onClick={onClose}
              >
                {texts[language].close}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default NumberModal;












PurchaseResult.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function PurchaseResult({ language, purchaseData, onBack, balance, selectedCrypto, displayCurrency, onGoToPurchases }) {
  const { tg } = useTelegram();
  const [code, setCode] = useState('');
  const [isLoadingCode, setIsLoadingCode] = useState(purchaseData.code ? true : false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    console.log('PurchaseResult data:', purchaseData);
    if (purchaseData.service === 'sms' && purchaseData.code && !code) {
      console.log('Starting 90s timer for code:', purchaseData.code);
      const timer = setTimeout(() => {
        console.log('Code displayed:', purchaseData.code);
        setCode(purchaseData.code);
        setIsLoadingCode(false);
      }, 90000);
      return () => clearTimeout(timer);
    }
  }, [purchaseData.service, purchaseData.code, code]);

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
  };

  const completePurchase = async () => {
    try {
      await axios.post(
        `${API_URL}/complete-purchase/${purchaseData.purchase_id}`,
        {},
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      tg?.showPopup({ message: language === 'ru' ? 'Покупка завершена!' : 'Purchase completed!' });
      onGoToPurchases();
    } catch (err) {
      console.error('Complete purchase error:', err);
      tg?.showPopup({
        message: language === 'ru' ? 'Ошибка завершения покупки' : 'Error completing purchase',
      });
    }
  };

  const texts = {
    ru: {
      title: 'Результат покупки',
      number: 'Номер:',
      price: 'Цена:',
      code: 'Код:',
      waiting: 'Ожидание кода...',
      copy: 'Копировать',
      complete: 'Принять код',
      toPurchases: 'В мои покупки →',
      expiry: 'Действует до:',
      balance: 'Баланс:',
      crypto: 'Валюта:',
      service: 'Сервис:',
      type: 'Тип услуги:',
    },
    en: {
      title: 'Purchase Result',
      number: 'Number:',
      price: 'Price:',
      code: 'Code:',
      waiting: 'Waiting for code...',
      copy: 'Copy',
      complete: 'Accept Code',
      toPurchases: 'To My Purchases →',
      expiry: 'Valid until:',
      balance: 'Balance:',
      crypto: 'Currency:',
      service: 'Service:',
      type: 'Service Type:',
    },
  };

  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleString(language === 'ru' ? 'ru-RU' : 'en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getServiceTypeName = (type) => {
    const names = {
      sms: { ru: 'СМС', en: 'SMS' },
      call: { ru: 'Звонок', en: 'Call' },
      rent: { ru: 'Аренда номера', en: 'Number Rental' },
    };
    return names[type] ? names[type][language] : type;
  };

  const isFromPurchaseHistory = !!purchaseData.code;

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      <div className="p-4 bg-gray-100 rounded-lg shadow">
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].number}</p>
          <div className="flex items-center">
            <p>{purchaseData.number}</p>
            <button
              className="ml-2 text-blue-500"
              onClick={() => copyToClipboard(purchaseData.number)}
            >
              {texts[language].copy}
            </button>
          </div>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].service}</p>
          <p>{purchaseData.resource}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].type}</p>
          <p>{getServiceTypeName(purchaseData.service)}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].price}</p>
          <p>{purchaseData.display_price || purchaseData.price}</p>
        </div>
        {isFromPurchaseHistory && purchaseData.service === 'sms' && (
          <div className="flex justify-between mb-2">
            <p className="font-semibold">{texts[language].code}</p>
            <div className="flex items-center">
              {isLoadingCode ? (
                <div className="flex items-center">
                  <div className="spinner border-t-2 border-blue-500 rounded-full w-5 h-5 animate-spin mr-2"></div>
                  <p>{texts[language].waiting}</p>
                </div>
              ) : (
                <>
                  <p>{code || texts[language].waiting}</p>
                  {code && (
                    <button
                      className="ml-2 text-blue-500"
                      onClick={() => copyToClipboard(code)}
                    >
                      {texts[language].copy}
                    </button>
                  )}
                </>
              )}
            </div>
          </div>
        )}
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].expiry}</p>
          <p>{formatDate(purchaseData.expiry)}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].balance}</p>
          <p>{balance} {displayCurrency}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].crypto}</p>
          <p>{selectedCrypto}</p>
        </div>
        {isFromPurchaseHistory && purchaseData.service === 'sms' && !isLoadingCode && code && (
          <button
            className="mt-4 w-full bg-green-500 text-white px-4 py-2 rounded"
            onClick={completePurchase}
          >
            {texts[language].complete}
          </button>
        )}
        {!isFromPurchaseHistory && (
          <button
            className="mt-4 w-full bg-blue-500 text-white px-4 py-2 rounded"
            onClick={onGoToPurchases}
          >
            {texts[language].toPurchases}
          </button>
        )}
      </div>
      <style>
        {`
          .spinner {
            border: 2px solid #f3f3f3;
            border-top: 2px solid #3498db;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            animation: spin 1s linear infinite;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        `}
      </style>
    </div>
  );
}

export default PurchaseResult;












PurchaseHistory.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function PurchaseHistory({ language, onBack, refresh, setRefresh, onViewPurchase }) {
  const { tg, user } = useTelegram();
  const [purchases, setPurchases] = useState([]);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    const fetchPurchases = async () => {
      if (!user?.id) return;
      try {
        console.log('Fetching purchases for user:', user.id);
        const res = await axios.get(`${API_URL}/purchases/${user.id}`, {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        });
        console.log('Purchases response:', res.data);
        setPurchases(res.data);
        if (refresh) setRefresh(false);
      } catch (err) {
        console.error('Fetch purchases error:', err);
      }
    };
    fetchPurchases();
  }, [user, refresh, tg, API_URL]);

  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleString(language === 'ru' ? 'ru-RU' : 'en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const texts = {
    ru: {
      title: 'Мои покупки',
      country: 'Страна:',
      service: 'Сервис:',
      type: 'Тип услуги:',
      number: 'Номер:',
      price: 'Цена:',
      status: 'Статус:',
      active: 'Активна',
      completed: 'Завершена',
      view: 'Просмотреть',
      noPurchases: 'Нет покупок',
    },
    en: {
      title: 'My Purchases',
      country: 'Country:',
      service: 'Service:',
      type: 'Service Type:',
      number: 'Number:',
      price: 'Price:',
      status: 'Status:',
      active: 'Active',
      completed: 'Completed',
      view: 'View',
      noPurchases: 'No purchases',
    },
  };

  const getServiceTypeName = (type) => {
    const names = {
      sms: { ru: 'СМС', en: 'SMS' },
      call: { ru: 'Звонок', en: 'Call' },
      rent: { ru: 'Аренда номера', en: 'Number Rental' },
    };
    return names[type] ? names[type][language] : type;
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      {purchases.length === 0 ? (
        <p className="text-center text-gray-600">{texts[language].noPurchases}</p>
      ) : (
        <div className="space-y-4">
          {purchases.map((purchase) => (
            <div key={purchase.id} className="p-4 bg-gray-100 rounded-lg shadow">
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].country}</p>
                <p>{language === 'ru' ? purchase.country.name_ru : purchase.country.name_en}</p>
              </div>
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].service}</p>
                <p>{purchase.service}</p>
              </div>
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].type}</p>
                <p>{getServiceTypeName(purchase.service_type)}</p>
              </div>
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].number}</p>
                <p>{purchase.number}</p>
              </div>
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].price}</p>
                <p>{purchase.display_price || purchase.price}</p>
              </div>
              <div className="flex justify-between mb-2">
                <p className="font-semibold">{texts[language].status}</p>
                <div className="flex items-center">
                  <span
                    className={`w-3 h-3 rounded-full mr-2 ${
                      purchase.status === 'active' ? 'bg-green-500' : 'bg-red-500'
                    }`}
                  ></span>
                  <p>
                    {purchase.status === 'active'
                      ? texts[language].active
                      : texts[language].completed}
                  </p>
                </div>
              </div>
              {purchase.status === 'active' && (
                <button
                  className="mt-2 w-full bg-blue-500 text-white px-4 py-2 rounded"
                  onClick={() => onViewPurchase(purchase)}
                >
                  {texts[language].view}
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default PurchaseHistory;





