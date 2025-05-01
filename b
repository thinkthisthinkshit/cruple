NumberModal.js:
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
  const [cryptoRates, setCryptoRates] = useState({});
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    const fetchServicesAndRates = async () => {
      try {
        // Fetch services
        const servicesRes = await axios.get(`${API_URL}/resources?language=${language}`, {
          headers: {
            'ngrok-skip-browser-warning': 'true',
          },
        });
        setServices(servicesRes.data);

        // Fetch crypto rates
        const ratesRes = await axios.get('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,tether,litecoin,ethereum,binancecoin,avalanche-2,cardano,solana&vs_currencies=usd,rub');
        setCryptoRates(ratesRes.data);

        // Set last selected service
        if (lastSelectedResource) {
          const lastService = servicesRes.data.find((s) => s.id === lastSelectedResource);
          if (lastService) setSelectedService(lastService);
        }
      } catch (err) {
        console.error('Fetch services or rates error:', err);
        setError(language === 'ru' ? 'Ошибка загрузки сервисов' : 'Error loading services');
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
    const fiatRate = cryptoRates[selectedCrypto.toLowerCase()]?.[displayCurrency.toLowerCase()] || 1;
    const displayPrice = (parseFloat(cryptoPrice) * fiatRate).toFixed(2);
    return `${displayPrice} ${displayCurrency}`;
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
            {error && <p className="text-red-500 mt-2">{error}</p>}
            <button
              className="mt-4 w-full bg-gray-500 text-white px-4 py-2 rounded"
              onClick={onClose}
            >
              {texts[language].close}
            </button>
          </>
        ) : (
          <>
            <h2 className="text-xl font-bold mb-4">{texts[language].selectType}</h2>
            <p className="mb-4">{texts[language].title}: {selectedService.name}</p>
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
            {error && <p className="text-red-500 mt-2">{error}</p>}
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
          </>
        )}
      </div>
    </div>
  );
}

export default NumberModal;
