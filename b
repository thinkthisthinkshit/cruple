NumberModal:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import ServiceSelector from './ServiceSelector';

function NumberModal({ language, country, onBack, selectedCrypto, setShowPurchaseResult, setPurchaseData }) {
  const { tg, user } = useTelegram();
  const [service, setService] = useState('sms');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const handleBuy = async () => {
    if (!user?.id) {
      tg?.showPopup({ message: language === 'ru' ? 'Ошибка авторизации' : 'Authorization error' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        {
          telegram_id: user.id,
          country: country.id,
          service,
          currency: selectedCrypto,
        },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (res.data.success) {
        setPurchaseData(res.data);
        setShowPurchaseResult(true);
      } else {
        tg?.showPopup({
          message: language === 'ru' ? res.data.error || 'Недостаточно средств' : res.data.error || 'Insufficient funds',
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
      title: 'Покупка номера',
      country: 'Страна:',
      service: 'Сервис:',
      price: 'Цена:',
      buy: 'Купить',
    },
    en: {
      title: 'Purchase Number',
      country: 'Country:',
      service: 'Service:',
      price: 'Price:',
      buy: 'Buy',
    },
  };

  const getPrice = () => {
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
    const price = (priceInCrypto * (rates[selectedCrypto] || 1)).toFixed(8);
    return `${price} ${selectedCrypto}`;
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      <div className="p-4 bg-gray-100 rounded-lg shadow">
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].country}</p>
          <p>{language === 'ru' ? country.name_ru : country.name_en}</p>
        </div>
        <div className="mb-2">
          <p className="font-semibold mb-1">{texts[language].service}</p>
          <ServiceSelector language={language} selectedService={service} setService={setService} />
        </div>
        <div className="flex justify-between mb-4">
          <p className="font-semibold">{texts[language].price}</p>
          <p>{getPrice()}</p>
        </div>
        <button
          className="w-full bg-blue-500 text-white px-4 py-2 rounded"
          onClick={handleBuy}
        >
          {texts[language].buy}
        </button>
      </div>
    </div>
  );
}

export default NumberModal;








App.jsx
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

  const handleViewPurchase = (purchase) => {
    setPurchaseData({
      ...purchase,
      purchase_id: purchase.id,
      country: purchase.country,
      service: purchase.service,
      number: purchase.number,
      price: purchase.price,
      code: purchase.code,
      expiry: purchase.expiry || new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    });
    setShowPurchaseResult(true);
    setShowPurchaseHistory(false);
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
          setRefreshPurchases(true);
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









HISTORY
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
      if (!user?.id) {
        console.log('No user ID available');
        return;
      }
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
        console.error('Fetch purchases error:', err.response?.data || err.message);
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
      status: 'Статус:',
      active: 'Активна',
      completed: 'Завершена',
      view: 'Просмотреть',
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
      status: 'Status:',
      active: 'Active',
      completed: 'Completed',
      view: 'View',
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
              <div className="flex justify-between items-center">
                <p className="font-semibold">{texts[language].status}</p>
                <div className="flex items-center">
                  <span
                    className={`w-3 h-3 rounded-full mr-2 ${
                      purchase.status === 'active' ? 'bg-green-500' : 'bg-red-500'
                    }`}
                  ></span>
                  <p>{purchase.status === 'active' ? texts[language].active : texts[language].completed}</p>
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






