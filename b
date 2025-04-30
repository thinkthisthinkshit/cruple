routes:
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
        [telegram_id, index, address, JSON.stringify({ [crypto]: address }), 1.0, crypto || 'BTC'],
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
  const { crypto } = req.query;
  db.get('SELECT addresses, crypto, balance FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (!row) {
      return res.json({ balance: '0.00000000', address: '', crypto: crypto || 'BTC' });
    }
    const addresses = row.addresses ? JSON.parse(row.addresses) : {};
    const address = addresses[crypto || row.crypto] || '';
    const balance = row.balance || (await getBalance(address)) || 0;
    res.json({ balance: balance.toFixed(8), address, crypto: crypto || row.crypto || 'BTC' });
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
  db.get('SELECT * FROM users WHERE telegram_id = ?', [telegram_id], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'DB error' });
    }
    if (!row) {
      const index = Math.floor(Math.random() * 1000000);
      db.run(
        'INSERT INTO users (telegram_id, wallet_index, address, addresses, balance, crypto) VALUES (?, ?, ?, ?, ?, ?)',
        [telegram_id, index, '', '{}', 1.0, crypto],
        (err) => {
          if (err) return res.status(500).json({ error: 'DB error' });
          res.json({ success: true, crypto });
        }
      );
    } else {
      db.run(
        'UPDATE users SET crypto = ? WHERE telegram_id = ?',
        [crypto, telegram_id],
        (err) => {
          if (err) return res.status(500).json({ error: 'DB error' });
          res.json({ success: true, crypto });
        }
      );
    }
  });
});

router.post('/buy-number', async (req, res) => {
  const { telegram_id, country, service, currency } = req.body;
  db.get('SELECT balance, crypto, addresses FROM users WHERE telegram_id = ?', [telegram_id], async (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'DB error' });
    }
    if (!row) {
      const index = Math.floor(Math.random() * 1000000);
      db.run(
        'INSERT INTO users (telegram_id, wallet_index, address, addresses, balance, crypto) VALUES (?, ?, ?, ?, ?, ?)',
        [telegram_id, index, '', '{}', 1.0, currency || 'BTC'],
        async (err) => {
          if (err) {
            return res.status(500).json({ error: 'DB error' });
          }
          // Повторно получить данные пользователя после создания
          db.get('SELECT balance, crypto, addresses FROM users WHERE telegram_id = ?', [telegram_id], async (err, newRow) => {
            if (err) {
              return res.status(500).json({ error: 'DB error' });
            }
            await processPurchase(newRow, telegram_id, country, service, currency, res);
          });
        }
      );
    } else {
      await processPurchase(row, telegram_id, country, service, currency, res);
    }
  });
});

async function processPurchase(row, telegram_id, country, service, currency, res) {
  const addresses = row.addresses ? JSON.parse(row.addresses) : {};
  const address = addresses[currency] || '';
  const balance = row.balance || (await getBalance(address)) || 0;
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
    return res.json({ success: false, error: 'Недостаточно средств' });
  }
  const number = `+${Math.floor(10000000000 + Math.random() * 90000000000)}`;
  const code = service === 'sms' ? `CODE-${Math.random().toString(36).slice(2, 8)}` : null;
  const last4 = service === 'call' ? number.slice(-4) : null;
  const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  db.run(
    'INSERT INTO purchases (telegram_id, country, resource, code) VALUES (?, ?, ?, ?)',
    [telegram_id, country, service, code || number],
    (err) => {
      if (err) {
        return res.status(500).json({ error: 'DB error' });
      }
      db.run(
        'UPDATE users SET balance = balance - ? WHERE telegram_id = ?',
        [price, telegram_id],
        (err) => {
          if (err) {
            return res.status(500).json({ error: 'DB error' });
          }
          res.json({
            success: true,
            number,
            code,
            last4,
            expiry,
            price: `${price} ${currency}`,
          });
        }
      );
    }
  );
}

module.exports = router;






NumberModals:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ country, service, language, onClose, selectedCrypto }) {
  const { tg, user } = useTelegram();
  const [numberData, setNumberData] = useState(null);
  const [isPurchased, setIsPurchased] = useState(false);
  const [currentCrypto, setCurrentCrypto] = useState(selectedCrypto || 'BTC');
  const [balance, setBalance] = useState('0.00000000');
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin' },
    { id: 'LTC', name: 'Litecoin' },
    { id: 'ETH', name: 'Ethereum' },
    { id: 'USDT', name: 'Tether' },
    { id: 'BNB', name: 'Binance Coin' },
    { id: 'AVAX', name: 'Avalanche' },
    { id: 'ADA', name: 'Cardano' },
    { id: 'SOL', name: 'Solana' },
  ];

  useEffect(() => {
    if (user?.id) {
      fetchBalance(currentCrypto);
    }
  }, [currentCrypto, user]);

  const fetchBalance = async (crypto) => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${crypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
    } catch (err) {
      console.error('Balance fetch error:', err);
      tg?.showPopup({ message: language === 'ru' ? `Ошибка получения баланса: ${err.message}` : `Balance fetch error: ${err.message}` });
    }
  };

  const ensureUser = async () => {
    try {
      await axios.post(
        `${API_URL}/select-crypto/${user.id}`,
        { crypto: currentCrypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
    } catch (err) {
      console.error('Ensure user error:', err);
    }
  };

  const texts = {
    ru: {
      title: service === 'sms' ? `SMS код и ${country.name_ru}` : `Услуга и ${country.name_ru}`,
      number: 'Номер:',
      code: 'Код:',
      last4: '4 последние цифры:',
      price: 'Цена:',
      balance: 'Баланс:',
      copy: 'Копировать',
      buy: 'Купить',
      notPurchased: 'Не куплено',
      success: 'Успешно! ✅',
      insufficientFunds: 'Не хватает средств!',
    },
    en: {
      title: service === 'sms' ? `SMS Code and ${country.name_en}` : `Service and ${country.name_en}`,
      number: 'Number:',
      code: 'Code:',
      last4: 'Last 4 digits:',
      price: 'Price:',
      balance: 'Balance:',
      copy: 'Copy',
      buy: 'Buy',
      notPurchased: 'Not purchased',
      success: 'Success! ✅',
      insufficientFunds: 'Insufficient funds!',
    },
  };

  const copyToClipboard = (text) => {
    if (text) {
      navigator.clipboard.writeText(text);
      tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
    }
  };

  // Конверсия евро/долларов в крипту (синхронизировано с бэкендом)
  const convertPriceToCrypto = (euroPrice) => {
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
    return (euroPrice * (rates[currentCrypto] || 1)).toFixed(8);
  };

  const getPrice = () => {
    let euroPrice;
    switch (service) {
      case 'sms':
        euroPrice = 0.012;
        break;
      case 'call':
        euroPrice = 0.020;
        break;
      case 'rent':
        euroPrice = 5;
        break;
      default:
        euroPrice = 0;
    }
    return `${convertPriceToCrypto(euroPrice)} ${currentCrypto}`;
  };

  const getPriceValue = () => {
    let euroPrice;
    switch (service) {
      case 'sms':
        euroPrice = 0.012;
        break;
      case 'call':
        euroPrice = 0.020;
        break;
      case 'rent':
        euroPrice = 5;
        break;
      default:
        euroPrice = 0;
    }
    return convertPriceToCrypto(euroPrice);
  };

  const handleBuy = async () => {
    if (!user?.id) {
      tg?.showPopup({ message: language === 'ru' ? 'Ошибка: Telegram ID не определён' : 'Error: Telegram ID not defined' });
      return;
    }
    const balanceNum = parseFloat(balance);
    const priceNum = parseFloat(getPriceValue());
    if (balanceNum < priceNum) {
      tg?.showPopup({ message: texts[language].insufficientFunds });
      return;
    }
    try {
      // Создать пользователя, если не существует
      await ensureUser();
      const res = await axios.post(
        `${API_URL}/buy-number`,
        { telegram_id: user.id, country: country.id, service, currency: currentCrypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (!res.data.success) {
        tg?.showPopup({ message: language === 'ru' ? res.data.error || 'Ошибка покупки' : res.data.error || 'Purchase error' });
        return;
      }
      setNumberData({ ...res.data, service });
      setIsPurchased(true);
      tg?.showPopup({ message: texts[language].success });
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({ message: language === 'ru' ? `Ошибка покупки: ${err.message}` : `Purchase error: ${err.message}` });
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      onClick={onClose}
    >
      <div
        className="bg-white p-6 rounded-lg shadow-lg max-w-md w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-xl font-bold mb-4 text-center">{texts[language].title}</h2>
        <div className="space-y-4">
          <div>
            <p className="font-semibold">{texts[language].number}</p>
            <div className="flex items-center">
              <span className="flex-1 p-2 bg-blue-100 rounded">
                {numberData?.number || texts[language].notPurchased}
              </span>
              {numberData?.number && (
                <button
                  className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                  onClick={() => copyToClipboard(numberData.number)}
                >
                  {texts[language].copy}
                </button>
              )}
            </div>
          </div>
          {service === 'sms' && (
            <div>
              <p className="font-semibold">{texts[language].code}</p>
              <div className="flex items-center">
                <span className="flex-1 p-2 bg-blue-100 rounded">
                  {numberData?.code || texts[language].notPurchased}
                </span>
                {numberData?.code && (
                  <button
                    className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                    onClick={() => copyToClipboard(numberData.code)}
                  >
                    {texts[language].copy}
                  </button>
                )}
              </div>
            </div>
          )}
          {service === 'call' && (
            <div>
              <p className="font-semibold">{texts[language].last4}</p>
              <div className="flex items-center">
                <span className="flex-1 p-2 bg-blue-100 rounded">
                  {numberData?.last4 || texts[language].notPurchased}
                </span>
                {numberData?.last4 && (
                  <button
                    className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                    onClick={() => copyToClipboard(numberData.last4)}
                  >
                    {texts[language].copy}
                  </button>
                )}
              </div>
            </div>
          )}
          <div className="flex justify-between">
            <div>
              <p className="font-semibold">{texts[language].price}</p>
              <p className="p-2 bg-blue-100 rounded">{getPrice()}</p>
            </div>
            <div className="relative">
              <p
                className="font-semibold cursor-pointer hover:text-blue-500"
                onClick={() => setShowCryptoDropdown(!showCryptoDropdown)}
              >
                {texts[language].balance}
              </p>
              <p className="p-2 bg-blue-100 rounded">
                {balance} {currentCrypto}
              </p>
              {showCryptoDropdown && (
                <div className="absolute z-10 w-full bg-white border border-gray-300 rounded shadow-lg mt-1 max-h-48 overflow-y-auto">
                  {cryptos.map((crypto) => (
                    <button
                      key={crypto.id}
                      className="w-full text-left px-4 py-2 hover:bg-gray-100"
                      onClick={() => {
                        setCurrentCrypto(crypto.id);
                        setShowCryptoDropdown(false);
                      }}
                    >
                      {crypto.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
        {!isPurchased && (
          <button
            className="w-full bg-blue-500 text-white p-2 rounded mt-4"
            onClick={handleBuy}
          >
            {texts[language].buy}
          </button>
        )}
      </div>
    </div>
  );
}

export default NumberModal;





App.js:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountryList from './components/CountryList';
import Profile from './components/Profile';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [language, setLanguage] = useState('ru');
  const [showCountryList, setShowCountryList] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [showLanguageModal, setShowLanguageModal] = useState(false);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [balance, setBalance] = useState('0.00000000');

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.BackButton.onClick(() => {
        if (showProfile) setShowProfile(false);
        else if (showCountryList) setShowCountryList(false);
      });
      if (showCountryList || showProfile) {
        tg.BackButton.show();
      } else {
        tg.BackButton.hide();
      }
      if (user?.id) {
        fetchBalance();
      }
    }
  }, [tg, showCountryList, showProfile, selectedCrypto, user]);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
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
    } catch (err) {
      console.error('Select crypto error:', err);
    }
  };

  const texts = {
    ru: {
      title: 'Виртуальные сим-карты',
      subtitle: 'Более 70 стран от 0.01 €',
      buy: 'Купить',
      purchases: 'Мои покупки',
    },
    en: {
      title: 'Virtual SIM Cards',
      subtitle: 'Over 70 countries from 0.01 €',
      buy: 'Buy',
      purchases: 'My Purchases',
    },
  };

  if (showProfile) {
    return (
      <Profile
        username={user?.first_name || 'User'}
        selectedCrypto={selectedCrypto}
        setSelectedCrypto={handleSelectCrypto}
        balance={balance}
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
          onClick={() => tg?.showPopup({ message: 'Покупки пока не реализованы' })}
        >
          {texts[language].purchases}
        </button>
      </div>
      {showLanguageModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
          onClick={() => setShowLanguageModal(false)}
        >
          <div
            className="bg-white p-4 rounded-lg max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold mb-4">
              {language === 'ru' ? 'Выберите язык' : 'Select Language'}
            </h2>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => {
                setLanguage('ru');
                setShowLanguageModal(false);
              }}
            >
              Русский
            </button>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => {
                setLanguage('en');
                setShowLanguageModal(false);
              }}
            >
              English
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;





ServiceSelector:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack, selectedCrypto }) {
  const { tg } = useTelegram();
  const [service, setService] = useState(null);
  const [showNumberModal, setShowNumberModal] = useState(false);

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const handleSelectService = (selectedService) => {
    setService(selectedService);
    setShowNumberModal(true);
  };

  const texts = {
    ru: { title: `Выберите сервис для ${country.name_ru}` },
    en: { title: `Select Service for ${country.name_en}` },
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">
        {texts[language].title}
      </h1>
      <div className="flex flex-col gap-2">
        {[
          { id: 'sms', name_ru: 'СМС', name_en: 'SMS' },
          { id: 'call', name_ru: 'Звонок', name_en: 'Call' },
          { id: 'rent', name_ru: 'Аренда номера', name_en: 'Number Rental' },
        ].map((s) => (
          <button
            key={s.id}
            className={`p-2 rounded ${service === s.id ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
            onClick={() => handleSelectService(s.id)}
          >
            {language === 'ru' ? s.name_ru : s.name_en}
          </button>
        ))}
      </div>
      {showNumberModal && (
        <NumberModal
          country={country}
          service={service}
          language={language}
          onClose={() => setShowNumberModal(false)}
          selectedCrypto={selectedCrypto}
        />
      )}
    </div>
  );
}

export default ServiceSelector;




