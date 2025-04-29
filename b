const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const { BIP32Factory } = require('bip32');
const ecc = require('tiny-secp256k1');
const { ethers } = require('ethers');
const TonWeb = require('tonweb');
require('dotenv').config();

const SEED_PHRASE = process.env.SEED_PHRASE;

if (!SEED_PHRASE) {
  throw new Error('SEED_PHRASE not set in .env');
}

if (!bip39.validateMnemonic(SEED_PHRASE)) {
  throw new Error('Invalid SEED_PHRASE');
}

const bip32 = BIP32Factory(ecc);

const getDerivationPath = (coinType, userIndex) => {
  return `m/44'/${coinType}'/0'/0/${userIndex}`;
};

const cryptoCoinTypes = {
  BTC: 0,
  ETH: 60,
  USDT: 60,
  BNB: 60,
  ADA: 1815,
  SOL: 501,
  XRP: 144,
  DOT: 354,
  LTC: 2,
  XMR: 128,
  TRX: 195,
  AVAX: 60,
  ATOM: 118,
  XTZ: 1729,
  ALGO: 283,
  NOT: 607,
  HMSTR: 607,
};

const generateAddress = async (telegram_id, crypto) => {
  try {
    console.log(`Generating address for telegram_id: ${telegram_id}, crypto: ${crypto}`);
    const userIndex = parseInt(telegram_id, 10) % 1000000;
    const seed = await bip39.mnemonicToSeed(SEED_PHRASE);
    console.log(`Seed generated, length: ${seed.length}`);

    if (['BTC', 'LTC'].includes(crypto)) {
      const network = crypto === 'BTC' ? bitcoin.networks.bitcoin : bitcoin.networks.litecoin;
      console.log(`Using network: ${crypto === 'BTC' ? 'bitcoin' : 'litecoin'}`);
      const root = bip32.fromSeed(seed, network);
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      console.log(`Derivation path: ${path}`);
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({ pubkey: child.publicKey, network });
      console.log(`Generated address: ${address}`);
      return address;
    } else if (['ETH', 'USDT', 'BNB', 'AVAX'].includes(crypto)) {
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      const wallet = ethers.Wallet.fromMnemonic(SEED_PHRASE, path);
      console.log(`Generated ETH-based address: ${wallet.address}`);
      return wallet.address;
    } else if (['NOT', 'HMSTR'].includes(crypto)) {
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      const wallet = ethers.Wallet.fromMnemonic(SEED_PHRASE, path);
      const keyPair = TonWeb.utils.nacl.sign.keyPair.fromSeed(wallet.signingKey.privateKey.slice(0, 32));
      const tonWallet = new TonWeb.Wallets.WalletV4({ publicKey: keyPair.publicKey });
      const { address } = await tonWallet.getAddress();
      const tonAddress = address.toString(true, true, true);
      console.log(`Generated TON address: ${tonAddress}`);
      return tonAddress;
    } else {
      console.log(`Placeholder address for ${crypto}`);
      return `PlaceholderAddress_${crypto}_${telegram_id}`;
    }
  } catch (error) {
    console.error(`Error generating address for ${crypto}:`, error);
    throw new Error(`Failed to generate address for ${crypto}`);
  }
};

const getBalance = async (address) => {
  console.log(`Fetching balance for address: ${address}`);
  return 0;
};

module.exports = { generateAddress, getBalance };





