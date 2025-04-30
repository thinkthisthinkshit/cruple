Purchase:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function PurchaseHistory({ language, onBack }) {
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
      } catch (err) {
        console.error('Fetch purchases error:', err);
        tg?.showPopup({ message: language === 'ru' ? 'Ошибка загрузки покупок' : 'Error loading purchases' });
      }
    };
    fetchPurchases();
  }, [user, tg, language]);

  const texts = {
    ru: {
      title: 'Мои покупки',
      number: 'Номер:',
      country: 'Страна:',
      service: 'Сервис:',
      price: 'Цена:',
      date: 'Дата:',
      empty: 'Покупок пока нет',
    },
    en: {
      title: 'My Purchases',
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


app.js:
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

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.BackButton.onClick(() => {
        if (showProfile) setShowProfile(false);
        else if (showCountryList) setShowCountryList(false);
        else if (showPurchaseResult) setShowPurchaseResult(false);
        else if (showPurchaseHistory) setShowPurchaseHistory(false);
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
        onBack={() => setShowPurchaseResult(false)}
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



db.js:
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./database.db');

db.serialize(() => {
  // Таблица users
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      telegram_id TEXT PRIMARY KEY,
      wallet_index INTEGER,
      address TEXT,
      addresses TEXT,
      balance REAL,
      crypto TEXT
    )
  `);

  // Таблица purchases
  db.run(`
    CREATE TABLE IF NOT EXISTS purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      telegram_id TEXT,
      country TEXT,
      resource TEXT,
      code TEXT,
      number TEXT,
      price TEXT,
      created_at TEXT
    )
  `);

  // Миграция: добавление новых полей, если они отсутствуют
  db.run(`ALTER TABLE purchases ADD COLUMN number TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) console.error('Migration error (number):', err);
  });
  db.run(`ALTER TABLE purchases ADD COLUMN price TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) console.error('Migration error (price):', err);
  });
  db.run(`ALTER TABLE purchases ADD COLUMN created_at TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) console.error('Migration error (created_at):', err);
  });
});

module.exports = db;



