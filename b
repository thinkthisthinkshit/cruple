function ServiceSelector({ language, selectedService, setService }) {
  const services = [
    { id: 'sms', name_ru: 'СМС', name_en: 'SMS' },
    { id: 'call', name_ru: 'Звонок', name_en: 'Call' },
    { id: 'rent', name_ru: 'Аренда номера', name_en: 'Number Rental' },
  ];

  return (
    <div className="flex flex-col gap-2">
      {services.map((service) => (
        <button
          key={service.id}
          className={`px-4 py-2 rounded ${
            selectedService === service.id ? 'bg-blue-500 text-white' : 'bg-gray-200'
          }`}
          onClick={() => setService(service.id)}
        >
          {language === 'ru' ? service.name_ru : service.name_en}
        </button>
      ))}
    </div>
  );
}

export default ServiceSelector;






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
