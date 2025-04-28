App.jsx:
import { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import SimCardForm from './components/SimCardForm';
import SimCardCatalog from './components/SimCardCatalog';
import MySimCards from './components/MySimCards';

function App() {
  const [userId] = useState('12345'); // Тестовый userId, позже из Telegram.initData

  return (
    <Router>
      <div className="min-h-screen bg-telegram-bg p-4">
        <h1 className="text-2xl font-bold text-telegram-blue mb-4">Virtual SIM App</h1>
        <nav className="mb-4 flex space-x-4">
          <Link to="/" className="text-telegram-blue hover:underline">Wallet</Link>
          <Link to="/catalog" className="text-telegram-blue hover:underline">Catalog</Link>
          <Link to="/my-sim-cards" className="text-telegram-blue hover:underline">My SIMs</Link>
        </nav>
        <Routes>
          <Route path="/" element={<SimCardForm userId={userId} />} />
          <Route path="/catalog" element={<SimCardCatalog userId={userId} />} />
          <Route path="/my-sim-cards" element={<MySimCards userId={userId} />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;







SimCardForm.jsx:
import { useState, useEffect } from 'react';
import QRCode from 'qrcode.react';

function SimCardForm({ userId }) {
  const [address, setAddress] = useState('');
  const [balance, setBalance] = useState(0);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`https://d0ce-109-206-241-94.ngrok-free.app/api/wallet/${userId}`, {
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      },
    })
      .then(res => {
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        return res.json();
      })
      .then(data => {
        console.log('API response:', data);
        if (data.error) {
          setError(data.error);
          return;
        }
        setAddress(data.address || '');
        setBalance(data.balance || 0);
      })
      .catch(error => {
        setError(error.message);
        console.error('Failed to fetch wallet:', error);
      });
  }, [userId]);

  const topUp = () => {
    if (address) {
      window.Telegram.WebApp.openTelegramLink(
        `https://t.me/wallet?start=send&address=${encodeURIComponent(address)}&amount=1`
      );
    } else {
      setError('No wallet address available');
    }
  };

  return (
    <div className="bg-white p-4 rounded shadow">
      {error && <p className="text-red-500 mb-2">Error: {error}</p>}
      <h2 className="text-xl font-bold mb-2">Your Wallet</h2>
      <p className="text-lg">Balance: {balance} TON</p>
      <p className="text-sm break-all">Address: {address}</p>
      {address && (
        <div className="mt-2">
          <QRCode value={address} size={128} />
        </div>
      )}
      <button
        className="mt-4 bg-blue-500 text-white p-2 rounded hover:bg-blue-600 disabled:bg-gray-400"
        onClick={topUp}
        disabled={!address}
      >
        Top Up
      </button>
    </div>
  );
}

export default SimCardForm;






SimCardCatalog.jsx:
import { useState, useEffect } from 'react';

function SimCardCatalog() {
  const [simCards, setSimCards] = useState([]);
  const [error, setError] = useState(null);
  const [filterCountry, setFilterCountry] = useState('');

  useEffect(() => {
    fetch('https://d0ce-109-206-241-94.ngrok-free.app/api/sim-cards', {
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      },
    })
      .then(res => {
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        return res.json();
      })
      .then(data => {
        setSimCards(data);
      })
      .catch(error => {
        setError(error.message);
        console.error('Failed to fetch SIM cards:', error);
      });
  }, []);

  const filteredSimCards = filterCountry
    ? simCards.filter(sim => sim.country.toLowerCase().includes(filterCountry.toLowerCase()))
    : simCards;

  const purchaseSim = async (simId) => {
    try {
      const res = await fetch('https://d0ce-109-206-241-94.ngrok-free.app/api/sim-cards/purchase', {
        method: 'POST',
        mode: 'cors',
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true'
        },
        body: JSON.stringify({ simId, userId: '12345' }) // Тестовый userId
      });
      if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
      window.Telegram.WebApp.showAlert('SIM card purchased!');
    } catch (error) {
      setError(error.message);
    }
  };

  return (
    <div className="bg-white p-4 rounded shadow">
      {error && <p className="text-red-500 mb-2">Error: {error}</p>}
      <h2 className="text-xl font-bold mb-2">SIM Card Catalog</h2>
      <input
        type="text"
        placeholder="Filter by country"
        className="mb-4 p-2 border rounded w-full"
        value={filterCountry}
        onChange={e => setFilterCountry(e.target.value)}
      />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {filteredSimCards.map(sim => (
          <div key={sim.id} className="p-4 border rounded">
            <p><strong>Country:</strong> {sim.country}</p>
            <p><strong>Price:</strong> {sim.price} TON</p>
            <p><strong>Duration:</strong> {sim.duration} days</p>
            <button
              className="mt-2 bg-green-500 text-white p-2 rounded hover:bg-green-600"
              onClick={() => purchaseSim(sim.id)}
            >
              Buy
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default SimCardCatalog;








MySimCards.jsx:
import { useState, useEffect } from 'react';

function MySimCards({ userId }) {
  const [simCards, setSimCards] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`https://d0ce-109-206-241-94.ngrok-free.app/api/sim-cards/${userId}`, {
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      },
    })
      .then(res => {
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        return res.json();
      })
      .then(data => {
        setSimCards(data);
      })
      .catch(error => {
        setError(error.message);
        console.error('Failed to fetch SIM cards:', error);
      });
  }, [userId]);

  return (
    <div className="bg-white p-4 rounded shadow">
      {error && <p className="text-red-500 mb-2">Error: {error}</p>}
      <h2 className="text-xl font-bold mb-2">My SIM Cards</h2>
      {simCards.length === 0 ? (
        <p>No SIM cards purchased yet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {simCards.map(sim => (
            <div key={sim.id} className="p-4 border rounded">
              <p><strong>Number:</strong> {sim.number}</p>
              <p><strong>Country:</strong> {sim.country}</p>
              <p><strong>Status:</strong> {sim.status}</p>
              <p><strong>Expires:</strong> {new Date(sim.expiry).toLocaleDateString()}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default MySimCards;



index.css:
@tailwind base;
@tailwind components;
@tailwind utilities;








vite.config.js:
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
  build: {
    minify: 'esbuild',
    chunkSizeWarningLimit: 1000,
  },
});






index.html:
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Virtual SIM App</title>
  <script src="https://telegram.org/js/telegram-web-app.js"></script>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>





main.jsx:
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);






