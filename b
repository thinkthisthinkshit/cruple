import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';

function Profile({ username, selectedCrypto, setSelectedCrypto, balance, onBack }) {
  const { tg } = useTelegram();
  const [showCryptoDropdown, setShowCryptoDropdown] = useState(false);
  const [showDepositModal, setShowDepositModal] = useState(false);

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  const cryptos = [
    { id: 'BTC', name: 'Bitcoin', balance: '0.00000000' },
    { id: 'ETH', name: 'Ethereum', balance: '0.00000000' },
    { id: 'USDT', name: 'Tether', balance: '0.00000000' },
    { id: 'BNB', name: 'Binance Coin', balance: '0.00000000' },
    { id: 'ADA', name: 'Cardano', balance: '0.00000000' },
    { id: 'SOL', name: 'Solana', balance: '0.00000000' },
    { id: 'XRP', name: 'Ripple', balance: '0.00000000' },
    { id: 'DOT', name: 'Polkadot', balance: '0.00000000' },
    { id: 'LTC', name: 'Litecoin', balance: '0.00000000' },
    { id: 'XMR', name: 'Monero', balance: '0.00000000' },
    { id: 'TRX', name: 'Tron', balance: '0.00000000' },
    { id: 'AVAX', name: 'Avalanche', balance: '0.00000000' },
    { id: 'ATOM', name: 'Cosmos', balance: '0.00000000' },
    { id: 'XTZ', name: 'Tezos', balance: '0.00000000' },
    { id: 'ALGO', name: 'Algorand', balance: '0.00000000' },
  ];

  const toggleCryptoDropdown = () => {
    setShowCryptoDropdown(!showCryptoDropdown);
  };

  const handleDeposit = () => {
    setShowDepositModal(true);
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
            <span>
              {selectedCryptoData
                ? `${selectedCryptoData.name} ${selectedCryptoData.balance}`
                : 'Select Crypto'}
            </span>
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
                  className="w-full text-left px-4 py-2 hover:bg-gray-100 flex justify-between"
                  onClick={() => {
                    setSelectedCrypto(crypto.id);
                    setShowCryptoDropdown(false);
                  }}
                >
                  <span>{crypto.name}</span>
                  <span>{crypto.balance}</span>
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
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center"
          onClick={() => setShowDepositModal(false)}
        >
          <div
            className="bg-white p-4 rounded-lg max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold mb-4">
              {cryptos.find((c) => c.id === selectedCrypto)?.name || 'Crypto'} Адрес
            </h2>
            <p className="text-gray-600">Адрес для пополнения скоро будет доступен.</p>
          </div>
        </div>
      )}
    </div>
  );
}

export default Profile;
