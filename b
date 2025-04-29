telegram.js:
import { useEffect, useState } from 'react';

export const useTelegram = () => {
  const [tg, setTg] = useState(null);
  const [user, setUser] = useState(null);

  useEffect(() => {
    const telegram = window.Telegram?.WebApp;
    if (telegram) {
      telegram.ready();
      telegram.expand();
      setTg(telegram);
      setUser(telegram.initDataUnsafe?.user);
      console.log('Telegram WebApp initialized:', telegram.initDataUnsafe);
    } else {
      console.error('Telegram WebApp is not available');
    }
  }, []);

  return { tg, user };
};



profile:
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
    console.log('Profile user:', user); // Отладка
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin' },
    { id: 'ETH', name: 'Ethereum' },
    { id: 'USDT', name: 'Tether' },
    { id: 'BNB', name: 'Binance Coin' },
    { id: 'ADA', name: 'Cardano' },
    { id: 'SOL', name: 'Solana' },
    { id: 'XRP', name: 'Ripple' },
    { id: 'DOT', name: 'Polkadot' },
    { id: 'LTC', name: 'Litecoin' },
    { id: 'XMR', name: 'Monero' },
    { id: 'TRX', name: 'Tron' },
    { id: 'AVAX', name: 'Avalanche' },
    { id: 'ATOM', name: 'Cosmos' },
    { id: 'XTZ', name: 'Tezos' },
    { id: 'ALGO', name: 'Algorand' },
    { id: 'NOT', name: 'Notcoin' },
    { id: 'HMSTR', name: 'Hamster Kombat' },
  ];

  const toggleCryptoDropdown = () => {
    setShowCryptoDropdown(!showCryptoDropdown);
  };

  const handleDeposit = async () => {
    if (!user?.id) {
      console.error('Telegram user ID is undefined');
      tg?.showPopup({ message: 'Ошибка: Telegram ID не определён' });
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
      tg?.showPopup({ message: `Ошибка генерации адреса: ${err.message}` });
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(depositAddress);
    tg?.showPopup({ message: 'Адрес скопирован!' });
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
            <span>{selectedCryptoData ? selectedCryptoData.name : 'Select Crypto'}</span>
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
                  {crypto.name}
                </button>
              ))}
            </div>
          )}
        </div>
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded"
          onClick={handleDeposit}
        >
          Пополнить
        </button>
      </div>
      <h1 className="text-2xl font-bold text-center mb-4">{username}</h1>
      {showDepositModal && (
        <BalanceModal
          address={depositAddress}
          onClose={() => setShowDepositModal(false)}
          onCopy={copyToClipboard}
        />
      )}
    </div>
  );
}

export default Profile;
