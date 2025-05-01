PROF
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import CryptoModal from './CryptoModal';
import BalanceModal from './BalanceModal';
import QRCode from 'qrcode.react';
import axios from 'axios';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, displayCurrency, onBack, language }) {
  const { tg } = useTelegram();
  const [showCryptoModal, setShowCryptoModal] = useState(false);
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const [address, setAddress] = useState('');
  const [isCryptoLoading, setIsCryptoLoading] = useState(false);
  const [isGeneratingAddress, setIsGeneratingAddress] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    console.log('Profile.jsx: selectedCrypto updated:', selectedCrypto);
  }, [selectedCrypto]);

  const handleGenerateAddress = async () => {
    if (!tg?.initData || isCryptoLoading || isGeneratingAddress || !selectedCrypto) {
      console.warn('Generate address blocked:', {
        hasInitData: !!tg?.initData,
        isCryptoLoading,
        isGeneratingAddress,
        selectedCrypto,
      });
      return;
    }
    setIsGeneratingAddress(true);
    try {
      console.log('Generating address for crypto:', selectedCrypto);
      const res = await axios.post(
        `${API_URL}/generate-address/${tg.initDataUnsafe.user.id}`,
        { crypto: selectedCrypto },
        {
          headers: {
            'telegram-init-data': tg.initData,
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      console.log('Generate address response:', res.data); // Лог для отладки
      if (!res.data.address) {
        throw new Error('No address returned from server');
      }
      setAddress(res.data.address);
      // Ждем обновления состояния перед открытием модалки
      setTimeout(() => {
        setShowBalanceModal(true);
      }, 0);
    } catch (err) {
      console.error('Generate address error:', err.response?.data || err.message);
      tg.showPopup({
        message: language === 'ru' ? 'Ошибка генерации адреса' : 'Error generating address',
      });
    } finally {
      setIsGeneratingAddress(false);
    }
  };

  const handleSelectCrypto = async (crypto) => {
    if (crypto === selectedCrypto) {
      setShowCryptoModal(false);
      return;
    }
    setIsCryptoLoading(true);
    try {
      console.log('Selecting crypto:', crypto);
      await axios.post(
        `${API_URL}/select-crypto/${tg.initDataUnsafe.user.id}`,
        { crypto },
        {
          headers: {
            'telegram-init-data': tg.initData,
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setSelectedCrypto(crypto);
      setShowCryptoModal(false);
    } catch (err) {
      console.error('Select crypto error:', err.response?.data || err.message);
      tg.showPopup({
        message: language === 'ru' ? 'Ошибка выбора валюты' : 'Error selecting currency',
      });
    } finally {
      setIsCryptoLoading(false);
    }
  };

  const texts = {
    ru: {
      profile: 'Профиль',
      balance: 'Баланс',
      topUp: 'Пополнить',
      crypto: 'Валюта',
      copied: 'Адрес скопирован',
    },
    en: {
      profile: 'Profile',
      balance: 'Balance',
      topUp: 'Top Up',
      crypto: 'Currency',
      copied: 'Address copied',
    },
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4">{texts[language].profile}</h1>
      <p className="text-lg mb-4">{username}</p>
      <div className="mb-4">
        <p className="text-sm text-gray-600">{texts[language].balance}</p>
        <p className="text-lg font-semibold">
          {balance} {displayCurrency}
        </p>
      </div>
      <div className="mb-4">
        <p className="text-sm text-gray-600">{texts[language].crypto}</p>
        <button
          className="text-lg font-semibold text-blue-500"
          onClick={() => setShowCryptoModal(true)}
          disabled={isCryptoLoading || isGeneratingAddress}
        >
          {selectedCrypto || 'BTC'} {isCryptoLoading && <span className="spinner ml-2"></span>}
        </button>
      </div>
      <button
        className={`w-full bg-blue-500 text-white px-4 py-2 rounded mb-4 ${
          isCryptoLoading || isGeneratingAddress || !selectedCrypto ? 'opacity-50 cursor-not-allowed' : ''
        }`}
        onClick={handleGenerateAddress}
        disabled={isCryptoLoading || isGeneratingAddress || !selectedCrypto}
      >
        {texts[language].topUp} {isGeneratingAddress && <span className="spinner ml-2"></span>}
      </button>
      {showCryptoModal && (
        <CryptoModal
          language={language}
          onClose={() => setShowCryptoModal(false)}
          onSelect={handleSelectCrypto}
          selectedCrypto={selectedCrypto}
          isLoading={isCryptoLoading}
        />
      )}
      {showBalanceModal && (
        <BalanceModal
          language={language}
          address={address}
          crypto={selectedCrypto}
          onClose={() => setShowBalanceModal(false)}
          onCopy={() => tg.showPopup({ message: texts[language].copied })}
        />
      )}
      <style>
        {`
          .spinner {
            display: inline-block;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #3498db;
            border-radius: 50%;
            width: 16px;
            height: 16px;
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

export default Profile;








BalanceMOD
import QRCode from 'qrcode.react';

function BalanceModal({ language, address, crypto, onClose, onCopy }) {
  const texts = {
    ru: {
      title: 'Пополнение баланса',
      balance: 'Текущий баланс',
      address: 'Адрес для пополнения',
      close: 'Закрыть',
      copy: 'Скопировать адрес',
    },
    en: {
      title: 'Top Up Balance',
      balance: 'Current Balance',
      address: 'Deposit Address',
      close: 'Close',
      copy: 'Copy Address',
    },
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
      onClick={onClose}
    >
      <div
        className="bg-white p-4 rounded-lg max-w-sm w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
        <p className="text-sm text-gray-600 mb-2">{texts[language].balance}</p>
        <p className="text-lg font-semibold mb-4">{crypto || 'N/A'}</p>
        {address ? (
          <>
            <p className="text-sm text-gray-600 mb-2">{texts[language].address}</p>
            <p className="text-sm break-all mb-4">{address}</p>
            <QRCode value={address} size={128} className="mb-4 mx-auto" />
          </>
        ) : (
          <p className="text-sm text-red-500 mb-4">
            {language === 'ru' ? 'Адрес не сгенерирован' : 'Address not generated'}
          </p>
        )}
        <div className="flex gap-4">
          <button
            className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
          >
            {texts[language].close}
          </button>
          <button
            className="flex-1 bg-blue-500 text-white px-4 py-2 rounded"
            onClick={() => {
              navigator.clipboard.writeText(address || '');
              onCopy();
            }}
            disabled={!address}
          >
            {texts[language].copy}
          </button>
        </div>
      </div>
    </div>
  );
}

export default BalanceModal;






ROUTES
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

const SUPPORTED_CRYPTOS = ['BTC', 'USDT', 'LTC', 'ETH', 'BNB', 'AVAX', 'ADA', 'SOL'];

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

router.get('/resources', async (req, res) => {
  const language = req.query.language || 'ru';
  try {
    const rates = await fetchCryptoRates();
    console.log('Returning rates for /resources:', rates);
    res.json({
      services: resources.map((resource) => ({
        id: resource.id,
        name: language === 'ru' ? resource.name_ru : resource.name_en,
      })),
      rates,
    });
  } catch (err) {
    console.error('Fetch resources error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/generate-address/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  console.log('Raw request body:', req.body);
  try {
    if (!crypto || !SUPPORTED_CRYPTOS.includes(crypto)) {
      console.warn('Invalid crypto:', { crypto, supported: SUPPORTED_CRYPTOS });
      return res.status(400).json({ error: `Invalid cryptocurrency: ${crypto || 'undefined'}` });
    }
    console.log('Generate address request:', { telegram_id, crypto });
    let user = await User.findOne({ telegram_id });
    let addresses = user?.addresses || {};
    if (!user || user.crypto !== crypto || !addresses[crypto]) {
      const address = await generateAddress(telegram_id, crypto);
      addresses[crypto] = address;
      if (user) {
        user.addresses = addresses;
        user.crypto = crypto;
        await user.save();
        console.log('New address generated:', { address, crypto });
        res.json({ address });
      } else {
        const index = Math.floor(Math.random() * 1000000);
        await User.create({
          telegram_id,
          wallet_index: index,
          address,
          addresses: { [crypto]: address },
          balance: 1.0,
          crypto,
          language: 'ru',
          display_currency: 'RUB',
          last_selected_resource: 'other',
        });
        console.log('New user created with address:', { address, crypto });
        res.json({ address });
      }
    } else {
      console.log('Returning cached address:', { address: addresses[crypto], crypto });
      res.json({ address: addresses[crypto] });
    }
  } catch (err) {
    console.error('Generate address error:', err.message);
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
  console.log('Raw request body for select-crypto:', req.body);
  try {
    if (!crypto || !SUPPORTED_CRYPTOS.includes(crypto)) {
      console.warn('Invalid crypto in select-crypto:', { crypto, supported: SUPPORTED_CRYPTOS });
      return res.status(400).json({ error: `Invalid cryptocurrency: ${crypto || 'undefined'}` });
    }
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
    console.log('Crypto selected:', { telegram_id, crypto });
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
      return res.status(400).json({ error: 'Purchase not found' });
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

