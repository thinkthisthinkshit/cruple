import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import BalanceModal from './BalanceModal';
import './Profile.css';

const Profile = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [selectedCrypto, setSelectedCrypto] = useState('');
  const [address, setAddress] = useState('');
  const [error, setError] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);

  const cryptocurrencies = ['BTC', 'TON', 'LTC', 'ETH', 'USDT', 'BNB', 'AVAX', 'ADA', 'SOL'];

  useEffect(() => {
    if (window.Telegram?.WebApp) {
      const tg = window.Telegram.WebApp;
      tg.ready();
      const userData = tg.initDataUnsafe?.user;
      console.log('Profile user:', userData);
      if (userData?.id) {
        setUser(userData);
      } else {
        setError('User data not found');
      }
    } else {
      setError('Telegram WebApp not initialized');
    }
  }, []);

  const handleCryptoSelect = async (crypto) => {
    setSelectedCrypto(crypto);
    setError('');
    if (user?.id) {
      try {
        console.log(`Fetching address for ${crypto}, telegram_id: ${user.id}`);
        const response = await fetch(`http://localhost:5000/generate-address/${user.id}?crypto=${crypto}`);
        const data = await response.json();
        if (data.address) {
          setAddress(data.address);
          setIsModalOpen(true);
        } else {
          setError(data.error || 'Failed to generate address');
        }
      } catch (err) {
        console.error('Generate address error:', err);
        setError('Failed to generate address');
      }
    } else {
      setError('User not authenticated');
    }
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setAddress('');
    setSelectedCrypto('');
  };

  if (!user) {
    return <div>{error || 'Loading...'}</div>;
  }

  return (
    <div className="profile">
      <h1>Profile</h1>
      <p>Welcome, {user.first_name || 'User'}!</p>
      <h2>Select Cryptocurrency</h2>
      <div className="crypto-list">
        {cryptocurrencies.map((crypto) => (
          <button
            key={crypto}
            onClick={() => handleCryptoSelect(crypto)}
            className="crypto-button"
          >
            {crypto}
          </button>
        ))}
      </div>
      {error && <p className="error">{error}</p>}
      <BalanceModal
        isOpen={isModalOpen}
        onClose={closeModal}
        address={address}
        crypto={selectedCrypto}
      />
      <button onClick={() => navigate('/')}>Back to Home</button>
    </div>
  );
};

export default Profile;
