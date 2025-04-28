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
      const res = await axios.get(`${API_URL}/balance/${user?.id}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance);
      setSelectedCrypto(res.data.crypto);
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
    return <CountryList language={language} onBack={() => setShowCountryList(false)} />;
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






import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const { tg } = useTelegram();
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin' },
    { id: 'ETH', name: 'Ethereum' },
    { id: 'USDT', name: 'Tether' },
  ];

  const toggleCryptoDropdown = () => {
    setShowCryptoDropdown(!showCryptoDropdown);
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <div className="relative mb-4">
        <button
          className="w-full bg-gray-200 bg-opacity-50 text-gray-800 border border-gray-600 border-opacity-50 px-4 py-2 rounded flex justify-between items-center"
          onClick={toggleCryptoDropdown}
        >
          <span>{cryptos.find((c) => c.id === selectedCrypto)?.name || 'Select Crypto'}</span>
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
          <div className="absolute z-10 w-full bg-white border border-gray-300 rounded shadow-lg mt-1">
            {cryptos.map((crypto) => (
              <button
                key={crypto.id}
                className="w-full text-left px-4 py-2 hover:bg-gray-100"
                onClick={() => {
                  setSelectedCrypto(crypto.id);
                  setShowCryptoDropdown(false);
                }}
              >
                {crypto.name}
              </button>
            ))}
          </div>
        )}
      </div>
      <h1 className="text-2xl font-bold text-center mb-4">{username}</h1>
      <p className="text-center text-gray-600 mb-4">
        Balance: {balance !== null ? balance : 'Loading...'} {selectedCrypto}
      </p>
    </div>
  );
}

export default Profile;




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

  // Коды стран
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
