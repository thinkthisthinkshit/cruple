import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ language, country, selectedCrypto, displayCurrency, onClose, setShowPurchaseResult, setPurchaseData, lastSelectedResource }) {
  const { tg, user } = useTelegram();
  const [services, setServices] = useState([]);
  const [search, setSearch] = useState('');
  const [selectedService, setSelectedService] = useState(null);
  const [step, setStep] = useState('select_service');
  const [error, setError] = useState('');
  const [cryptoRates, setCryptoRates] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  // Резервные курсы на случай сбоя API
  const fallbackRates = {
    btc: { usd: 60000, rub: 6000000 },
    usdt: { usd: 1, rub: 100 },
    ltc: { usd: 80, rub: 8000 },
    eth: { usd: 3000, rub: 300000 },
    bnb: { usd: 600, rub: 60000 },
    avax: { usd: 35, rub: 3500 },
    ada: { usd: 0.5, rub: 50 },
    sol: { usd: 150, rub: 15000 },
  };

  useEffect(() => {
    const fetchServicesAndRates = async () => {
      try {
        setIsLoading(true);

        // Fetch services
        const servicesRes = await axios.get(`${API_URL}/resources?language=${language}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setServices(servicesRes.data);

        // Fetch crypto rates with cache
        const cacheKey = 'crypto_rates';
        const cacheTimestampKey = 'crypto_rates_timestamp';
        const cacheDuration = 3600000; // 1 hour
        const cachedRates = localStorage.getItem(cacheKey);
        const cachedTimestamp = localStorage.getItem(cacheTimestampKey);
        const now = Date.now();

        let ratesData;
        if (cachedRates && cachedTimestamp && now - parseInt(cachedTimestamp) < cacheDuration) {
          ratesData = JSON.parse(cachedRates);
        } else {
          try {
            const ratesRes = await axios.get(
              'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,tether,litecoin,ethereum,binancecoin,avalanche-2,cardano,solana&vs_currencies=usd,rub'
            );
            ratesData = ratesRes.data;
            localStorage.setItem(cacheKey, JSON.stringify(ratesData));
            localStorage.setItem(cacheTimestampKey, now.toString());
          } catch (err) {
            console.warn('CoinGecko API failed, using fallback rates:', err);
            ratesData = fallbackRates;
          }
        }

        setCryptoRates(ratesData);

        // Set last selected service
        if (lastSelectedResource) {
          const lastService = servicesRes.data.find((s) => s.id === lastSelectedResource);
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

  const filteredServices = services.filter((service) =>
    service.name.toLowerCase().includes(search.toLowerCase())
  );

  const handleServiceSelect = (service) => {
    setSelectedService(service);
    setStep('select_type');
  };

  const handleBuy = async (serviceType) => {
    if (!user?.id || !selectedService) return;
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

  const getPriceDisplay = (serviceType) => {
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
    const fiatRate = cryptoRates?.[selectedCrypto.toLowerCase()]?.[displayCurrency.toLowerCase()] || 
                    fallbackRates[selectedCrypto.toLowerCase()]?.[displayCurrency.toLowerCase()] || 1;
    const displayPrice = (parseFloat(cryptoPrice) * fiatRate).toFixed(2);
    return isNaN(displayPrice) ? `0.00 ${displayCurrency}` : `${displayPrice} ${displayCurrency}`;
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
              value={search}
              onChange={(e) => setSearch(e.target.value)}
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
                      {texts[language].sms}: {getPriceDisplay('sms')}
                    </p>
                    <p className="text-sm text-gray-600">
                      {texts[language].call}: {getPriceDisplay('call')}
                    </p>
                    <p className="text-sm text-gray-600">
                      {texts[language].rent}: {getPriceDisplay('rent')}
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
                  onClick={() => handleBuy('sms')}
                >
                  {texts[language].sms} ({getPriceDisplay('sms')})
                </button>
                <button
                  className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
                  onClick={() => handleBuy('call')}
                >
                  {texts[language].call} ({getPriceDisplay('call')})
                </button>
                <button
                  className="w-full bg-blue-500 text-white px-4 py-2 rounded mb-2"
                  onClick={() => handleBuy('rent')}
                >
                  {texts[language].rent} ({getPriceDisplay('rent')})
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
