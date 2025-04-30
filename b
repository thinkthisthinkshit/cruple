routes:
const express = require('express');
const db = require('./db');
const { generateAddress, getBalance } = require('./wallet');

const router = express.Router();

// Глобальный массив countries
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





