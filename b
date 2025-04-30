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
  const [balance, setBalance] = useState(null);

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
    try {
      const res = await axios.get(`${API_URL}/balance/${user?.id}?crypto=${selectedCrypto}`, {
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
    try {
      await axios.post(
        `${API_URL}/select-crypto/${user?.id}`,
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






ServiceSelector.jsx:
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
    if (!selectedCrypto) {
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Выберите валюту в профиле' : 'Select a currency in profile' });
      return;
    }
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






NumberModal.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ country, service, language, onClose, selectedCrypto }) {
  const { tg, user } = useTelegram();
  const [numberData, setNumberData] = useState(null);
  const [isPurchased, setIsPurchased] = useState(false);
  const [currentCrypto, setCurrentCrypto] = useState(selectedCrypto);
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
    fetchBalance(currentCrypto);
  }, [currentCrypto]);

  const fetchBalance = async (crypto) => {
    if (!user?.id) return;
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

  // Заглушка для конверсии евро/долларов в крипту
  const convertPriceToCrypto = (euroPrice) => {
    const rates = {
      USDT: 1, // 1 € ≈ 1 USDT
      BTC: 0.000015, // 1 € ≈ 0.000015 BTC
      LTC: 0.012, // 1 € ≈ 0.012 LTC
      ETH: 0.00033, // 1 € ≈ 0.00033 ETH
      BNB: 0.0017, // 1 € ≈ 0.0017 BNB
      AVAX: 0.028, // 1 € ≈ 0.028 AVAX
      ADA: 2.2, // 1 € ≈ 2.2 ADA
      SOL: 0.0067, // 1 € ≈ 0.0067 SOL
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
        euroPrice = 5; // Предполагаем 5$ ≈ 5€ для простоты
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
        { telegram_id: user.id, country: country.id, service, currency: currentCrypto },
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
            <div className="relative">
              <p
                className="font-semibold cursor-pointer"
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








