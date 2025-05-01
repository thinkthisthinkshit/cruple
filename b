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
        const servicesData = Array.isArray(res.data) ? res.data : [];
        setServices(servicesData);
        setCryptoRates(res.data.rates || {}); // rates пока не возвращаются API, оставляем заглушку
        if (lastSelectedResource) {
          const lastService = servicesData.find((s) => s.id === lastSelectedResource);
          if (lastService) {
            console.log('Found last selected service:', lastService); // Лог для отладки
            setSelectedService(lastService);
          }
        }
      } catch (err) {
        console.error('Fetch services error:', err);
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
      noServices: 'Сервисы не найдены',
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
      noServices: 'No services found',
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
                  <p className="text-gray-600">{texts[language].noServices}</p>
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








import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import NumberModal from './NumberModal';
import axios from 'axios';

function CountryList({ language, onBack, selectedCrypto, displayCurrency, setShowPurchaseResult, setPurchaseData, lastSelectedResource, onSelectCountry }) {
  const { tg } = useTelegram();
  const [countries, setCountries] = useState([]);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    console.log('CountryList props:', { language, selectedCrypto, displayCurrency, lastSelectedResource }); // Лог для отладки
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    const fetchCountries = async () => {
      try {
        const res = await axios.get(`${API_URL}/countries`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        console.log('API /countries response:', res.data); // Лог для отладки
        setCountries(res.data);
      } catch (err) {
        console.error('Fetch countries error:', err);
      }
    };
    fetchCountries();
  }, [API_URL]);

  const filteredCountries = countries.filter((country) =>
    language === 'ru'
      ? country.name_ru.toLowerCase().includes(search.toLowerCase())
      : country.name_en.toLowerCase().includes(search.toLowerCase())
  );

  const handleCountrySelect = (country) => {
    console.log('Selected country:', country); // Лог для отладки
    setSelectedCountry(country);
    onSelectCountry(country);
  };

  const texts = {
    ru: {
      title: 'Выберите страну',
      search: 'Поиск...',
    },
    en: {
      title: 'Select Country',
      search: 'Search...',
    },
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      <input
        type="text"
        className="w-full p-2 mb-4 border rounded"
        placeholder={texts[language].search}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="space-y-2">
        {filteredCountries.map((country) => (
          <button
            key={country.id}
            className="w-full p-2 text-left bg-gray-100 rounded hover:bg-gray-200"
            onClick={() => handleCountrySelect(country)}
          >
            {language === 'ru' ? country.name_ru : country.name_en}
          </button>
        ))}
      </div>
      {selectedCountry && (
        <NumberModal
          language={language}
          country={selectedCountry}
          selectedCrypto={selectedCrypto}
          displayCurrency={displayCurrency}
          onClose={() => setSelectedCountry(null)}
          setShowPurchaseResult={setShowPurchaseResult}
          setPurchaseData={setPurchaseData}
          lastSelectedResource={lastSelectedResource}
          setShowProfile={setShowProfile}
        />
      )}
    </div>
  );
}

export default CountryList;
