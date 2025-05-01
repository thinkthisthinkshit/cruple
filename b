Numb
import { useState, useEffect, useMemo } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import debounce from 'lodash.debounce';
import InsufficientFundsModal from './InsufficientFundsModal';

function NumberModal({ language, country, selectedCrypto, displayCurrency, onClose, setShowPurchaseResult, setPurchaseData, lastSelectedResource, setShowProfile }) {
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
        console.log('API /resources response:', res.data); // Лог для отладки
        const servicesData = Array.isArray(res.data.services) ? res.data.services : [];
        setServices(servicesData);
        setCryptoRates(res.data.rates || {});
        if (lastSelectedResource) {
          const lastService = servicesData.find((s) => s.id === lastSelectedResource);
          if (lastService) {
            console.log('Found last selected service:', lastService); // Лог для отладки
            setSelectedService(lastService);
          }
        }
      } catch (err) {
        console.error('Fetch services or rates error:', err);
        setError(language === 'ru' ? 'Ошибка загрузки данных' : 'Error loading data');
        setServices([]); // Устанавливаем пустой массив при ошибке
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
    if (!Array.isArray(services)) {
      console.warn('Services is not an array:', services); // Лог для отладки
      return [];
    }
    return services.filter((service) =>
      service?.name?.toLowerCase().includes(search.toLowerCase())
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
      console.log('Balance response:', balanceRes.data); // Лог для отладки
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
      console.log('Buy number response:', res.data); // Лог для отладки
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
                {filteredServices.length === 0 ? (
                  <p className="text-gray-600">{language === 'ru' ? 'Сервисы не найдены' : 'No services found'}</p>
                ) : (
                  filteredServices.map((service) => (
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
                  ))
                )}
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
            <p className="mb-4">{texts[language].title}: {selectedService?.name}</p>
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
            setShowProfile={setShowProfile}
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






App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountryList from './components/CountryList';
import Profile from './components/Profile';
import PurchaseResult from './components/PurchaseResult';
import PurchaseHistory from './components/PurchaseHistory';
import NumberModal from './components/NumberModal';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [language, setLanguage] = useState('ru');
  const [displayCurrency, setDisplayCurrency] = useState('RUB');
  const [showCountryList, setShowCountryList] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [showLanguageModal, setShowLanguageModal] = useState(false);
  const [showPurchaseResult, setShowPurchaseResult] = useState(false);
  const [showPurchaseHistory, setShowPurchaseHistory] = useState(false);
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [purchaseData, setPurchaseData] = useState(null);
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [balance, setBalance] = useState('0.00000000');
  const [displayBalance, setDisplayBalance] = useState('0.00');
  const [refreshPurchases, setRefreshPurchases] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [lastSelectedResource, setLastSelectedResource] = useState('other');
  const [selectedCountry, setSelectedCountry] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      console.log('Telegram user:', user);
      tg.BackButton.onClick(() => {
        if (showProfile) setShowProfile(false);
        else if (showCountryList) setShowCountryList(false);
        else if (showNumberModal) setShowNumberModal(false);
        else if (showPurchaseResult) {
          setShowPurchaseResult(false);
          setRefreshPurchases(true);
        } else if (showPurchaseHistory) setShowPurchaseHistory(false);
      });
      if (showCountryList || showProfile || showPurchaseResult || showPurchaseHistory || showNumberModal) {
        tg.BackButton.show();
      } else {
        tg.BackButton.hide();
      }
      if (user?.id) {
        checkUser();
      }
    }
  }, [tg, showCountryList, showProfile, showPurchaseResult, showPurchaseHistory, showNumberModal, selectedCrypto, user]);

  const checkUser = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      if (res.data.balance === '0.00000000' && !res.data.address) {
        setIsNewUser(true);
        setShowLanguageModal(true);
      } else {
        setLanguage(res.data.language || 'ru');
        setDisplayCurrency(res.data.display_currency || 'RUB');
        setBalance(res.data.balance || '0.00000000');
        setDisplayBalance(res.data.display_balance || '0.00');
        setLastSelectedResource(res.data.last_selected_resource || 'other');
      }
    } catch (err) {
      console.error('Check user error:', err);
    }
  };

  const handleSelectLanguage = async (lang) => {
    try {
      const res = await axios.post(
        `${API_URL}/set-language/${user.id}`,
        { language: lang },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setLanguage(lang);
      setDisplayCurrency(res.data.display_currency);
      setShowLanguageModal(false);
      setIsNewUser(false);
    } catch (err) {
      console.error('Set language error:', err);
    }
  };

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
      setDisplayBalance(res.data.display_balance || '0.00');
      setLastSelectedResource(res.data.last_selected_resource || 'other');
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

  const handleViewPurchase = (purchase) => {
    console.log('Viewing purchase:', purchase);
    setPurchaseData({
      ...purchase,
      purchase_id: purchase.id,
      country: purchase.country,
      service: purchase.service_type,
      resource: purchase.service,
      number: purchase.number,
      price: purchase.display_price || purchase.price,
      code: purchase.code,
      expiry: purchase.expiry || new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    });
    setShowPurchaseResult(true);
    setShowPurchaseHistory(false);
  };

  const handleGoToPurchases = () => {
    setShowPurchaseResult(false);
    setShowPurchaseHistory(true);
    setRefreshPurchases(true);
  };

  const handleBuyNumber = (country) => {
    if (!country?.id) {
      console.error('No country selected:', country);
      return;
    }
    setSelectedCountry(country);
    setShowNumberModal(true);
  };

  const texts = {
    ru: {
      title: 'Виртуальные сим-карты',
      subtitle: 'Более 70 стран от 0.01 €',
      buy: 'Купить',
      purchases: 'Мои покупки',
      selectLanguage: 'Выберите язык',
    },
    en: {
      title: 'Virtual SIM Cards',
      subtitle: 'Over 70 countries from 0.01 €',
      buy: 'Buy',
      purchases: 'My Purchases',
      selectLanguage: 'Select Language',
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
        balance={displayBalance}
        selectedCrypto={selectedCrypto}
        displayCurrency={displayCurrency}
        onGoToPurchases={handleGoToPurchases}
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
        balance={displayBalance}
        displayCurrency={displayCurrency}
        onBack={() => setShowProfile(false)}
        language={language}
      />
    );
  }

  if (showNumberModal && selectedCountry) {
    return (
      <NumberModal
        language={language}
        country={selectedCountry}
        selectedCrypto={selectedCrypto}
        displayCurrency={displayCurrency}
        onClose={() => setShowNumberModal(false)}
        setShowPurchaseResult={setShowPurchaseResult}
        setPurchaseData={setPurchaseData}
        lastSelectedResource={lastSelectedResource}
        setShowProfile={setShowProfile}
      />
    );
  }

  if (showCountryList) {
    return (
      <CountryList
        language={language}
        onBack={() => setShowCountryList(false)}
        selectedCrypto={selectedCrypto}
        displayCurrency={displayCurrency}
        setShowPurchaseResult={setShowPurchaseResult}
        setPurchaseData={setPurchaseData}
        lastSelectedResource={lastSelectedResource}
        onSelectCountry={handleBuyNumber}
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
          onClick={() => !isNewUser && setShowLanguageModal(false)}
        >
          <div
            className="bg-white p-4 rounded-lg max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold mb-4">
              {texts[language].selectLanguage}
            </h2>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => handleSelectLanguage('ru')}
            >
              Русский (RUB)
            </button>
            <button
              className="w-full mb-2 bg-gray-200 p-2 rounded"
              onClick={() => handleSelectLanguage('en')}
            >
              English (USD)
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;








