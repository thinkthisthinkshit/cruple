import { useState, useEffect } from 'react';
   import QRCode from 'qrcode.react';

   function WalletForm({ userId }) {
     const [address, setAddress] = useState('');
     const [balance, setBalance] = useState(0);
     const [error, setError] = useState(null);

     useEffect(() => {
       fetch(`https://abcd-1234.ngrok-free.app/api/wallet/${userId}`, {
         mode: 'cors',
         headers: {
           'Content-Type': 'application/json',
         },
       })
         .then(res => {
           if (!res.ok) {
             throw new Error(`HTTP error! status: ${res.status}`);
           }
           return res.json();
         })
         .then(data => {
           if (data.error) {
             setError(data.error);
             console.error('API error:', data.error);
             return;
           }
           setAddress(data.address);
           setBalance(data.balance);
           console.log('Wallet data:', data);
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
       <div className="mb-4">
         {error && <p className="text-red-500">Error: {error}</p>}
         <p className="text-lg">Balance: {balance} TON</p>
         <p className="text-sm break-all">Address: {address}</p>
         {address && (
           <div className="mt-2">
             <QRCode value={address} size={128} />
           </div>
         )}
         <button
           className="bg-blue-500 text-white p-2 rounded mt-2"
           onClick={topUp}
           disabled={!address}
         >
           Top Up via Telegram Wallet
         </button>
       </div>
     );
   }

   export default WalletForm;
