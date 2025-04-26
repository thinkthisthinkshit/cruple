<!DOCTYPE html>
   <html lang="en">
     <head>
       <meta charset="UTF-8" />
       <meta name="viewport" content="width=device-width, initial-scale=1.0" />
       <title>BTC Signals</title>
     </head>
     <body>
       <div id="root"></div>
       <script type="module" src="/src/main.jsx"></script>
     </body>
   </html>





main.jsx:
import React from 'react';
   import ReactDOM from 'react-dom/client';
   import App from './App.jsx';
   import './index.css';

   ReactDOM.createRoot(document.getElementById('root')).render(
     <React.StrictMode>
       <App />
     </React.StrictMode>
   );





app.jsx:
import WalletForm from './components/WalletForm';

   function App() {
     return (
       <div className="p-4">
         <h1>BTC Signals</h1>
         <WalletForm userId="12345" />
       </div>
     );
   }

   export default App;


index.css
@tailwind base;
   @tailwind components;
   @tailwind utilities;













