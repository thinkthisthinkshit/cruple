PurchaseResult.js:
import { useState, useEffect } from 'react';
import { useTelegram } from '../telegram';
import axios from 'axios';

function PurchaseResult({ language, purchaseData, onBack, balance, selectedCrypto, onGoToPurchases }) {
  const { tg } = useTelegram();
  const [code, setCode] = useState(purchaseData.code || '');
  const [isLoadingCode, setIsLoadingCode] = useState(purchaseData.code ? true : false);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

  useEffect(() => {
    if (tg) {
      tg.BackButton.show().onClick(onBack);
    }
    return () => tg?.BackButton.hide();
  }, [tg, onBack]);

  useEffect(() => {
    if (purchaseData.service === 'sms' && !code && purchaseData.code) {
      const timer = setTimeout(() => {
        setCode(purchaseData.code);
        setIsLoadingCode(false);
      }, 10000); // 10 секунд
      return () => clearTimeout(timer);
    }
  }, [purchaseData.service, purchaseData.code, code]);

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    tg?.showPopup({ message: language === 'ru' ? 'Скопировано!' : 'Copied!' });
  };

  const completePurchase = async () => {
    try {
      await axios.post(
        `${API_URL}/complete-purchase/${purchaseData.purchase_id}`,
        {},
        {
          headers: {
            'telegram-init-data': tg?.initData || '',
            'ngrok-skip-browser-warning': 'true',
          },
        }
      );
      tg?.showPopup({ message: language === 'ru' ? 'Покупка завершена!' : 'Purchase completed!' });
      onGoToPurchases();
    } catch (err) {
      console.error('Complete purchase error:', err);
      tg?.showPopup({
        message: language === 'ru' ? 'Ошибка завершения покупки' : 'Error completing purchase',
      });
    }
  };

  const texts = {
    ru: {
      title: 'Результат покупки',
      number: 'Номер:',
      price: 'Цена:',
      code: 'Код:',
      waiting: 'Ожидание кода...',
      copy: 'Копировать',
      complete: 'Принять код',
      toPurchases: 'В мои покупки →',
      expiry: 'Действует до:',
      balance: 'Баланс:',
      crypto: 'Валюта:',
    },
    en: {
      title: 'Purchase Result',
      number: 'Number:',
      price: 'Price:',
      code: 'Code:',
      waiting: 'Waiting for code...',
      copy: 'Copy',
      complete: 'Accept Code',
      toPurchases: 'To My Purchases →',
      expiry: 'Valid until:',
      balance: 'Balance:',
      crypto: 'Currency:',
    },
  };

  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return date.toLocaleString(language === 'ru' ? 'ru-RU' : 'en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const isFromPurchaseHistory = !!purchaseData.code; // Проверяем, открыто ли из "Мои покупки"

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-4 text-center">{texts[language].title}</h1>
      <div className="p-4 bg-gray-100 rounded-lg shadow">
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].number}</p>
          <div className="flex items-center">
            <p>{purchaseData.number}</p>
            <button
              className="ml-2 text-blue-500"
              onClick={() => copyToClipboard(purchaseData.number)}
            >
              {texts[language].copy}
            </button>
          </div>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].price}</p>
          <p>{purchaseData.price}</p>
        </div>
        {isFromPurchaseHistory && purchaseData.service === 'sms' && (
          <div className="flex justify-between mb-2">
            <p className="font-semibold">{texts[language].code}</p>
            <div className="flex items-center">
              {isLoadingCode ? (
                <div className="flex items-center">
                  <div className="spinner border-t-2 border-blue-500 rounded-full w-5 h-5 animate-spin mr-2"></div>
                  <p>{texts[language].waiting}</p>
                </div>
              ) : (
                <>
                  <p>{code || texts[language].waiting}</p>
                  {code && (
                    <button
                      className="ml-2 text-blue-500"
                      onClick={() => copyToClipboard(code)}
                    >
                      {texts[language].copy}
                    </button>
                  )}
                </>
              )}
            </div>
          </div>
        )}
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].expiry}</p>
          <p>{formatDate(purchaseData.expiry)}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].balance}</p>
          <p>{balance}</p>
        </div>
        <div className="flex justify-between mb-2">
          <p className="font-semibold">{texts[language].crypto}</p>
          <p>{selectedCrypto}</p>
        </div>
        {isFromPurchaseHistory && purchaseData.service === 'sms' && !isLoadingCode && code && (
          <button
            className="mt-4 w-full bg-green-500 text-white px-4 py-2 rounded"
            onClick={completePurchase}
          >
            {texts[language].complete}
          </button>
        )}
        {!isFromPurchaseHistory && (
          <button
            className="mt-4 w-full bg-blue-500 text-white px-4 py-2 rounded"
            onClick={onGoToPurchases}
          >
            {texts[language].toPurchases}
          </button>
        )}
      </div>
      <style>
        {`
          .spinner {
            border: 2px solid #f3f3f3;
            border-top: 2px solid #3498db;
            border-radius: 50%;
            width: 20px;
            height: 20px;
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

export default PurchaseResult;








