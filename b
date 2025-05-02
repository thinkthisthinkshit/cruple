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







index.js:
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import './index.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <BrowserRouter>
    <App />
  </BrowserRouter>
);










BottomNav:
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






Routes.jsx:
const express = require('express');
const { User, Purchase } = require('./db');
const { generateAddress, getBalance } = require('./wallet');
const axios = require('axios');

const router = express.Router();

const countries = [
  { id: 'us', name_en: 'United States', name_ru: 'США' },
  { id: 'ru', name_en: 'Russia', name_ru: 'Россия' },
  { id: 'uk', name_en: 'United Kingdom', name_ru: 'Великобритания' },
  { id: 'fr', name_en: 'France', name_ru: 'Франция' },
  { id: 'de', name_en: 'Germany', name_ru: 'Германия' },
  { id: 'it', name_en: 'Italy', name_ru: 'Италия' },
  { id: 'es', name_en: 'Spain', name_ru: 'Испания' },
  { id: 'cn', name_en: 'China', name_ru: 'Китай' },
  { id: 'jp', name_en: 'Japan', name_ru: 'Япония' },
  { id: 'in', name_en: 'India', name_ru: 'Индия' },
  { id: 'br', name_en: 'Brazil', name_ru: 'Бразилия' },
  { id: 'ca', name_en: 'Canada', name_ru: 'Канада' },
  { id: 'au', name_en: 'Australia', name_ru: 'Австралия' },
  { id: 'za', name_en: 'South Africa', name_ru: 'Южная Африка' },
  { id: 'mx', name_en: 'Mexico', name_ru: 'Мексика' },
  { id: 'ar', name_en: 'Argentina', name_ru: 'Аргентина' },
  { id: 'cl', name_en: 'Chile', name_ru: 'Чили' },
  { id: 'co', name_en: 'Colombia', name_ru: 'Колумбия' },
  { id: 'pe', name_en: 'Peru', name_ru: 'Перу' },
  { id: 've', name_en: 'Venezuela', name_ru: 'Венесуэла' },
  { id: 'eg', name_en: 'Egypt', name_ru: 'Египет' },
  { id: 'ng', name_en: 'Nigeria', name_ru: 'Нигерия' },
  { id: 'ke', name_en: 'Kenya', name_ru: 'Кения' },
  { id: 'gh', name_en: 'Ghana', name_ru: 'Гана' },
  { id: 'dz', name_en: 'Algeria', name_ru: 'Алжир' },
  { id: 'ma', name_en: 'Morocco', name_ru: 'Марокко' },
  { id: 'sa', name_en: 'Saudi Arabia', name_ru: 'Саудовская Аравия' },
  { id: 'ae', name_en: 'United Arab Emirates', name_ru: 'ОАЭ' },
  { id: 'tr', name_en: 'Turkey', name_ru: 'Турция' },
  { id: 'pl', name_en: 'Poland', name_ru: 'Польша' },
  { id: 'ua', name_en: 'Ukraine', name_ru: 'Украина' },
  { id: 'by', name_en: 'Belarus', name_ru: 'Беларусь' },
  { id: 'kz', name_en: 'Kazakhstan', name_ru: 'Казахстан' },
  { id: 'uz', name_en: 'Uzbekistan', name_ru: 'Узбекистан' },
  { id: 'ge', name_en: 'Georgia', name_ru: 'Грузия' },
  { id: 'am', name_en: 'Armenia', name_ru: 'Армения' },
  { id: 'az', name_en: 'Azerbaijan', name_ru: 'Азербайджан' },
  { id: 'id', name_en: 'Indonesia', name_ru: 'Индонезия' },
  { id: 'th', name_en: 'Thailand', name_ru: 'Таиланд' },
  { id: 'vn', name_en: 'Vietnam', name_ru: 'Вьетнам' },
  { id: 'ph', name_en: 'Philippines', name_ru: 'Филиппины' },
  { id: 'my', name_en: 'Malaysia', name_ru: 'Малайзия' },
  { id: 'sg', name_en: 'Singapore', name_ru: 'Сингапур' },
  { id: 'kr', name_en: 'South Korea', name_ru: 'Южная Корея' },
  { id: 'pk', name_en: 'Pakistan', name_ru: 'Пакистан' },
  { id: 'bd', name_en: 'Bangladesh', name_ru: 'Бангладеш' },
  { id: 'lk', name_en: 'Sri Lanka', name_ru: 'Шри-Ланка' },
  { id: 'np', name_en: 'Nepal', name_ru: 'Непал' },
  { id: 'mm', name_en: 'Myanmar', name_ru: 'Мьянма' },
  { id: 'kh', name_en: 'Cambodia', name_ru: 'Камбоджа' },
  { id: 'la', name_en: 'Laos', name_ru: 'Лаос' },
  { id: 'se', name_en: 'Sweden', name_ru: 'Швеция' },
  { id: 'no', name_en: 'Norway', name_ru: 'Норвегия' },
  { id: 'fi', name_en: 'Finland', name_ru: 'Финляндия' },
  { id: 'dk', name_en: 'Denmark', name_ru: 'Дания' },
  { id: 'nl', name_en: 'Netherlands', name_ru: 'Нидерланды' },
  { id: 'be', name_en: 'Belgium', name_ru: 'Бельгия' },
  { id: 'at', name_en: 'Austria', name_ru: 'Австрия' },
  { id: 'ch', name_en: 'Switzerland', name_ru: 'Швейцария' },
  { id: 'gr', name_en: 'Greece', name_ru: 'Греция' },
  { id: 'pt', name_en: 'Portugal', name_ru: 'Португалия' },
  { id: 'ie', name_en: 'Ireland', name_ru: 'Ирландия' },
  { id: 'cz', name_en: 'Czech Republic', name_ru: 'Чехия' },
  { id: 'sk', name_en: 'Slovakia', name_ru: 'Словакия' },
  { id: 'hu', name_en: 'Hungary', name_ru: 'Венгрия' },
  { id: 'ro', name_en: 'Romania', name_ru: 'Румыния' },
  { id: 'bg', name_en: 'Bulgaria', name_ru: 'Болгария' },
  { id: 'hr', name_en: 'Croatia', name_ru: 'Хорватия' },
  { id: 'rs', name_en: 'Serbia', name_ru: 'Сербия' },
  { id: 'ba', name_en: 'Bosnia and Herzegovina', name_ru: 'Босния и Герцеговина' },
];

const resources = [
  { id: 'other', name_en: 'Other', name_ru: 'Другой' },
  { id: 'whatsapp', name_en: 'WhatsApp', name_ru: 'WhatsApp' },
  { id: 'telegram', name_en: 'Telegram', name_ru: 'Telegram' },
  { id: 'instagram', name_en: 'Instagram', name_ru: 'Instagram' },
  { id: 'facebook', name_en: 'Facebook', name_ru: 'Facebook' },
  { id: 'viber', name_en: 'Viber', name_ru: 'Viber' },
  { id: 'skype', name_en: 'Skype', name_ru: 'Skype' },
  { id: 'wechat', name_en: 'WeChat', name_ru: 'WeChat' },
  { id: 'snapchat', name_en: 'Snapchat', name_ru: 'Snapchat' },
  { id: 'tiktok', name_en: 'TikTok', name_ru: 'TikTok' },
  { id: 'discord', name_en: 'Discord', name_ru: 'Discord' },
  { id: 'twitter', name_en: 'Twitter', name_ru: 'Twitter' },
  { id: 'linkedin', name_en: 'LinkedIn', name_ru: 'LinkedIn' },
  { id: 'vk', name_en: 'VK', name_ru: 'ВКонтакте' },
  { id: 'gmail', name_en: 'Gmail', name_ru: 'Gmail' },
];

let ratesCache = {
  timestamp: 0,
  rates: {
    btc: { usd: 0, rub: 0 },
    usdt: { usd: 0, rub: 0 },
    ltc: { usd: 0, rub: 0 },
    eth: { usd: 0, rub: 0 },
    bnb: { usd: 0, rub: 0 },
    avax: { usd: 0, rub: 0 },
    ada: { usd: 0, rub: 0 },
    sol: { usd: 0, rub: 0 },
  },
};

const SUPPORTED_CRYPTOS = ['BTC', 'USDT', 'LTC', 'ETH', 'BNB', 'AVAX', 'ADA', 'SOL'];

const fetchCryptoRates = async () => {
  const start = Date.now();
  const now = Date.now();
  if (now - ratesCache.timestamp < 3600000) {
    console.log('Using cached rates, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  }
  try {
    const res = await axios.get(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,tether,litecoin,ethereum,binancecoin,avalanche-2,cardano,solana&vs_currencies=usd,rub'
    );
    ratesCache = {
      timestamp: now,
      rates: {
        btc: res.data.bitcoin,
        usdt: res.data.tether,
        ltc: res.data.litecoin,
        eth: res.data.ethereum,
        bnb: res.data['binancecoin'],
        avax: res.data['avalanche-2'],
        ada: res.data.cardano,
        sol: res.data.solana,
      },
    };
    console.log('Fetched rates from CoinGecko, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  } catch (err) {
    console.error('Fetch crypto rates error:', err.message);
    console.log('Fetch rates failed, time:', Date.now() - start, 'ms');
    return ratesCache.rates;
  }
};

router.get('/countries', (req, res) => {
  const start = Date.now();
  res.json(countries);
  console.log('Countries fetched, time:', Date.now() - start, 'ms');
});

router.get('/resources', async (req, res) => {
  const start = Date.now();
  const language = req.query.language || 'ru';
  try {
    const rates = await fetchCryptoRates();
    console.log('Returning rates for /resources:', rates);
    res.json({
      services: resources.map((resource) => ({
        id: resource.id,
        name: language === 'ru' ? resource.name_ru : resource.name_en,
      })),
      rates,
    });
    console.log('Resources fetched, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Fetch resources error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Resources fetch failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/generate-address/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  console.log('Raw request body:', req.body);
  try {
    if (!crypto || !SUPPORTED_CRYPTOS.includes(crypto)) {
      console.warn('Invalid crypto:', { crypto, supported: SUPPORTED_CRYPTOS });
      res.status(400).json({ error: `Invalid cryptocurrency: ${crypto || 'undefined'}` });
      console.log('Invalid crypto error, time:', Date.now() - start, 'ms');
      return;
    }
    console.log('Generate address request:', { telegram_id, crypto });
    let user = await User.findOne({ telegram_id });
    let addresses = user?.addresses || {};
    const rates = await fetchCryptoRates();
    const rate = rates[crypto.toLowerCase()]?.[user?.display_currency.toLowerCase() || 'rub'] || 0;
    
    if (!user || user.crypto !== crypto || !addresses[crypto]) {
      const address = await generateAddress(telegram_id, crypto);
      addresses[crypto] = address;
      if (user) {
        user.addresses = addresses;
        user.crypto = crypto;
        await user.save();
        console.log('New address generated:', { address, crypto, rate });
        res.json({ address, rate });
      } else {
        const index = Math.floor(Math.random() * 1000000);
        user = await User.create({
          telegram_id,
          wallet_index: index,
          address,
          addresses: { [crypto]: address },
          balance: 1.0,
          crypto,
          language: 'ru',
          display_currency: 'RUB',
          last_selected_resource: 'other',
        });
        console.log('New user created with address:', { address, crypto, rate });
        res.json({ address, rate });
      }
    } else {
      console.log('Returning cached address:', { address: addresses[crypto], crypto, rate });
      res.json({ address: addresses[crypto], rate });
    }
    console.log('Generate address completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Generate address error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Generate address failed, time:', Date.now() - start, 'ms');
  }
});

router.get('/balance/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.query;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user) {
      res.json({
        balance: '0.00000000',
        address: '',
        crypto: crypto || 'BTC',
        display_balance: '0.00',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
      console.log('Balance fetched (no user), time:', Date.now() - start, 'ms');
      return;
    }
    const addresses = user.addresses || {};
    const address = addresses[crypto || user.crypto] || '';
    const balance = user.balance !== undefined ? user.balance : (await getBalance(address)) || 0;
    const rates = await fetchCryptoRates();
    const rate = rates[crypto?.toLowerCase() || user.crypto?.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
    const display_balance = (balance * rate).toFixed(2);
    res.json({
      balance: balance.toFixed(8),
      address,
      crypto: crypto || user.crypto || 'BTC',
      display_balance,
      display_currency: user.display_currency,
      language: user.language,
      last_selected_resource: user.last_selected_resource,
    });
    console.log('Balance fetched, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Fetch balance error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Balance fetch failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/buy', async (req, res) => {
  const start = Date.now();
  const { telegram_id, country, resource } = req.body;
  try {
    const user = await User.findOne({ telegram_id });
    if (!user || (user.balance !== undefined && user.balance < 0.0001)) {
      res.json({ success: false, error: user?.language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds' });
      console.log('Buy failed (insufficient funds), time:', Date.now() - start, 'ms');
      return;
    }
    const code = `SMS-${Math.random().toString(36).slice(2, 8)}`;
    await Purchase.create({
      telegram_id,
      country,
      resource,
      code,
      status: 'active',
      service_type: 'sms',
    });
    user.balance = (user.balance || 1.0) - 0.0001;
    user.last_selected_resource = resource;
    await user.save();
    res.json({ success: true, code });
    console.log('Buy completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Buy error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Buy failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/select-crypto/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { crypto } = req.body;
  console.log('Raw request body for select-crypto:', req.body);
  try {
    if (!crypto || !SUPPORTED_CRYPTOS.includes(crypto)) {
      console.warn('Invalid crypto in select-crypto:', { crypto, supported: SUPPORTED_CRYPTOS });
      res.status(400).json({ error: `Invalid cryptocurrency: ${crypto || 'undefined'}` });
      console.log('Select crypto failed (invalid crypto), time:', Date.now() - start, 'ms');
      return;
    }
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto,
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: 'other',
      });
    } else {
      user.crypto = crypto;
      await user.save();
    }
    console.log('Crypto selected:', { telegram_id, crypto });
    res.json({ success: true, crypto });
    console.log('Select crypto completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Select crypto error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Select crypto failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/set-language/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  const { language } = req.body;
  try {
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto: 'BTC',
        language,
        display_currency: language === 'ru' ? 'RUB' : 'USD',
        last_selected_resource: 'other',
      });
    } else {
      user.language = language;
      user.display_currency = language === 'ru' ? 'RUB' : 'USD';
      await user.save();
    }
    res.json({ success: true, language, display_currency: user.display_currency });
    console.log('Set language completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Set language error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Set language failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/buy-number', async (req, res) => {
  const start = Date.now();
  const { telegram_id, country, service, currency, resource } = req.body;
  console.log('Buy number request:', { telegram_id, country, service, currency, resource });
  try {
    let user = await User.findOne({ telegram_id });
    if (!user) {
      const index = Math.floor(Math.random() * 1000000);
      user = await User.create({
        telegram_id,
        wallet_index: index,
        address: '',
        addresses: {},
        balance: 1.0,
        crypto: currency || 'BTC',
        language: 'ru',
        display_currency: 'RUB',
        last_selected_resource: resource || 'other',
      });
    }
    user.last_selected_resource = resource || user.last_selected_resource;
    await user.save();
    await processPurchase(user, telegram_id, country, service, currency, resource, res);
    console.log('Buy number completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Buy number error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Buy number failed, time:', Date.now() - start, 'ms');
  }
});

router.get('/purchases/:telegram_id', async (req, res) => {
  const start = Date.now();
  const { telegram_id } = req.params;
  try {
    const user = await User.findOne({ telegram_id });
    const purchases = await Purchase.find({ telegram_id }).sort({ created_at: -1 });
    console.log('Purchases fetched:', purchases);
    const rates = await fetchCryptoRates();
    const formattedPurchases = purchases.map((purchase) => {
      console.log('Formatting purchase:', purchase);
      const [priceValue, crypto] = purchase.price.split(' ');
      const rate = rates[crypto?.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
      const display_price = (parseFloat(priceValue) * rate).toFixed(2);
      return {
        id: purchase._id,
        telegram_id: purchase.telegram_id,
        country: countries.find((c) => c.id === purchase.country) || {
          id: purchase.country,
          name_en: purchase.country,
          name_ru: purchase.country,
        },
        service: purchase.resource,
        service_type: purchase.service_type,
        code: purchase.code,
        number: purchase.number || `+${Math.floor(10000000000 + Math.random() * 90000000000)}`,
        price: purchase.price,
        display_price: `${display_price} ${user.display_currency}`,
        created_at: purchase.created_at.toISOString(),
        status: purchase.status,
      };
    });
    res.json(formattedPurchases);
    console.log('Purchases fetched, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Fetch purchases error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Purchases fetch failed, time:', Date.now() - start, 'ms');
  }
});

router.post('/complete-purchase/:purchase_id', async (req, res) => {
  const start = Date.now();
  const { purchase_id } = req.params;
  try {
    const purchase = await Purchase.findById(purchase_id);
    if (!purchase) {
      res.status(400).json({ error: 'Purchase not found' });
      console.log('Complete purchase failed (not found), time:', Date.now() - start, 'ms');
      return;
    }
    if (purchase.status === 'completed') {
      res.json({ success: false, error: 'Purchase already completed' });
      console.log('Complete purchase failed (already completed), time:', Date.now() - start, 'ms');
      return;
    }
    purchase.status = 'completed';
    await purchase.save();
    console.log('Purchase completed:', purchase);
    res.json({ success: true });
    console.log('Complete purchase completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Complete purchase error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Complete purchase failed, time:', Date.now() - start, 'ms');
  }
});

async function processPurchase(user, telegram_id, country, service, currency, resource, res) {
  const start = Date.now();
  console.log('Processing purchase:', { telegram_id, country, service, currency, resource });
  const addresses = user.addresses || {};
  const address = addresses[currency] || '';
  const balance = user.balance !== undefined ? user.balance : (await getBalance(address)) || 0;
  const priceInCrypto = {
    sms: 0.012,
    call: 0.020,
    rent: 5,
  }[service] || 0.012;
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
  const cryptoPrice = (priceInCrypto * (rates[currency] || 1)).toFixed(8);
  const cryptoRates = await fetchCryptoRates();
  const fiatRate = cryptoRates[currency.toLowerCase()]?.[user.display_currency.toLowerCase()] || 1;
  const displayPrice = (parseFloat(cryptoPrice) * fiatRate).toFixed(2);
  if (isNaN(balance) || balance < parseFloat(cryptoPrice)) {
    console.log('Insufficient funds:', { balance, cryptoPrice });
    res.json({ success: false, error: user.language === 'ru' ? 'Недостаточно средств' : 'Insufficient funds' });
    console.log('Process purchase failed (insufficient funds), time:', Date.now() - start, 'ms');
    return;
  }
  const number = `+${Math.floor(10000000000 + Math.random() * 90000000000)}`;
  const code = service === 'sms' ? `CODE-${Math.random().toString(36).slice(2, 8)}` : null;
  const last4 = service === 'call' ? number.slice(-4) : null;
  const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  try {
    const purchase = await Purchase.create({
      telegram_id,
      country,
      resource: resource || service,
      code: code || number,
      number,
      price: `${cryptoPrice} ${currency}`,
      service_type: service,
      status: 'active',
      created_at: new Date(),
    });
    console.log('Purchase created:', purchase);
    user.balance = (user.balance || 1.0) - parseFloat(cryptoPrice);
    user.last_selected_resource = resource || user.last_selected_resource;
    await user.save();
    console.log('Balance updated:', { telegram_id, newBalance: user.balance });
    res.json({
      success: true,
      number,
      last4,
      expiry,
      price: `${cryptoPrice} ${currency}`,
      display_price: `${displayPrice} ${user.display_currency}`,
      country: countries.find((c) => c.id === country) || { id: country, name_en: country, name_ru: country },
      service,
      resource,
      purchase_id: purchase._id,
    });
    console.log('Process purchase completed, time:', Date.now() - start, 'ms');
  } catch (err) {
    console.error('Process purchase error:', err.message);
    res.status(500).json({ error: 'Server error' });
    console.log('Process purchase failed, time:', Date.now() - start, 'ms');
  }
}

module.exports = router;









