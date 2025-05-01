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
  language: { type: String, default: 'ru' }, // RU, EN
  display_currency: { type: String, default: 'RUB' }, // RUB, USD
});

const purchaseSchema = new mongoose.Schema({
  telegram_id: String,
  country: String,
  resource: String,
  code: String,
  number: String,
  price: String,
  status: { type: String, enum: ['active', 'completed'], default: 'active' },
  created_at: { type: Date, default: Date.now },
});

const User = mongoose.model('User', userSchema);
const Purchase = mongoose.model('Purchase', purchaseSchema);

module.exports = { connectDB, User, Purchase };





server.js:
const express = require('express');
const cors = require('cors');
const routes = require('./src/routes');
const { connectDB } = require('./src/db');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 5000;

app.use(cors({
  origin: process.env.WEB_APP_URL,
  credentials: true,
}));
app.use(express.json());
app.use((req, res, next) => {
  res.header('ngrok-skip-browser-warning', 'true');
  next();
});
app.use('/', routes);

// Подключение к MongoDB
connectDB().catch((err) => {
  console.error('Failed to connect to MongoDB:', err);
  process.exit(1);
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});








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

// Кэш для курсов валют
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
  res.json([
    { id: 'whatsapp', name: 'WhatsApp' },
    { id: 'telegram', name: 'Telegram' },
    { id: 'other', name: language === 'ru' ? 'Другой' : 'Other' },
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
        language: 'ru',
        display_currency: 'RUB',
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
      return res.json({ balance: '0.00000000', address: '', crypto: crypto || 'BTC', display_balance: '0.00', language: 'ru', display_currency: 'RUB' });
    }
    const addresses = user.addresses || {};
    const address = addresses[crypto || user.crypto] || '';
    const balance = user.balance || (await getBalance(address)) || 0;
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
    if (!user || user.balance < 0.0001) {
      return res.json({ success: false, error: user?.language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds' });
    }
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    await Purchase.create({
      telegram_id,
      country,
      resource,
      code,
      status: 'active',
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
        language: 'ru',
        display_currency: 'RUB',
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
  const { telegram_id, country, service, currency } = req.body;
  console.log('Buy number request:', { telegram_id, country, service, currency });
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

async function processPurchase(user, telegram_id, country, service, currency, res) {
  console.log('Processing purchase:', { telegram_id, country, service, currency });
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
  const cryptoPrice = (priceInCrypto * (rates[currency] || 1)).toFixed(8);
  const cryptoRates = await fetchCryptoRates();
  const fiatRate = cryptoRates[currency.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
  const displayPrice = (cryptoPrice * fiatRate).toFixed(2);
  if (balance < cryptoPrice) {
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
      resource: service,
      code: code || number,
      number,
      price: `${cryptoPrice} ${currency}`,
      status: 'active',
      created_at: new Date(),
    });
    console.log('Purchase created:', purchase);
    user.balance -= parseFloat(cryptoPrice);
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
      purchase_id: purchase._id,
    });
  } catch (err) {
    console.error('Process purchase error:', err);
    res.status(500).json({ error: 'Server error' });
  }
}

module.exports = router;











