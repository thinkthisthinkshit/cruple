Profile.jsx:
import { useState } from 'react';
import { useTelegram } from '../telegram';
import BalanceModal from './BalanceModal';
import axios from 'axios';

function Profile({ username, balance, displayCurrency, onBack, language }) {
  const { tg } = useTelegram();
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const [address, setAddress] = useState('');
  const [cryptoRate, setCryptoRate] = useState(0);
  const [selectedCrypto, setSelectedCrypto] = useState('');
  const [isGeneratingAddress, setIsGeneratingAddress] = useState(false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  const handleGenerateAddress = async (crypto) => {
    if (!tg?.initData || isGeneratingAddress || !crypto) {
      console.warn('Generate address blocked:', {
        hasInitData: !!tg?.initData,
        isGeneratingAddress,
        crypto,
      });
      return;
    }
    setIsGeneratingAddress(true);
    try {
      console.log('Generating address for crypto:', crypto);
      const res = await axios.post(
        `${API_URL}/generate-address/${tg.initDataUnsafe.user.id}`,
        { crypto },
        {
          headers: {
            'telegram-init-data': tg.initData,
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      console.log('Generate address response:', res.data);
      if (!res.data.address) {
        throw new Error('No address returned from server');
      }
      setAddress(res.data.address);
      setCryptoRate(res.data.rate || 0);
      setSelectedCrypto(crypto);
      setShowBalanceModal(true);
    } catch (err) {
      console.error('Generate address error:', err.response?.data || err.message);
      tg.showPopup({
        message: language === 'ru' ? 'Ошибка генерации адреса' : 'Error generating address',
      });
    } finally {
      setIsGeneratingAddress(false);
    }
  };

  const texts = {
    ru: {
      profile: 'Профиль',
      balance: 'Баланс',
      topUp: 'Пополнить',
      copied: 'Адрес скопирован',
    },
    en: {
      profile: 'Profile',
      balance: 'Balance',
      topUp: 'Top Up',
      copied: 'Address copied',
    },
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4">{texts[language].profile}</h1>
      <p className="text-lg mb-4">{username}</p>
      <div className="mb-4">
        <p className="text-sm text-gray-600">{texts[language].balance}</p>
        <p className="text-lg font-semibold">
          {balance} {displayCurrency}
        </p>
      </div>
      <button
        className={`w-full bg-blue-500 text-white px-4 py-2 rounded mb-4 ${
          isGeneratingAddress ? 'opacity-50 cursor-not-allowed' : ''
        }`}
        onClick={() => setShowBalanceModal(true)}
        disabled={isGeneratingAddress}
      >
        {texts[language].topUp} {isGeneratingAddress && <span className="spinner ml-2"></span>}
      </button>
      {showBalanceModal && (
        <BalanceModal
          language={language}
          address={address}
          crypto={selectedCrypto}
          cryptoRate={cryptoRate}
          displayCurrency={displayCurrency}
          onClose={() => setShowBalanceModal(false)}
          onCopy={() => tg.showPopup({ message: texts[language].copied })}
          onSelectCrypto={handleGenerateAddress}
        />
      )}
      <style>
        {`
          .spinner {
            display: inline-block;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #3498db;
            border-radius: 50%;
            width: 16px;
            height: 16px;
            animation: spin 1s linear infinite;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        `}
      </style>
    </div>
  );
}

export default Profile;







BalanceModal.jsx:
import { useState } from 'react';
import QRCode from 'qrcode.react';

function BalanceModal({ language, address, crypto, cryptoRate, displayCurrency, onClose, onCopy, onSelectCrypto }) {
  const [selectedCrypto, setSelectedCrypto] = useState(crypto || '');
  const supportedCryptos = ['BTC', 'USDT', 'LTC', 'ETH', 'BNB', 'AVAX', 'ADA', 'SOL'];

  const texts = {
    ru: {
      title: 'Пополнение баланса',
      balance: 'Текущий баланс',
      address: 'Адрес для пополнения',
      close: 'Закрыть',
      copy: 'Скопировать адрес',
      selectCrypto: 'Выберите валюту',
    },
    en: {
      title: 'Top Up Balance',
      balance: 'Current Balance',
      address: 'Deposit Address',
      close: 'Close',
      copy: 'Copy Address',
      selectCrypto: 'Select Currency',
    },
  };

  const formatRate = (rate) => {
    if (!rate) return 'N/A';
    return new Intl.NumberFormat(language === 'ru' ? 'ru-RU' : 'en-US', {
      style: 'decimal',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(rate);
  };

  const handleCryptoChange = (e) => {
    const newCrypto = e.target.value;
    setSelectedCrypto(newCrypto);
    if (newCrypto) {
      onSelectCrypto(newCrypto);
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
      onClick={onClose}
    >
      <div
        className="bg-white p-4 rounded-lg max-w-sm w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-xl font-bold mb-4">{texts[language].title}</h2>
        <p className="text-sm text-gray-600 mb-2">{texts[language].selectCrypto}</p>
        <select
          className="w-full p-2 border rounded mb-4"
          value={selectedCrypto}
          onChange={handleCryptoChange}
        >
          <option value="">{language === 'ru' ? 'Выберите валюту' : 'Select currency'}</option>
          {supportedCryptos.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
        {selectedCrypto && (
          <>
            <p className="text-sm text-gray-600 mb-2">{texts[language].balance}</p>
            <p className="text-lg font-semibold mb-4">
              {selectedCrypto} {cryptoRate ? ` (1 ${selectedCrypto} = ${formatRate(cryptoRate)} ${displayCurrency})` : ''}
            </p>
            {address ? (
              <>
                <p className="text-sm text-gray-600 mb-2">{texts[language].address}</p>
                <p className="text-sm break-all mb-4">{address}</p>
                <QRCode value={address} size={128} className="mb-4 mx-auto" />
                {selectedCrypto === 'USDT' && (
                  <p className="text-sm text-red-500 mb-4">
                    {language === 'ru'
                      ? 'Отправляйте USDT только через сеть Ethereum (ERC-20). Переводы по другим сетям не будут зачислены.'
                      : 'Send USDT only via Ethereum (ERC-20) network. Transfers via other networks will not be credited.'}
                  </p>
                )}
              </>
            ) : (
              <p className="text-sm text-red-500 mb-4">
                {language === 'ru' ? 'Адрес не сгенерирован' : 'Address not generated'}
              </p>
            )}
          </>
        )}
        <div className="flex gap-4">
          <button
            className="flex-1 bg-gray-500 text-white px-4 py-2 rounded"
            onClick={onClose}
          >
            {texts[language].close}
          </button>
          <button
            className="flex-1 bg-blue-500 text-white px-4 py-2 rounded"
            onClick={() => {
              navigator.clipboard.writeText(address || '');
              onCopy();
            }}
            disabled={!address}
          >
            {texts[language].copy}
          </button>
        </div>
      </div>
    </div>
  );
}

export default BalanceModal;









BottomNav.jsx:
import { FaHome, FaCog, FaHistory, FaUser } from 'react-icons/fa';

function BottomNav({ language, onHome, onSettings, onHistory, onProfile }) {
  const texts = {
    ru: {
      home: 'Главная',
      settings: 'Настройки',
      history: 'История',
      profile: 'Профиль',
    },
    en: {
      home: 'Home',
      settings: 'Settings',
      history: 'History',
      profile: 'Profile',
    },
  };

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 flex justify-around py-2">
      <button
        className="flex flex-col items-center text-gray-600"
        onClick={onHome}
      >
        <FaHome className="text-xl" />
        <span className="text-xs">{texts[language].home}</span>
      </button>
      <button
        className="flex flex-col items-center text-gray-600"
        onClick={onSettings}
      >
        <FaCog className="text-xl" />
        <span className="text-xs">{texts[language].settings}</span>
      </button>
      <button
        className="flex flex-col items-center text-gray-600"
        onClick={onHistory}
      >
        <FaHistory className="text-xl" />
        <span className="text-xs">{texts[language].history}</span>
      </button>
      <button
        className="flex flex-col items-center text-gray-600"
        onClick={onProfile}
      >
        <FaUser className="text-xl" />
        <span className="text-xs">{texts[language].profile}</span>
      </button>
    </div>
  );
}

export default BottomNav;








App.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountryList from './components/CountryList';
import Profile from './components/Profile';
import PurchaseResult from './components/PurchaseResult';
import PurchaseHistory from './components/PurchaseHistory';
import NumberModal from './components/NumberModal';
import BottomNav from './components/BottomNav';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [language, setLanguage] = useState('ru');
  const [displayCurrency, setDisplayCurrency] = useState('RUB');
  const [showCountryList, setShowCountryList] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
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
        else if (showSettingsModal) setShowSettingsModal(false);
      });
      if (showCountryList || showProfile || showPurchaseResult || showPurchaseHistory || showNumberModal || showSettingsModal) {
        tg.BackButton.show();
      } else {
        tg.BackButton.hide();
      }
      if (user?.id) {
        checkUser();
      }
    }
  }, [tg, showCountryList, showProfile, showPurchaseResult, showPurchaseHistory, showNumberModal, showSettingsModal, user]);

  const checkUser = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user.id}?crypto=${selectedCrypto}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      console.log('Check user response:', res.data);
      if (res.data.balance === '0.00000000' && !res.data.address) {
        setIsNewUser(true);
        setShowSettingsModal(true);
      } else {
        setLanguage(res.data.language || 'ru');
        setDisplayCurrency(res.data.display_currency || 'RUB');
        setBalance(res.data.balance || '0.00000000');
        setDisplayBalance(res.data.display_balance || '0.00');
        setLastSelectedResource(res.data.last_selected_resource || 'other');
        const serverCrypto = res.data.crypto || 'BTC';
        setSelectedCrypto(serverCrypto);
        console.log('Set selectedCrypto from server:', serverCrypto);
      }
    } catch (err) {
      console.error('Check user error:', err.response?.data || err.message);
      setSelectedCrypto('BTC');
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
      setShowSettingsModal(false);
      setIsNewUser(false);
    } catch (err) {
      console.error('Set language error:', err.response?.data || err.message);
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
      console.error('Fetch balance error:', err.response?.data || err.message);
    }
  };

  const handleSelectCrypto = async (crypto) => {
    if (!user?.id || !crypto) {
      console.warn('Select crypto blocked:', { userId: user?.id, crypto });
      return;
    }
    try {
      console.log('App selecting crypto:', crypto);
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
      console.error('Select crypto error:', err.response?.data || err.message);
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
        balance={displayBalance}
        displayCurrency={displayCurrency}
        onBack={() => setShowProfile(false)}
        language={language}
      />
    );
  }

  if (showNumberModal) {
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
    <div className="p-4 max-w-md mx-auto pb-16">
      <div className="flex justify-end mb-4">
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
      {(showSettingsModal || isNewUser) && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
          onClick={() => !isNewUser && setShowSettingsModal(false)}
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
      <BottomNav
        language={language}
        onHome={() => {
          setShowProfile(false);
          setShowPurchaseHistory(false);
          setShowCountryList(false);
          setShowNumberModal(false);
          setShowPurchaseResult(false);
          setShowSettingsModal(false);
        }}
        onSettings={() => {
          setShowProfile(false);
          setShowPurchaseHistory(false);
          setShowCountryList(false);
          setShowNumberModal(false);
          setShowPurchaseResult(false);
          setShowSettingsModal(true);
        }}
        onHistory={() => {
          setShowProfile(false);
          setShowPurchaseHistory(true);
          setShowCountryList(false);
          setShowNumberModal(false);
          setShowPurchaseResult(false);
          setShowSettingsModal(false);
          setRefreshPurchases(true);
        }}
        onProfile={() => {
          setShowProfile(true);
          setShowPurchaseHistory(false);
          setShowCountryList(false);
          setShowNumberModal(false);
          setShowPurchaseResult(false);
          setShowSettingsModal(false);
        }}
      />
    </div>
  );
}

export default App;








