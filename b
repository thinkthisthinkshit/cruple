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
