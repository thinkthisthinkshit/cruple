app.jsx:
import { useState, useEffect } from 'react';
import { useTelegram } from './telegram';
import CountrySelector from './components/CountrySelector';
import ResourceSelector from './components/ResourceSelector';
import BalanceModal from './components/BalanceModal';
import axios from 'axios';

function App() {
  const { tg, user } = useTelegram();
  const [country, setCountry] = useState('');
  const [resource, setResource] = useState('');
  const [balance, setBalance] = useState(null);
  const [address, setAddress] = useState('');
  const [showModal, setShowModal] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.ready();
      tg.MainButton.setText('Купить').show().onClick(handleBuy);
      fetchBalance();
    }
  }, [tg]);

  const fetchBalance = async () => {
    try {
      const res = await axios.get(`${API_URL}/balance/${user?.id}`, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setBalance(res.data.balance);
      setAddress(res.data.address);
    } catch (err) {
      console.error('Fetch balance error:', err);
      tg?.showPopup({ message: `Ошибка загрузки баланса: ${err.message}` });
    }
  };

  const handleBuy = async () => {
    if (!country || !resource) {
      tg?.showPopup({ message: 'Выберите страну и ресурс' });
      return;
    }
    try {
      const res = await axios.post(
        `${API_URL}/buy`,
        { telegram_id: user?.id, country, resource },
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      if (res.data.success) {
        tg?.showPopup({ message: `Код: ${res.data.code}` });
        fetchBalance();
      } else {
        setShowModal(true);
      }
    } catch (err) {
      console.error('Buy error:', err);
      tg?.showPopup({ message: `Ошибка покупки: ${err.message}` });
    }
  };

  const handleTopUp = async () => {
    try {
      const res = await axios.post(`${API_URL}/generate-address/${user?.id}`, null, {
        headers: {
          'telegram-init-data': tg?.initData || '',
          'ngrok-skip-browser-warning': 'true',
        },
      });
      setAddress(res.data.address);
      setShowModal(true);
    } catch (err) {
      console.error('Generate address error:', err);
      tg?.showPopup({ message: `Ошибка генерации адреса: ${err.message}` });
    }
  };

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">SimCard Mini App</h1>
      <CountrySelector onSelect={setCountry} />
      <ResourceSelector onSelect={setResource} />
      <div className="mt-4">
        <p className="text-lg">Баланс: {balance !== null ? `${balance} BTC` : 'Загрузка...'}</p>
      </div>
      {showModal && (
        <BalanceModal
          address={address}
          onClose={() => setShowModal(false)}
          onCopy={() => navigator.clipboard.writeText(address)}
        />
      )}
    </div>
  );
}

export default App;}






server.js:
const express = require('express');
const cors = require('cors');
const routes = require('./src/routes');
const axios = require('axios');

const app = express();

app.use(cors({ origin: '*' }));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.headers['user-agent']}`);
  next();
});
app.use('/', routes);

const BOT_TOKEN = process.env.BOT_TOKEN;
const WEB_APP_URL = 'https://frontend-abc123.ngrok.io';

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands`, {
  commands: [{ command: 'start', description: 'Открыть SimCard Mini App' }],
}).catch(err => console.error('Ошибка настройки команд:', err));

axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/setChatMenuButton`, {
  menu_button: {
    type: 'web_app',
    text: 'OPEN',
    web_app: { url: WEB_APP_URL },
  },
}).catch(err => console.error('Ошибка настройки кнопки:', err));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));





