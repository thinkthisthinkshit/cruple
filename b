ServiceSelector.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack }) {
  const { tg, user } = useTelegram();
  const [service, setService] = useState(null);
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [numberData, setNumberData] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.MainButton.hide();
      if (service) {
        tg.MainButton.setText(language === 'ru' ? 'Купить' : 'Buy').show().onClick(handleBuy);
      }
    }
    return () => tg?.MainButton.hide();
  }, [tg, service, language]);

  const services = [
    { id: 'sms', name_ru: 'СМС', name_en: 'SMS' },
    { id: 'call', name_ru: 'Звонок', name_en: 'Call' },
    { id: 'rent', name_ru: 'Аренда номера', name_en: 'Number Rental' },
  ];

  const handleBuy = async () => {
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        { telegram_id: user?.id, country: country.id, service },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setNumberData({ ...res.data, service });
      setShowNumberModal(true);
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({ message: `Ошибка покупки: ${err.message}` });
    }
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
        {services.map((s) => (
          <button
            key={s.id}
            className={`p-2 rounded ${service === s.id ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
            onClick={() => setService(s.id)}
          >
            {language === 'ru' ? s.name_ru : s.name_en}
          </button>
        ))}
      </div>
      {showNumberModal && numberData && (
        <NumberModal
          numberData={numberData}
          language={language}
          onClose={() => setShowNumberModal(false)}
        />
      )}
    </div>
  );
}

export default ServiceSelector;





NumberModal.jsx:
import { useTelegram } from '../telegram';

function NumberModal({ numberData, language, onClose }) {
  const { tg } = useTelegram();

  const texts = {
    ru: {
      title: 'Ваш номер',
      number: 'Номер:',
      code: 'Код:',
      last4: '4 последние цифры:',
      price: 'Цена:',
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ в месяц',
      copy: 'Копировать',
      close: 'Закрыть',
    },
    en: {
      title: 'Your Number',
      number: 'Number:',
      code: 'Code:',
      last4: 'Last 4 digits:',
      price: 'Price:',
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ per month',
      copy: 'Copy',
      close: 'Close',
    },
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
  };

  const getPrice = () => {
    switch (numberData.service) {
      case 'sms':
        return texts[language].smsPrice;
      case 'call':
        return texts[language].callPrice;
      case 'rent':
        return texts[language].rentPrice;
      default:
        return '';
    }
  };

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white p-4 rounded-t-lg shadow-lg max-w-md mx-auto">
      <h2 className="text-xl font-bold mb-2">{texts[language].title}</h2>
      <div className="space-y-2">
        <div>
          <p className="font-semibold">{texts[language].number}</p>
          <div className="flex items-center">
            <span className="flex-1 p-2 bg-blue-100 rounded">{numberData.number}</span>
            <button
              className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
              onClick={() => copyToClipboard(numberData.number)}
            >
              {texts[language].copy}
            </button>
          </div>
        </div>
        {numberData.service === 'sms' && numberData.code && (
          <div>
            <p className="font-semibold">{texts[language].code}</p>
            <div className="flex items-center">
              <span className="flex-1 p-2 bg-blue-100 rounded">{numberData.code}</span>
              <button
                className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                onClick={() => copyToClipboard(numberData.code)}
              >
                {texts[language].copy}
              </button>
            </div>
          </div>
        )}
        {numberData.service === 'call' && numberData.last4 && (
          <div>
            <p className="font-semibold">{texts[language].last4}</p>
            <div className="flex items-center">
              <span className="flex-1 p-2 bg-blue-100 rounded">{numberData.last4}</span>
              <button
                className="ml-2 bg-blue-500 text-white px-3 py-1 rounded"
                onClick={() => copyToClipboard(numberData.last4)}
              >
                {texts[language].copy}
              </button>
            </div>
          </div>
        )}
        <div>
          <p className="font-semibold">{texts[language].price}</p>
          <p className="p-2 bg-blue-100 rounded">{getPrice()}</p>
        </div>
      </div>
      <button
        className="w-full bg-red-500 text-white p-2 rounded mt-4"
        onClick={onClose}
      >
        {texts[language].close}
      </button>
    </div>
  );
}

export default NumberModal;




routes.js:
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





