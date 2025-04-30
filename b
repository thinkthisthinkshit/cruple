const bip39 = require('bip39');
const bitcoin = require('bitcoinjs-lib');
const { BIP32Factory } = require('bip32');
const ecc = require('tiny-secp256k1');
const { Wallet } = require('ethers');
const TonWeb = require('tonweb');
const CardanoWasm = require('@emurgo/cardano-serialization-lib-nodejs');
const { Keypair } = require('@solana/web3.js');
require('dotenv').config();

// Инициализация TonWeb с HTTP-провайдером
const ton = new TonWeb(new TonWeb.HttpProvider('https://toncenter.com/api/v2/jsonRPC'));

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
  LTC: 2,
  ETH: 60,
  USDT: 60,
  BNB: 60,
  AVAX: 60,
  TON: 607,
  ADA: 1815,
  SOL: 501,
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
      console.log(`Wallet:`, Wallet);
      const wallet = Wallet.fromMnemonic(SEED_PHRASE, path);
      console.log(`Generated ETH-based address: ${wallet.address}`);
      return wallet.address;
    } else if (crypto === 'TON') {
      const path = getDerivationPath(cryptoCoinTypes[crypto], userIndex);
      console.log(`Wallet:`, Wallet);
      const wallet = Wallet.fromMnemonic(SEED_PHRASE, path);
      const privateKey = wallet.privateKey.slice(2); // Убираем '0x'
      const privateKeyBuffer = Buffer.from(privateKey, 'hex');
      const keyPair = TonWeb.utils.nacl.sign.keyPair.fromSeed(privateKeyBuffer.slice(0, 32));
      console.log('TonWeb.Wallets.all:', TonWeb.Wallets.all); // Отладка
      const walletOptions = {
        publicKey: keyPair.publicKey,
        wc: 0 // Workchain 0
      };
      const tonWallet = new TonWeb.Wallets.WalletContract(ton, {
        ...walletOptions,
        contract: new TonWeb.Wallets.all['v4R2'](ton, walletOptions)
      });
      const { address } = await tonWallet.getAddress();
      const tonAddress = address.toString(true, true, true);
      console.log(`Generated TON address: ${tonAddress}`);
      return tonAddress;
    } else if (crypto === 'ADA') {
      const rootKey = CardanoWasm.Bip32PrivateKey.from_bip39_entropy(seed, Buffer.from(''));
      const accountKey = rootKey.derive(1852).derive(1815).derive(0);
      const paymentKey = accountKey.derive(0).derive(0).to_public();
      const stakeKey = accountKey.derive(2).derive(0).to_public();
      const address = CardanoWasm.BaseAddress.new(
        CardanoWasm.NetworkInfo.mainnet().network_id(),
        CardanoWasm.StakeCredential.from_keyhash(paymentKey.to_raw_key().hash()),
        CardanoWasm.StakeCredential.from_keyhash(stakeKey.to_raw_key().hash())
      ).to_address().to_bech32();
      console.log(`Generated ADA address: ${address}`);
      return address;
    } else if (crypto === 'SOL') {
      const keypair = Keypair.fromSeed(seed.slice(0, 32));
      const address = keypair.publicKey.toBase58();
      console.log(`Generated SOL address: ${address}`);
      return address;
    } else {
      console.log(`Unsupported crypto: ${crypto}`);
      throw new Error(`Unsupported cryptocurrency: ${crypto}`);
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
