NumberModal.js:
import { useState } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function NumberModal({ country, service, language, onClose, balance }) {
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
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ в месяц',
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
      smsPrice: '0.012 €',
      callPrice: '0.020 €',
      rentPrice: '5$ per month',
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

  const getPriceValue = () => {
    switch (service) {
      case 'sms':
        return 0.012;
      case 'call':
        return 0.020;
      case 'rent':
        return 5;
      default:
        return 0;
    }
  };

  const handleBuy = async () => {
    const balanceNum = parseFloat(balance);
    const priceNum = getPriceValue();
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
        { telegram_id: user.id, country: country.id, service },
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
              <p className="p-2 bg-blue-100 rounded">{balance} USDT</p>
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



ServiceSelector.js:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack }) {
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
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=USDT`, {
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
        />
      )}
    </div>
  );
}

export default ServiceSelector;



















Profile.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import BalanceModal from './BalanceModal';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const { tg, user } = useTelegram();
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);
  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositAddress, setDepositAddress] = useState('');
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    console.log('Profile user:', user);
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin', balance: '0.00000000' },
    { id: 'LTC', name: 'Litecoin', balance: '0.00000000' },
    { id: 'ETH', name: 'Ethereum', balance: '0.00000000' },
    { id: 'USDT', name: 'Tether', balance: '0.00000000' },
    { id: 'BNB', name: 'Binance Coin', balance: '0.00000000' },
    { id: 'AVAX', name: 'Avalanche', balance: '0.00000000' },
    { id: 'ADA', name: 'Cardano', balance: '0.00000000' },
    { id: 'SOL', name: 'Solana', balance: '0.00000000' },
  ];

  const toggleCryptoDropdown = () => {
    setShowCryptoDropdown(!showCryptoDropdown);
  };

  const handleDeposit = async () => {
    if (!user?.id) {
      console.error('Telegram user ID is undefined');
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Ошибка: Telegram ID не определён' : 'Error: Telegram ID not defined' });
      return;
    }
    console.log('Sending request for telegram_id:', user.id, 'crypto:', selectedCrypto);
    try {
      const res = await axios.post(
        `${API_URL}/generate-address/${user.id}`,
        { crypto: selectedCrypto },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      setDepositAddress(res.data.address);
      setShowDepositModal(true);
    } catch (err) {
      console.error('Generate address error:', err);
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? `Ошибка генерации адреса: ${err.message}` : `Address generation error: ${err.message}` });
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(depositAddress);
    tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Адрес скопирован!' : 'Address copied!' });
  };

  const selectedCryptoData = cryptos.find((c) => c.id === selectedCrypto);

  return (
    <div className="p-4 max-w-md mx-auto">
      <div className="flex justify-center items-center mb-4 gap-2">
        <div className="relative max-w-xs w-full">
          <button
            className="w-full bg-gray-200 bg-opacity-50 text-gray-800 border border-gray-600 border-opacity-50 px-4 py-2 rounded flex justify-between items-center"
            onClick={toggleCryptoDropdown}
          >
            <span>{selectedCryptoData ? `${selectedCryptoData.name} (${selectedCryptoData.balance})` : 'Select Crypto'}</span>
            <svg
              className={`w-4 h-4 transform ${showCryptoDropdown ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          {showCryptoDropdown && (
            <div className="absolute z-10 w-full bg-white border border-gray-300 rounded shadow-lg mt-1 max-h-64 overflow-y-auto">
              {cryptos.map((crypto) => (
                <button
                  key={crypto.id}
                  className="w-full text-left px-4 py-2 hover:bg-gray-100"
                  onClick={() => {
                    setSelectedCrypto(crypto.id);
                    setShowCryptoDropdown(false);
                  }}
                >
                  {crypto.name} ({crypto.balance})
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded"
          onClick={handleDeposit}
        >
          {tg?.languageCode === 'ru' ? 'Пополнить' : 'Deposit'}
        </button>
      </div>
      <h1 className="text-2xl font-bold text-center mb-4">{username}</h1>
      {showDepositModal && (
        <BalanceModal
          address={depositAddress}
          crypto={selectedCrypto}
          onClose={() => setShowDepositModal(false)}
          onCopy={copyToClipboard}
        />
      )}
    </div>
  );
}

export default Profile;







BalanceModal.jsx:
import QRCode from 'qrcode.react';
import { useTelegram } from '../telegram';

function BalanceModal({ address, crypto, onClose, onCopy }) {
  const { tg } = useTelegram();

  const getQrValue = () => {
    switch (crypto) {
      case 'BTC':
        return `bitcoin:${address}`;
      case 'LTC':
        return `litecoin:${address}`;
      case 'ETH':
      case 'USDT':
      case 'BNB':
      case 'AVAX':
        return `ethereum:${address}`;
      case 'ADA':
        return `cardano:${address}`;
      case 'SOL':
        return `solana:${address}`;
      default:
        return address;
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg max-w-sm w-full">
        <h2 className="text-lg font-bold mb-4">
          {tg?.languageCode === 'ru' ? 'Пополнить баланс' : 'Deposit Balance'}
        </h2>
        <p className="text-sm mb-2">
          {tg?.languageCode === 'ru' ? `Адрес для ${crypto}` : `Address for ${crypto}`}
        </p>
        <QRCode value={getQrValue()} className="mx-auto mb-4" size={160} />
        <p className="text-sm text-center mb-4 break-all">{address}</p>
        <div className="flex justify-between">
          <button
            className="bg-blue-500 text-white px-4 py-2 rounded"
            onClick={onCopy}
          >
            {tg?.languageCode === 'ru' ? 'Скопировать' : 'Copy'}
          </button>
          <button
            className="bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
          >
            {tg?.languageCode === 'ru' ? 'Закрыть' : 'Close'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default BalanceModal;





ServiceSelector.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';
import NumberModal from './NumberModal';

function ServiceSelector({ country, language, onBack }) {
  const { tg, user } = useTelegram();
  const [service, setService] = useState(null);
  const [showNumberModal, setShowNumberModal] = useState(false);
  const [numberData, setNumberData] = useState(null);
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
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=USDT`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance || '0.00000000');
      setService(selectedService);
      setShowNumberModal(true);
      setNumberData(null);
    } catch (err) {
      console.error('Balance fetch error:', err);
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? `Ошибка получения баланса: ${err.message}` : `Balance fetch error: ${err.message}` });
    }
  };

  const handleBuy = async () => {
    const balanceNum = parseFloat(balance);
    const priceNum = service === 'sms' ? 0.012 : service === 'call' ? 0.020 : 5;
    if (balanceNum < priceNum) {
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Недостаточно средств!' : 'Insufficient funds!' });
      return;
    }
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
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? 'Услуга заказана!' : 'Service ordered!' });
    } catch (err) {
      console.error('Buy number error:', err);
      tg?.showPopup({ message: tg?.languageCode === 'ru' ? `Ошибка покупки: ${err.message}` : `Purchase error: ${err.message}` });
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
          balance={balance}
        />
      )}
    </div>
  );
}

export default ServiceSelector;





NumberModal.jsx:
import { useTelegram } from '../telegram';

function NumberModal({ numberData, service, language, onClose, onBuy, balance }) {
  const { tg } = useTelegram();

  const texts = {
    ru: {
      title: 'Ваш номер',
      number: 'Номер:',
      code: 'Код:',
      last4: '4 последние цифры:',
      price: 'Цена:',
      balance: 'Баланс:',
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
      balance: 'Balance:',
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
            <p className="font-semibold">{texts[language].balance}</p>
            <p className="p-2 bg-blue-100 rounded">{balance} USDT</p>
          </div>
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







CountryList.jsx:
import { useState, useEffect } from 'react';
import axios from 'axios';
import ServiceSelector from './ServiceSelector';
import { useTelegram } from '../telegram';

function CountryList({ language, onBack }) {
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

  if (selectedCountry) {
    return (
      <ServiceSelector
        country={selectedCountry}
        language={language}
        onBack={() => setSelectedCountry(null)}
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
            <span className="text-green-600">0.012 €</span>
          </button>
        ))}
      </div>
    </div>
  );
}

export default CountryList;





Wallet.js:
const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const { BIP32Factory } = require('bip32');
const ecc = require('tiny-secp256k1');
const { Wallet } = require('ethers');
const CardanoWasm = require('@emurgo/cardano-serialization-lib-nodejs');
const { Keypair } = require('@solana/web3.js');
require('dotenv').config();

const SEED_PHRASE = process.env.SEED_PHRASE;

if (!SEED_PHRASE) {
  throw new Error('SEED_PHRASE not set in .env');
}

if (!bip39.validateMnemonic(SEED_PHRASE)) {
  throw new Error('Invalid SEED_PHRASE');
}

const bip32 = BIP32Factory(ecc);

const getDerivationPath = (coinType, userIndex) => {
  return `m/44'/${coinType}'/0'/0/${userIndex}`;
};

const cryptoCoinTypes = {
  BTC: 0,
  LTC: 2,
  ETH: 60,
  USDT: 60,
  BNB: 60,
  AVAX: 60,
  ADA: 1815,
  SOL: 501,
};

const generateAddress = async (telegram_id, crypto) => {
  try {
    console.log(`Generating address for telegram_id: ${telegram_id}, crypto: ${crypto}`);
    const userIndex = parseInt(telegram_id, 10) % 1000000;
    const seed = await bip39.mnemonicToSeed(SEED_PHRASE);
    console.log(`Seed generated, length: ${seed.length}`);

    if (['BTC', 'LTC'].includes(crypto)) {
      const network = crypto === 'BTC' ? bitcoin.networks.bitcoin : bitcoin.networks.litecoin;
      console.log(`Using network: ${crypto === 'BTC' ? 'bitcoin' : 'litecoin'}`);
      const root = bip32.fromSeed(seed, network);
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      console.log(`Derivation path: ${path}`);
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({ pubkey: child.publicKey, network });
      console.log(`Generated address: ${address}`);
      return address;
    } else if (['ETH', 'USDT', 'BNB', 'AVAX'].includes(crypto)) {
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      console.log(`Wallet:`, Wallet);
      const wallet = Wallet.fromMnemonic(SEED_PHRASE, path);
      console.log(`Generated ETH-based address: ${wallet.address}`);
      return wallet.address;
    } else if (crypto === 'ADA') {
      const rootKey = CardanoWasm.Bip32PrivateKey.from_bip39_entropy(seed, Buffer.from(''));
      const accountKey = rootKey.derive(1852).derive(1815).derive(0);
      const paymentKey = accountKey.derive(0).derive(0).to_public();
      const stakeKey = accountKey.derive(2).derive(0).to_public();
      const address = CardanoWasm.BaseAddress.new(
        CardanoWasm.NetworkInfo.mainnet().network_id(),
        CardanoWasm.StakeCredential.from_keyhash(paymentKey.to_raw_key().hash()),
        CardanoWasm.StakeCredential.from_keyhash(stakeKey.to_raw_key().hash())
      ).to_address().to_bech32();
      console.log(`Generated ADA address: ${address}`);
      return address;
    } else if (crypto === 'SOL') {
      const keypair = Keypair.fromSeed(seed.slice(0, 32));
      const address = keypair.publicKey.toBase58();
      console.log(`Generated SOL address: ${address}`);
      return address;
    } else {
      console.log(`Unsupported crypto: ${crypto}`);
      throw new Error(`Unsupported cryptocurrency: ${crypto}`);
    }
  } catch (error) {
    console.error(`Error generating address for ${crypto}:`, error);
    throw new Error(`Failed to generate address for ${crypto}`);
  }
};

const getBalance = async (address) => {
  console.log(`Fetching balance for address: ${address}`);
  return 0;
};

module.exports = { generateAddress, getBalance };










