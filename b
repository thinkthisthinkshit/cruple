Purchase:
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
      if (!user?.id) return;
      try {
        const res = await axios.get(`${API_URL}/purchases/${user.id}`, {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setPurchases(res.data);
        if (refresh) setRefresh(false); // Сбросить флаг после обновления
      } catch (err) {
        console.error('Fetch purchases error:', err);
        tg?.showPopup({ message: language === 'ru' ? 'Ошибка загрузки покупок' : 'Error loading purchases' });
      }
    };
    fetchPurchases();
  }, [user, tg, language, refresh]);

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

router.get('/purchases/:telegram_id', (req, res) => {
  const { telegram_id } = req.params;
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
  db.all(
    'SELECT id, telegram_id, country, resource AS service, code, number, price, created_at FROM purchases WHERE telegram_id = ? ORDER BY created_at DESC',
    [telegram_id],
    (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'DB error' });
      }
      const purchases = rows.map((row) => ({
        ...row,
        country: countries.find((c) => c.id === row.country) || { id: row.country, name_en: row.country, name_ru: row.country },
        number: row.number || `+${Math.floor(10000000000 + Math.random() * 90000000000)}`,
        price: row.price || '0.00018000 BTC',
        created_at: row.created_at || new Date().toISOString(),
      }));
      res.json(purchases);
    }
  );
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
    'INSERT INTO purchases (telegram_id, country, resource, code, number, price, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [telegram_id, country, service, code || number, number, `${price} ${currency}`, new Date().toISOString()],
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
            country: countries.find((c) => c.id === country) || { id: country, name_en: country, name_ru: country },
            service,
          });
        }
      );
    }
  );
}

module.exports = router;






NumberModal.js:
import { useState } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({
  language,
  country,
  service,
  price,
  currency,
  onClose,
  setShowPurchaseResult,
  setPurchaseData,
}) {
  const { tg, user } = useTelegram();
  const [isLoading, setIsLoading] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  const handleBuy = async () => {
    if (!user?.id) {
      tg?.showPopup({ message: language === 'ru' ? 'Ошибка авторизации' : 'Authorization error' });
      return;
    }

    setIsLoading(true);
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        {
          telegram_id: user.id,
          country: country.id,
          service,
          currency,
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
          country,
          service,
          number: res.data.number,
          code: res.data.code,
          last4: res.data.last4,
          price: res.data.price,
          expiry: res.data.expiry,
        });
        setShowPurchaseResult(true);
      } else {
        tg?.showPopup({
          message: language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds',
        });
      }
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({
        message: language === 'ru' ? 'Ошибка покупки' : 'Purchase error',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const texts = {
    ru: {
      title: `Покупка номера (${country.name_ru})`,
      service: 'Сервис:',
      price: 'Цена:',
      buy: 'Купить',
      cancel: 'Отмена',
      loading: 'Обработка...',
    },
    en: {
      title: `Purchase Number (${country.name_en})`,
      service: 'Service:',
      price: 'Price:',
      buy: 'Buy',
      cancel: 'Cancel',
      loading: 'Processing...',
    },
  };

  const getServiceName = () => {
    const names = {
      sms: language === 'ru' ? 'СМС' : 'SMS',
      call: language === 'ru' ? 'Звонок' : 'Call',
      rent: language === 'ru' ? 'Аренда номера' : 'Number Rental',
    };
    return names[service] || service;
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
        <div className="mb-4">
          <p className="font-semibold">{texts[language].service}</p>
          <p>{getServiceName()}</p>
        </div>
        <div className="mb-4">
          <p className="font-semibold">{texts[language].price}</p>
          <p>{price} {currency}</p>
        </div>
        <div className="flex justify-between">
          <button
            className="bg-blue-500 text-white px-4 py-2 rounded"
            onClick={handleBuy}
            disabled={isLoading}
          >
            {isLoading ? texts[language].loading : texts[language].buy}
          </button>
          <button
            className="bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
            disabled={isLoading}
          >
            {texts[language].cancel}
          </button>
        </div>
      </div>
    </div>
  );
}

export default NumberModal;





App.jsx:
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
  const [showCountryList, setShowCountryList] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [showLanguageModal, setShowLanguageModal] = useState(false);
  const [showPurchaseResult, setShowPurchaseResult] = useState(false);
  const [showPurchaseHistory, setShowPurchaseHistory] = useState(false);
  const [purchaseData, setPurchaseData] = useState(null);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [balance, setBalance] = useState('0.00000000');
  const [refreshPurchases, setRefreshPurchases] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.BackButton.onClick(() => {
        if (showProfile) setShowProfile(false);
        else if (showCountryList) setShowCountryList(false);
        else if (showPurchaseResult) {
          setShowPurchaseResult(false);
          setRefreshPurchases(true); // Обновить покупки после возврата
        } else if (showPurchaseHistory) setShowPurchaseHistory(false);
      });
      if (showCountryList || showProfile || showPurchaseResult || showPurchaseHistory) {
        tg.BackButton.show();
      } else {
        tg.BackButton.hide();
      }
      if (user?.id) {
        fetchBalance();
      }
    }
  }, [tg, showCountryList, showProfile, showPurchaseResult, showPurchaseHistory, selectedCrypto, user]);

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

  if (showPurchaseResult) {
    return (
      <PurchaseResult
        language={language}
        purchaseData={purchaseData}
        onBack={() => {
          setShowPurchaseResult(false);
          setRefreshPurchases(true); // Обновить покупки после возврата
        }}
        balance={balance}
        selectedCrypto={selectedCrypto}
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
      />
    );
  }

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
        setShowPurchaseResult={setShowPurchaseResult}
        setPurchaseData={setPurchaseData}
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





