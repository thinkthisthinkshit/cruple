App.jsx:
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
      fetchBalance();
    }
  }, [tg, showCountryList, showProfile]);

  const fetchBalance = async () => {
    if (!user?.id) return;
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
      setSelectedCrypto(res.data.crypto || selectedCrypto);
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
          onClick={() => tg?.showPopup({ message: language === 'ru' ? 'Покупки пока не реализованы' : 'Purchases not implemented yet' })}
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






CountryList.jsx:
import { useState, useEffect } from 'react';
import axios from 'axios';
import ServiceSelector from './ServiceSelector';
import { useTelegram } from '../telegram';

function CountryList({ language, onBack, selectedCrypto }) {
  const { tg } = useTelegram();
  const [countries, setCountries] = useState([]);
  const [selectedCountry, setSelectedCountry] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchCountries = async () => {
      try {
        const res = await axios.get(`${API_URL}/countries`, {
          headers: { 'ngrok-skip-browser-warning': 'true' },
        });
        setCountries(res.data);
      } catch (err) {
        console.error('Fetch countries error:', err);
      }
    };
    fetchCountries();
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const texts = {
    ru: { title: 'Выберите страну' },
    en: { title: 'Select Country' },
  };

  const countryCodes = {
    us: '+1',
    ru: '+7',
    uk: '+44',
    fr: '+33',
    de: '+49',
    it: '+39',
    es: '+34',
    cn: '+86',
    jp: '+81',
    in: '+91',
    br: '+55',
    ca: '+1',
    au: '+61',
    za: '+27',
    mx: '+52',
    ar: '+54',
    cl: '+56',
    co: '+57',
    pe: '+51',
    ve: '+58',
    eg: '+20',
    ng: '+234',
    ke: '+254',
    gh: '+233',
    dz: '+213',
    ma: '+212',
    sa: '+966',
    ae: '+971',
    tr: '+90',
    pl: '+48',
    ua: '+380',
    by: '+375',
    kz: '+7',
    uz: '+998',
    ge: '+995',
    am: '+374',
    az: '+994',
    id: '+62',
    th: '+66',
    vn: '+84',
    ph: '+63',
    my: '+60',
    sg: '+65',
    kr: '+82',
    pk: '+92',
    bd: '+880',
    lk: '+94',
    np: '+977',
    mm: '+95',
    kh: '+855',
    la: '+856',
    se: '+46',
    no: '+47',
    fi: '+358',
    dk: '+45',
    nl: '+31',
    be: '+32',
    at: '+43',
    ch: '+41',
    gr: '+30',
    pt: '+351',
    ie: '+353',
    cz: '+420',
    sk: '+421',
    hu: '+36',
    ro: '+40',
    bg: '+359',
    hr: '+385',
    rs: '+381',
    ba: '+387',
  };

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
    return (euroPrice * (rates[selectedCrypto] || 1)).toFixed(8);
  };

  if (selectedCountry) {
    return (
      <ServiceSelector
        country={selectedCountry}
        language={language}
        onBack={() => setSelectedCountry(null)}
        selectedCrypto={selectedCrypto}
      />
    );
  }

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">
        {texts[language].title}
      </h1>
      <div className="space-y-2">
        {countries.map((country) => (
          <button
            key={country.id}
            className="flex justify-between items-center p-2 bg-gray-100 rounded w-full"
            onClick={() => setSelectedCountry(country)}
          >
            <span>
              {language === 'ru' ? country.name_ru : country.name_en} ({countryCodes[country.id] || '+'})
            </span>
            <span className="text-green-600">{convertPriceToCrypto(0.012)} {selectedCrypto}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

export default CountryList;





ServiceSelector.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack, selectedCrypto }) {
  const { tg, user } = useTelegram();
  const [service, setService] = useState(null);
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [balance, setBalance] = useState('0.00000000');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const handleSelectService = async (selectedService) => {
    if (!user?.id) {
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Ошибка: Telegram ID не определён' : 'Error: Telegram ID not defined' });
      return;
    }
    if (!selectedCrypto) {
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Выберите валюту в профиле' : 'Select a currency in profile' });
      return;
    }
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
      setService(selectedService);
      setShowNumberModal(true);
    } catch (err) {
      console.error('Balance fetch error:', err);
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? `Ошибка получения баланса: ${err.message}` : `Balance fetch error: ${err.message}` });
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
          balance={balance}
          selectedCrypto={selectedCrypto}
        />
      )}
    </div>
  );
}

export default ServiceSelector;




NumberModal.jsx:
import { useState } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ country, service, language, onClose, balance, selectedCrypto }) {
  const { tg, user } = useTelegram();
  const [numberData, setNumberData] = useState(null);
  const [isPurchased, setIsPurchased] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

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
      success: 'Успешно!',
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
      success: 'Success!',
      insufficientFunds: 'Insufficient funds!',
    },
  };

  const copyToClipboard = (text) => {
    if (text) {
      navigator.clipboard.writeText(text);
      tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
    }
  };

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
    return (euroPrice * (rates[selectedCrypto] || 1)).toFixed(8);
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
    return `${convertPriceToCrypto(euroPrice)} ${selectedCrypto}`;
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
    const balanceNum = parseFloat(balance);
    const priceNum = parseFloat(getPriceValue());
    if (balanceNum < priceNum) {
      tg?.showPopup({ message: texts[language].insufficientFunds });
      return;
    }
    if (!user?.id) {
      tg?.showPopup({ message: language === 'ru' ? 'Ошибка: Telegram ID не определён' : 'Error: Telegram ID not defined' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        { telegram_id: user.id, country: country.id, service, currency: selectedCrypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
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
            <div>
              <p className="font-semibold">{texts[language].balance}</p>
              <p className="p-2 bg-blue-100 rounded">{balance} {selectedCrypto}</p>
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






