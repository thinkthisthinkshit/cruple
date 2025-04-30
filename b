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

// Схемы
const userSchema = new mongoose.Schema({
  telegram_id: { type: String, required: true, unique: true },
  wallet_index: Number,
  address: String,
  addresses: Object,
  balance: Number,
  crypto: String,
});

const purchaseSchema = new mongoose.Schema({
  telegram_id: String,
  country: String,
  resource: String,
  code: String,
  number: String,
  price: String,
  created_at: { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);
const Purchase = mongoose.model('Purchase', purchaseSchema);

module.exports = { connectDB, User, Purchase };



server.js:
const express = require('express');
const cors = require('cors');
const routes = require('./routes');
const { connectDB } = require('./db');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 5000;

app.use(cors({
  origin: process.env.WEB_APP_URL,
  credentials: true,
}));
app.use(express.json());
app.use('/', routes);

// Подключение к MongoDB
connectDB();

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});





routes.js:
const express = require('express');
const { User, Purchase } = require('./db');
const { generateAddress, getBalance } = require('./wallet');

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

router.get('/countries', (req, res) => {
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
      return res.json({ balance: '0.00000000', address: '', crypto: crypto || 'BTC' });
    }
    const addresses = user.addresses || {};
    const address = addresses[crypto || user.crypto] || '';
    const balance = user.balance || (await getBalance(address)) || 0;
    res.json({ balance: balance.toFixed(8), address, crypto: crypto || user.crypto || 'BTC' });
  } catch (err) {
    console.error('Fetch balance error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/buy', async (req, res) => {
  const { telegram_id, country, resource } = req.body;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user || user.balance < 0.0001) {
      return res.json({ success: false });
    }
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    await Purchase.create({
      telegram_id,
      country,
      resource,
      code,
    });
    user.balance -= 0.0001;
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

router.post('/buy-number', async (req, res) => {
  const { telegram_id, country, service, currency } = req.body;
  console.log('Buy number request:', { telegram_id, country, service, currency }); // Лог для отладки
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
      });
    }
    await processPurchase(user, telegram_id, country, service, currency, res);
  } catch (err) {
    console.error('Buy number error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/purchases/:telegram_id', async (req, res) => {
  const { telegram_id } = req.params;
  try {
    const purchases = await Purchase.find({ telegram_id }).sort({ created_at: -1 });
    console.log('Purchases fetched:', purchases); // Лог для отладки
    const formattedPurchases = purchases.map((purchase) => ({
      id: purchase._id,
      telegram_id: purchase.telegram_id,
      country: countries.find((c) => c.id === purchase.country) || {
        id: purchase.country,
        name_en: purchase.country,
        name_ru: purchase.country,
      },
      service: purchase.resource,
      code: purchase.code,
      number: purchase.number || `+${Math.floor(10000000000 + Math.random() * 90000000000)}`,
      price: purchase.price || '0.00018000 BTC',
      created_at: purchase.created_at.toISOString(),
    }));
    res.json(formattedPurchases);
  } catch (err) {
    console.error('Fetch purchases error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

async function processPurchase(user, telegram_id, country, service, currency, res) {
  console.log('Processing purchase:', { telegram_id, country, service, currency }); // Лог для отладки
  const addresses = user.addresses || {};
  const address = addresses[currency] || '';
  const balance = user.balance || (await getBalance(address)) || 0;
  const priceInCrypto = {
    sms: 0.012,
    call: 0.020,
    rent: 5,
  }[service];
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
  const price = (priceInCrypto * (rates[currency] || 1)).toFixed(8);
  if (balance < price) {
    console.log('Insufficient funds:', { balance, price }); // Лог для отладки
    return res.json({ success: false, error: 'Недостаточно средств' });
  }
  const number = `+${Math.floor(10000000000 + Math.random() * 90000000000)}`;
  const code = service === 'sms' ? `CODE-${Math.random().toString(36).slice(2, 8)}` : null;
  const last4 = service === 'call' ? number.slice(-4) : null;
  const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  try {
    const purchase = await Purchase.create({
      telegram_id,
      country,
      resource: service,
      code: code || number,
      number,
      price: `${price} ${currency}`,
      created_at: new Date(),
    });
    console.log('Purchase created:', purchase); // Лог для отладки
    user.balance -= parseFloat(price);
    await user.save();
    console.log('Balance updated:', { telegram_id, newBalance: user.balance }); // Лог для отладки
    res.json({
      success: true,
      number,
      code,
      last4,
      expiry,
      price: `${price} ${currency}`,
      country: countries.find((c) => c.id === country) || { id: country, name_en: country, name_ru: country },
      service,
    });
  } catch (err) {
    console.error('Process purchase error:', err);
    res.status(500).json({ error: 'Server error' });
  }
}

module.exports = router;










PurchaseHistory:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function PurchaseHistory({ language, onBack, refresh, setRefresh }) {
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
      if (!user?.id) {
        console.log('No user ID available'); // Лог для отладки
        return;
      }
      try {
        console.log('Fetching purchases for user:', user.id); // Лог для отладки
        const res = await axios.get(`${API_URL}/purchases/${user.id}`, {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        });
        console.log('Purchases response:', res.data); // Лог для отладки
        setPurchases(res.data);
        if (refresh) setRefresh(false); // Сбросить флаг после обновления
      } catch (err) {
        console.error('Fetch purchases error:', err.response?.data || err.message); // Улучшенный лог ошибки
        tg?.showPopup({ message: language === 'ru' ? 'Ошибка загрузки покупок' : 'Error loading purchases' });
      }
    };
    fetchPurchases();
  }, [user strategically, tg, language, refresh]);

  const texts = {
    ru: {
      title: 'Мои покупки',
      name: 'Название:',
      number: 'Номер:',
      country: 'Страна:',
      service: 'Сервис:',
      price: 'Цена:',
      date: 'Дата:',
      empty: 'Покупок пока нет',
    },
    en: {
      title: 'My Purchases',
      name: 'Name:',
      number: 'Number:',
      country: 'Country:',
      service: 'Service:',
      price: 'Price:',
      date: 'Date:',
      empty: 'No purchases yet',
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

  const getServiceName = (service) => {
    const names = {
      sms: language === 'ru' ? 'СМС' : 'SMS',
      call: language === 'ru' ? 'Звонок' : 'Call',
      rent: language === 'ru' ? 'Аренда номера' : 'Number Rental',
    };
    return names[service] || service;
  };

  const getPurchaseName = (purchase) => {
    const countryName = language === 'ru' ? purchase.country.name_ru : purchase.country.name_en;
    const serviceName = getServiceName(purchase.service);
    return `${countryName} - ${serviceName}`;
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      {purchases.length === 0 ? (
        <p className="text-center text-gray-600">{texts[language].empty}</p>
      ) : (
        <div className="space-y-4">
          {purchases.map((purchase) => (
            <div key={purchase.id} className="p-4 bg-gray-100 rounded-lg shadow">
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].name}</p>
                <p>{getPurchaseName(purchase)}</p>
              </div>
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].number}</p>
                <p>{purchase.number}</p>
              </div>
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].country}</p>
                <p>{language === 'ru' ? purchase.country.name_ru : purchase.country.name_en}</p>
              </div>
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].service}</p>
                <p>{getServiceName(purchase.service)}</p>
              </div>
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].price}</p>
                <p>{purchase.price}</p>
              </div>
              <div className="flex justify-between">
                <p className="font-semibold">{texts[language].date}</p>
                <p>{formatDate(purchase.created_at)}</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default PurchaseHistory;









