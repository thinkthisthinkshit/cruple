import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack }) {
  const { tg, user } = useTelegram();
  const [service, setService] = useState(null);
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [numberData, setNumberData] = useState(null);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const handleSelectService = (selectedService) => {
    setService(selectedService);
    setShowNumberModal(true);
    setNumberData(null); // Сбрасываем данные, пока не купили
  };

  const handleBuy = async () => {
    try {
      const res = await axios.post(
        `${API_URL}/buy-number`,
        { telegram_id: user?.id, country: country.id, service },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setNumberData({ ...res.data, service });
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({ message: `Ошибка покупки: ${err.message}` });
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
          numberData={numberData}
          service={service}
          language={language}
          onClose={() => setShowNumberModal(false)}
          onBuy={handleBuy}
        />
      )}
    </div>
  );
}

export default ServiceSelector;





import { useTelegram } from '../telegram';

function NumberModal({ numberData, service, language, onClose, onBuy }) {
  const { tg } = useTelegram();

  const texts = {
    ru: {
      title: 'Ваш номер',
      number: 'Номер:',
      code: 'Код:',
      last4: '4 последние цифры:',
      price: 'Цена:',
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ в месяц',
      copy: 'Копировать',
      buy: 'Купить',
      notPurchased: 'Не куплено',
    },
    en: {
      title: 'Your Number',
      number: 'Number:',
      code: 'Code:',
      last4: 'Last 4 digits:',
      price: 'Price:',
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ per month',
      copy: 'Copy',
      buy: 'Buy',
      notPurchased: 'Not purchased',
    },
  };

  const copyToClipboard = (text) => {
    if (text) {
      navigator.clipboard.writeText(text);
      tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
    }
  };

  const getPrice = () => {
    switch (service) {
      case 'sms':
        return texts[language].smsPrice;
      case 'call':
        return texts[language].callPrice;
      case 'rent':
        return texts[language].rentPrice;
      default:
        return '';
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center"
      onClick={onClose}
    >
      <div
        className="bg-white p-4 rounded-t-lg shadow-lg max-w-md w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-xl font-bold mb-2">{texts[language].title}</h2>
        <div className="space-y-2">
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
          <div>
            <p className="font-semibold">{texts[language].price}</p>
            <p className="p-2 bg-blue-100 rounded">{getPrice()}</p>
          </div>
        </div>
        <button
          className="w-full bg-blue-500 text-white p-2 rounded mt-4"
          onClick={onBuy}
        >
          {texts[language].buy}
        </button>
      </div>
    </div>
  );
}

export default NumberModal;


