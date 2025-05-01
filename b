Insufficient:
import { useNavigate } from 'react-router-dom';

function InsufficientFundsModal({ language, data, onClose }) {
  const navigate = useNavigate();

  const texts = {
    ru: {
      title: 'Недостаточно средств',
      balance: 'Ваш баланс',
      price: 'Стоимость услуги',
      topUp: 'Пополнить',
    },
    en: {
      title: 'Insufficient Funds',
      balance: 'Your Balance',
      price: 'Service Cost',
      topUp: 'Top Up',
    },
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white p-6 rounded-lg max-w-sm w-full">
        <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
        <p className="mb-2">
          <span className="font-semibold">{texts[language].balance}:</span> {data.balance}
        </p>
        <p className="mb-4">
          <span className="font-semibold">{texts[language].price} ({data.serviceType}):</span> {data.price}
        </p>
        <button
          className="w-full bg-blue-500 text-white px-4 py-2 rounded"
          onClick={() => {
            onClose();
            navigate('/profile');
          }}
        >
          {texts[language].topUp}
        </button>
      </div>
    </div>
  );
}

export default InsufficientFundsModal;







NumberModal.js:
import { useState, useEffect, useMemo } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import debounce from 'lodash.debounce';
import InsufficientFundsModal from './InsufficientFundsModal';

function NumberModal({ language, country, selectedCrypto, displayCurrency, onClose, setShowPurchaseResult, setPurchaseData, lastSelectedResource }) {
  const { tg, user } = useTelegram();
  const [services, setServices] = useState([]);
  const [search, setSearch] = useState('');
  const [selectedService, setSelectedService] = useState(null);
  const [step, setStep] = useState('select_service');
  const [error, setError] = useState('');
  const [cryptoRates, setCryptoRates] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showInsufficientFunds, setShowInsufficientFunds] = useState(false);
  const [insufficientFundsData, setInsufficientFundsData] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchServicesAndRates = async () => {
      try {
        setIsLoading(true);
        const res = await axios.get(`${API_URL}/resources?language=${language}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setServices(res.data.services);
        setCryptoRates(res.data.rates);
        if (lastSelectedResource) {
          const lastService = res.data.services.find((s) => s.id === lastSelectedResource);
          if (lastService) setSelectedService(lastService);
        }
      } catch (err) {
        console.error('Fetch services or rates error:', err);
        setError(language === 'ru' ? 'Ошибка загрузки данных' : 'Error loading data');
      } finally {
        setIsLoading(false);
      }
    };
    fetchServicesAndRates();
  }, [API_URL, language, lastSelectedResource]);

  const debouncedSearch = debounce((value) => {
    setSearch(value);
  }, 300);

  const filteredServices = useMemo(() => {
    return services.filter((service) =>
      service.name.toLowerCase().includes(search.toLowerCase())
    );
  }, [services, search]);

  const handleServiceSelect = (service) => {
    setSelectedService(service);
    setStep('select_type');
  };

  const checkBalanceAndBuy = async (serviceType) => {
    if (!user?.id || !selectedService) return;
    try {
      // Fetch balance
      const balanceRes = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      });
      const { balance, display_balance } = balanceRes.data;

      // Calculate price
      const priceData = getPriceData(serviceType);
      const cryptoPrice = parseFloat(priceData.cryptoPrice);
      const displayPrice = priceData.displayPrice;

      if (parseFloat(balance) < cryptoPrice) {
        setInsufficientFundsData({
          balance: display_balance,
          price: `${displayPrice} ${displayCurrency}`,
          serviceType: texts[language][serviceType],
        });
        setShowInsufficientFunds(true);
        return;
      }

      // Proceed with purchase
      await handleBuy(serviceType);
    } catch (err) {
      console.error('Check balance error:', err);
      setError(language === 'ru' ? 'Ошибка проверки баланса' : 'Error checking balance');
    }
  };

  const handleBuy = async (serviceType) => {
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        {
          telegram_id: user.id,
          country: country.id,
          service: serviceType,
          currency: selectedCrypto,
          resource: selectedService.id,
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
          ...res.data,
          number: res.data.number,
          price: res.data.display_price || res.data.price,
          expiry: res.data.expiry,
          country,
          service: serviceType,
          resource: selectedService.id,
          purchase_id: res.data.purchase_id,
        });
        setShowPurchaseResult(true);
        onClose();
      } else {
        tg?.showPopup({
          message: res.data.error || (language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds'),
        });
      }
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({
        message: language === 'ru' ? 'Ошибка покупки' : 'Purchase error',
      });
    }
  };

  const getPriceData = (serviceType) => {
    const priceInCrypto = {
      sms: 0.012,
      call: 0.020,
      rent: 5,
    }[serviceType] || 0.012;

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

    const cryptoPrice = (priceInCrypto * (rates[selectedCrypto] || 1)).toFixed(8);
    const fiatRate = cryptoRates?.[selectedCrypto.toLowerCase()]?.[displayCurrency.toLowerCase()] || 1;
    const displayPrice = (parseFloat(cryptoPrice) * fiatRate).toFixed(2);
    return {
      cryptoPrice,
      displayPrice: isNaN(displayPrice) ? `0.00` : displayPrice,
    };
  };

  const texts = {
    ru: {
      title: 'Выберите сервис',
      search: 'Поиск сервиса...',
      selectType: 'Выберите тип услуги',
      sms: 'SMS',
      call: 'Звонки',
      rent: 'Аренда номера',
      back: 'Назад',
      close: 'Закрыть',
      error: 'Ошибка покупки',
      loading: 'Загрузка цен...',
    },
    en: {
      title: 'Select Service',
      search: 'Search service...',
      selectType: 'Select Service Type',
      sms: 'SMS',
      call: 'Calls',
      rent: 'Number Rental',
      back: 'Back',
      close: 'Close',
      error: 'Purchase error',
      loading: 'Loading prices...',
    },
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-4 rounded-lg max-w-sm w-full">
        {step === 'select_service' ? (
          <>
            <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
            <input
              type="text"
              className="w-full p-2 mb-4 border rounded"
              placeholder={texts[language].search}
              onChange={(e) => debouncedSearch(e.target.value)}
            />
            {isLoading ? (
              <div className="flex items-center justify-center">
                <div className="spinner border-t-2 border-blue-500 rounded-full w-5 h-5 animate-spin mr-2"></div>
                <p>{texts[language].loading}</p>
              </div>
            ) : (
              <div className="max-h-64 overflow-y-auto space-y-2">
                {filteredServices.map((service) => (
                  <div
                    key={service.id}
                    className={`p-2 border rounded cursor-pointer ${
                      selectedService?.id === service.id ? 'bg-blue-100' : ''
                    }`}
                    onClick={() => handleServiceSelect(service)}
                  >
                    <p className="font-semibold">{service.name}</p>
                    <p className="text-sm text-gray-600">
                      {texts[language].sms}: {getPriceData('sms').displayPrice} {displayCurrency}
                    </p>
                    <p className="text-sm text-gray-600">
                      {texts[language].call}: {getPriceData('call').displayPrice} {displayCurrency}
                    </p>
                    <p className="text-sm text-gray-600">
                      {texts[language].rent}: {getPriceData('rent').displayPrice} {displayCurrency}
                    </p>
                  </div>
                ))}
              </div>
            )}
            {error && <p className="text-red-500 mt-2">{error}</p>}
            {!isLoading && (
              <button
                className="mt-4 w-full bg-gray-500 text-white px-4 py-2 rounded"
                onClick={onClose}
              >
                {texts[language].close}
              </button>
            )}
          </>
        ) : (
          <>
            <h2 className="text-xl font-bold mb-4">{texts[language].selectType}</h2>
            <p className="mb-4">{texts[language].title}: {selectedService.name}</p>
            {isLoading ? (
              <div className="flex items-center justify-center">
                <div className="spinner border-t-2 border-blue-500 rounded-full w-5 h-5 animate-spin mr-2"></div>
                <p>{texts[language].loading}</p>
              </div>
            ) : (
              <>
                <button
                  className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
                  onClick={() => checkBalanceAndBuy('sms')}
                >
                  {texts[language].sms} ({getPriceData('sms').displayPrice} {displayCurrency})
                </button>
                <button
                  className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
                  onClick={() => checkBalanceAndBuy('call')}
                >
                  {texts[language].call} ({getPriceData('call').displayPrice} {displayCurrency})
                </button>
                <button
                  className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
                  onClick={() => checkBalanceAndBuy('rent')}
                >
                  {texts[language].rent} ({getPriceData('rent').displayPrice} {displayCurrency})
                </button>
              </>
            )}
            {error && <p className="text-red-500 mt-2">{error}</p>}
            {!isLoading && (
              <div className="flex gap-2 mt-4">
                <button
                  className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
                  onClick={() => setStep('select_service')}
                >
                  {texts[language].back}
                </button>
                <button
                  className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
                  onClick={onClose}
                >
                  {texts[language].close}
                </button>
              </div>
            )}
          </>
        )}
        {showInsufficientFunds && (
          <InsufficientFundsModal
            language={language}
            data={insufficientFundsData}
            onClose={() => setShowInsufficientFunds(false)}
          />
        )}
        <style>
          {`
            .spinner {
              border: 2px solid #f3f3f3;
              border-top: 2px solid #3498db;
              border-radius: 50%;
              width: 20px;
              height: 20px;
              animation: spin 1s linear infinite;
            }
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
          `}
        </style>
      </div>
    </div>
  );
}

export default NumberModal;









BalanceModal.js:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import QRCode from 'qrcode.react';

function BalanceModal({ language, selectedCrypto, displayCurrency, onClose }) {
  const { tg, user } = useTelegram();
  const [address, setAddress] = useState('');
  const [balance, setBalance] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchAddressAndBalance = async () => {
      try {
        // Fetch or generate address
        const addressRes = await axios.post(
          `${API_URL}/generate-address/${user.id}`,
          { crypto: selectedCrypto },
          {
            headers: {
              'ngrok-skip-browser-warning': 'true',
            },
          }
        );
        setAddress(addressRes.data.address);

        // Fetch balance
        const balanceRes = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setBalance(balanceRes.data);
      } catch (err) {
        console.error('Fetch address or balance error:', err);
      }
    };
    if (user?.id) {
      fetchAddressAndBalance();
    }
  }, [user, selectedCrypto]);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(address);
      tg?.showPopup({
        message: language === 'ru' ? 'Адрес скопирован' : 'Address copied',
      });
    } catch (err) {
      console.error('Copy address error:', err);
    }
  };

  const texts = {
    ru: {
      title: 'Пополнить баланс',
      address: 'Адрес кошелька',
      balance: 'Текущий баланс',
      copy: 'Скопировать',
      close: 'Закрыть',
    },
    en: {
      title: 'Top Up Balance',
      address: 'Wallet Address',
      balance: 'Current Balance',
      copy: 'Copy',
      close: 'Close',
    },
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg max-w-sm w-full">
        <h2 className="text-lg font-bold mb-4">{texts[language].title}</h2>
        {balance && (
          <p className="mb-4">
            <span className="font-semibold">{texts[language].balance}:</span>{' '}
            {balance.display_balance} {displayCurrency}
          </p>
        )}
        {address && (
          <>
            <p className="text-sm font-semibold mb-2">{texts[language].address}:</p>
            <p className="text-sm text-center mb-4 break-all">{address}</p>
            <QRCode value={`${selectedCrypto.toLowerCase()}:${address}`} className="mx-auto mb-4" />
          </>
        )}
        <div className="flex justify-between">
          <button
            className="bg-blue-500 text-white px-4 py-2 rounded"
            onClick={handleCopy}
          >
            {texts[language].copy}
          </button>
          <button
            className="bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
          >
            {texts[language].close}
          </button>
        </div>
      </div>
    </div>
  );
}

export default BalanceModal;










Profile.js:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import BalanceModal from './BalanceModal';

function Profile({ language, selectedCrypto, displayCurrency }) {
  const { tg, user } = useTelegram();
  const [balance, setBalance] = useState(null);
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchBalance = async () => {
      try {
        const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setBalance(res.data);
      } catch (err) {
        console.error('Fetch balance error:', err);
      }
    };
    if (user?.id) {
      fetchBalance();
    }
  }, [user, selectedCrypto]);

  const texts = {
    ru: {
      title: 'Профиль',
      balance: 'Баланс',
      crypto: 'Криптовалюта',
      currency: 'Валюта отображения',
      language: 'Язык',
    },
    en: {
      title: 'Profile',
      balance: 'Balance',
      crypto: 'Cryptocurrency',
      currency: 'Display Currency',
      language: 'Language',
    },
  };

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">{texts[language].title}</h1>
      {balance && (
        <div className="mb-4">
          <p>
            <span className="font-semibold">{texts[language].balance}:</span>{' '}
            {balance.display_balance} {displayCurrency}
          </p>
          <p>
            <span className="font-semibold">{texts[language].crypto}:</span>{' '}
            {selectedCrypto}
          </p>
          <p>
            <span className="font-semibold">{texts[language].currency}:</span>{' '}
            {displayCurrency}
          </p>
          <p>
            <span className="font-semibold">{texts[language].language}:</span>{' '}
            {language === 'ru' ? 'Русский' : 'English'}
          </p>
        </div>
      )}
      <button
        className="w-full bg-blue-500 text-white px-4 py-2 rounded"
        onClick={() => setShowBalanceModal(true)}
      >
        {texts[language].balance}
      </button>
      {showBalanceModal && (
        <BalanceModal
          language={language}
          selectedCrypto={selectedCrypto}
          displayCurrency={displayCurrency}
          onClose={() => setShowBalanceModal(false)}
        />
      )}
    </div>
  );
}

export default Profile;








App.jsx:
import { useState, useEffect } from 'react';
import { Routes, Route, useNavigate } from 'react-router-dom';
import { useTelegram } from './telegram';
import NumberModal from './components/NumberModal';
import PurchaseHistory from './components/PurchaseHistory';
import Profile from './components/Profile';

function App() {
  const { tg } = useTelegram();
  const navigate = useNavigate();
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [showPurchaseResult, setShowPurchaseResult] = useState(false);
  const [purchaseData, setPurchaseData] = useState(null);
  const [language, setLanguage] = useState('ru');
  const [country, setCountry] = useState(null);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [displayCurrency, setDisplayCurrency] = useState('RUB');

  useEffect(() => {
    tg.ready();
    tg.expand();

    // Handle back button for navigation
    tg.BackButton.onClick(() => {
      if (window.location.pathname === '/profile') {
        navigate('/');
      } else {
        navigate(-1);
      }
    });

    // Show/hide back button based on route
    if (window.location.pathname === '/profile') {
      tg.BackButton.show();
    } else {
      tg.BackButton.hide();
    }
  }, [tg, navigate]);

  const handleBuyNumber = (selectedCountry) => {
    setCountry(selectedCountry);
    setShowNumberModal(true);
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <Routes>
        <Route
          path="/"
          element={
            <PurchaseHistory
              language={language}
              selectedCrypto={selectedCrypto}
              displayCurrency={displayCurrency}
              onBuyNumber={handleBuyNumber}
              showPurchaseResult={showPurchaseResult}
              purchaseData={purchaseData}
              setShowPurchaseResult={setShowPurchaseResult}
            />
          }
        />
        <Route
          path="/profile"
          element={
            <Profile
              language={language}
              selectedCrypto={selectedCrypto}
              displayCurrency={displayCurrency}
            />
          }
        />
      </Routes>
      {showNumberModal && (
        <NumberModal
          language={language}
          country={country}
          selectedCrypto={selectedCrypto}
          displayCurrency={displayCurrency}
          onClose={() => setShowNumberModal(false)}
          setShowPurchaseResult={setShowPurchaseResult}
          setPurchaseData={setPurchaseData}
        />
      )}
    </div>
  );
}

export default App;





