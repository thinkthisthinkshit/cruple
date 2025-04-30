import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack, selectedCrypto, setShowPurchaseResult, setPurchaseData }) {
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
    setService(selectedService);
    setShowNumberModal(true);
  };

  const texts = {
    ru: { title: country ? `Выберите сервис для ${country.name_ru}` : 'Выберите сервис' },
    en: { title: country ? `Select Service for ${country.name_en}` : 'Select Service' },
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
          language={language}
          onBack={() => setShowNumberModal(false)}
          selectedCrypto={selectedCrypto}
          setShowPurchaseResult={setShowPurchaseResult}
          setPurchaseData={setPurchaseData}
        />
      )}
    </div>
  );
}

export default ServiceSelector;







NUMBMODAL
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










COUNTRYLIST
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import ServiceSelector from './ServiceSelector';

function CountryList({ language, onBack, selectedCrypto, setShowPurchaseResult, setPurchaseData }) {
  const { tg } = useTelegram();
  const [countries, setCountries] = useState([]);
  const [search, setSearch] = useState('');
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
  }, []);

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const filteredCountries = countries.filter((country) =>
    language === 'ru'
      ? country.name_ru.toLowerCase().includes(search.toLowerCase())
      : country.name_en.toLowerCase().includes(search.toLowerCase())
  );

  const handleSelectCountry = (country) => {
    setSelectedCountry(country);
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
      {selectedCountry ? (
        <ServiceSelector
          country={selectedCountry}
          language={language}
          onBack={() => setSelectedCountry(null)}
          selectedCrypto={selectedCrypto}
          setShowPurchaseResult={setShowPurchaseResult}
          setPurchaseData={setPurchaseData}
        />
      ) : (
        <>
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
                className="w-full p-2 bg-gray-100 rounded text-left"
                onClick={() => handleSelectCountry(country)}
              >
                {language === 'ru' ? country.name_ru : country.name_en}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

export default CountryList;






