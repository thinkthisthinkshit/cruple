curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6InRlc3R1c2VyIiwicm9sZSI6InZpZXdlciIsImlkIjoiNjgwODEwOWIxMjEzMTlkMDE2OGY3OWRjIiwiaWF0IjoxNzQ1MzU5MDAzfQ.i6EDtaCci7xwLm0b1P9lb2iArVq8sn_MpqA_M4cGUFE" http://localhost:3000/balance/testuser

app.post("/webhook/deposit", async (req, res) => {
  console.log("Webhook received:", JSON.stringify(req.body, null, 2));
  if (req.query.secret !== "justbetweenus") {
    console.log("Invalid secret received");
    return res.status(403).send("Invalid secret");
  }
  try {
    const { hash, outputs } = req.body;
    for (const output of outputs) {
      const user = await User.findOne({ bitcoinAddress: output.addresses[0] });
      if (user) {
        const btcAmount = output.value / 1e8;
        const btcPrice = await getBtcPrice();
        const usdAmount = btcAmount * btcPrice;
        user.balance += usdAmount;
        await user.save();
        console.log(`Balance updated for ${user.username}: +$${usdAmount}`);
        io.to(user._id.toString()).emit("depositUpdate", {
          username: user.username,
          amount: usdAmount,
          txHash: hash,
        });
        break;
      }
    }
    res.status(200).send("OK");
  } catch (err) {
    console.error("Webhook error:", err);
    res.status(500).send("Error");
  }
});







curl -X POST https://abcd-1234-efgh-5678.ngrok.io/webhook/deposit?secret=justbetweenus -H "Content-Type: application/json" -d "{\"hash\":\"test\",\"outputs\":[{\"addresses\":[\"mvc2RT4fXsS4j6S3Cnjuf6GKcHZS1vMB7F\"],\"value\":10000}]}"



curl -X POST https://abcd-1234-efgh-5678.ngrok.io/webhook/deposit?secret=justbetweenus -H "Content-Type: application/json" -d '{"hash":"test","outputs":[{"addresses":["mvc2RT4fXsS4j6S3Cnjuf6GKcHZS1vMB7F"],"value":10000}]}'






curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6InRlc3R1c2VyIiwicm9sZSI6InZpZXdlciIsImlkIjoiNjgwODEwOWIxMjEzMTlkMDE2OGY3OWRjIiwiaWF0IjoxNzQ1MzU5MDAzfQ.i6EDtaCci7xwLm0b1P9lb2iArVq8sn_MpqA_M4cGUFE" http://localhost:3000/deposit/address




curl -X POST http://localhost:3000/register -H 'Content-Type: application/json' -d '{"username":"testuser","password":"testpassword"}'
curl -X POST http://localhost:3000/register -H "Content-Type: application/json" -d "{\"username\":\"testuser\",\"password\":\"testpassword\"}"
curl -X POST http://localhost:3000/register -H "Content-Type: application/json" -d '{"username":"testuser","password":"testpassword"}'

curl -H "Authorization: Bearer твой_токен" http://localhost:3000/deposit/address

const express = require("express");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const cors = require("cors");
const http = require("http");
const socketIo = require("socket.io");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const QRCode = require("qrcode");
const User = require("./models/User");
const Post = require("./models/Post");
const Message = require("./models/Message");
const bitcoin = require("bitcoinjs-lib");
const bip32 = require("bip32");
const bip39 = require("bip39");
const axios = require("axios");
require("dotenv").config(); // Загрузка переменных окружения

// Модель Notification
const NotificationSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  type: { type: String, enum: ["like", "comment", "subscription"], required: true },
  fromUserId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  fromUsername: { type: String, required: true },
  postId: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
  text: { type: String },
  read: { type: Boolean, default: false },
  timestamp: { type: Date, default: Date.now },
});
const Notification = mongoose.model("Notification", NotificationSchema);

const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: "*" } });

// Настройка Multer
const uploadDir = path.join(__dirname, "Uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "Uploads/");
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|mp4/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);
    if (extname && mimetype) {
      return cb(null, true);
    }
    cb(new Error("Только изображения (.jpg, .png) и видео (.mp4)"));
  },
});

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "Uploads")));

// Подключение к MongoDB
mongoose
  .connect("mongodb://localhost:27017/btc-deposit-app", {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => console.error("MongoDB connection error:", err));

// Middleware
const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Требуется авторизация" });
  try {
    const decoded = jwt.verify(token, "secret");
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: "Недействительный токен" });
  }
};

const adminMiddleware = (req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ error: "Доступ только для админов" });
  }
  next();
};

// HD-Wallet настройки
const seedPhrase = process.env.SEED_PHRASE || bip39.generateMnemonic(); // В продакшене хранить в HSM
const network = bitcoin.networks.testnet; // Используем testnet для разработки
const seed = bip39.mnemonicToSeedSync(seedPhrase);
const root = bip32.fromSeed(seed, network);

// Генерация Bitcoin-адреса для пользователя
const generateBitcoinAddress = (userIndex) => {
  const path = `m/44'/1'/0'/0/${userIndex}`; // BIP-44 для testnet
  const child = root.derivePath(path);
  const { address } = bitcoin.payments.p2pkh({
    pubkey: child.publicKey,
    network,
  });
  return address;
};

// Конвертация BTC в USD через CoinGecko
const getBtcPrice = async () => {
  try {
    const response = await axios.get(
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
    );
    return response.data.bitcoin.usd;
  } catch (err) {
    console.error("Ошибка получения цены BTC:", err);
    return 60000; // Fallback-цена
  }
};

// Проверка подписки
const checkSubscription = async (userId, authorUsername) => {
  const author = await User.findOne({ username: authorUsername });
  if (!author) return false;
  return author.subscribers.includes(userId);
};

// Функция для создания chatId
const generateChatId = (user1, user2) => {
  return [user1, user2].sort().join("_");
};

// Socket.IO
io.on("connection", (socket) => {
  socket.on("joinPost", (postId) => {
    socket.join(postId);
  });
  socket.on("joinChat", (chatId) => {
    socket.join(chatId);
  });
  socket.on("joinNotifications", (userId) => {
    socket.join(userId);
  });
  socket.on("disconnect", () => {});
});

// Эндпоинт для получения адреса для депозита
app.get("/deposit/address", authMiddleware, async (req, res) => {
  try {
    let user = await User.findById(req.user.id);
    if (!user.bitcoinAddress) {
      const userIndex = (await User.countDocuments()) + 1; // Уникальный индекс
      const address = generateBitcoinAddress(userIndex);
      user.bitcoinAddress = address;
      await user.save();

      // Создание вебхука для BlockCypher
      const webhookData = {
        event: "tx-confirmation",
        address: address,
        url: "https://1234-5678-90ab-cdef.ngrok.io/webhook/deposit?secret=justbetweenus",
        token: process.env.BLOCKCYPHER_TOKEN,
      };
      try {
        await axios.post(
          "https://api.blockcypher.com/v1/btc/test3/hooks",
          webhookData,
          { headers: { "Content-Type": "application/json" } }
        );
        console.log(`Webhook created for address: ${address}`);
      } catch (webhookErr) {
        console.error("Ошибка создания вебхука:", webhookErr.response?.data || webhookErr.message);
      }
    }
    const qrCode = await QRCode.toDataURL(user.bitcoinAddress);
    res.json({ address: user.bitcoinAddress, qrCode });
  } catch (err) {
    console.error("Ошибка генерации адреса:", err);
    res.status(500).json({ error: "Ошибка генерации адреса" });
  }
});

// Webhook для BlockCypher (обрабатываем входящие транзакции)
app.post("/webhook/deposit", async (req, res) => {
  if (req.query.secret !== "justbetweenus") {
    return res.status(403).send("Invalid secret");
  }
  const { hash, outputs } = req.body;
  try {
    for (const output of outputs) {
      const user = await User.findOne({ bitcoinAddress: output.addresses[0] });
      if (user) {
        const btcAmount = output.value / 1e8; // Конвертация сатоши в BTC
        const btcPrice = await getBtcPrice();
        const usdAmount = btcAmount * btcPrice;
        user.balance += usdAmount;
        await user.save();
        io.to(user._id.toString()).emit("depositUpdate", {
          username: user.username,
          amount: usdAmount,
          txHash: hash,
        });
        break;
      }
    }
    res.status(200).send("OK");
  } catch (err) {
    console.error("Webhook error:", err);
    res.status(500).send("Error");
  }
});

// Эндпоинты уведомлений
app.get("/notifications", authMiddleware, async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.user.id })
      .sort({ timestamp: -1 })
      .limit(50);
    res.json(notifications);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения уведомлений" });
  }
});

app.get("/notifications/unread", authMiddleware, async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: req.user.id,
      read: false,
    });
    res.json({ unreadCount });
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения непрочитанных уведомлений" });
  }
});

app.post("/notifications/read", authMiddleware, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user.id, read: false },
      { read: true }
    );
    io.to(req.user.id).emit("notificationsRead", { userId: req.user.id });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка отметки уведомлений" });
  }
});

// Эндпоинт для имен пользователей
app.post("/users/usernames", async (req, res) => {
  const { userIds } = req.body;
  try {
    const users = await User.find({ _id: { $in: userIds } }, "username");
    const userMap = {};
    users.forEach((user) => {
      userMap[user._id] = user.username;
    });
    res.json(userMap);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения имен пользователей" });
  }
});

// Эндпоинты сообщений
app.get("/messages", authMiddleware, async (req, res) => {
  try {
    const messages = await Message.aggregate([
      {
        $match: {
          $or: [{ from: req.user.username }, { to: req.user.username }],
        },
      },
      {
        $sort: { timestamp: -1 },
      },
      {
        $group: {
          _id: "$chatId",
          lastMessage: { $first: "$text" },
          timestamp: { $first: "$timestamp" },
          with: {
            $first: {
              $cond: [
                { $eq: ["$from", req.user.username] },
                "$to",
                "$from",
              ],
            },
          },
        },
      },
      {
        $sort: { timestamp: -1 },
      },
    ]);

    const chatsWithUnread = await Promise.all(
      messages.map(async (chat) => {
        const unreadCount = await Message.countDocuments({
          chatId: chat._id,
          to: req.user.username,
          read: false,
        });
        return {
          id: chat._id,
          with: chat.with,
          lastMessage: chat.lastMessage,
          timestamp: chat.timestamp,
          unreadCount,
        };
      })
    );

    res.json(chatsWithUnread);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения чатов" });
  }
});

app.get("/messages/unread", authMiddleware, async (req, res) => {
  try {
    const unreadCount = await Message.countDocuments({
      to: req.user.username,
      read: false,
    });
    res.json({ unreadMessagesCount: unreadCount });
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения непрочитанных сообщений" });
  }
});

app.get("/messages/:chatId", authMiddleware, async (req, res) => {
  try {
    const [user1, user2] = req.params.chatId.split("_");
    if (![user1, user2].includes(req.user.username)) {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    const messages = await Message.find({ chatId: req.params.chatId }).sort({
      timestamp: 1,
    });
    res.json(messages);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения сообщений" });
  }
});

app.post("/messages/:chatId", authMiddleware, async (req, res) => {
  const { text } = req.body;
  if (!text) {
    return res.status(400).json({ error: "Текст сообщения обязателен" });
  }
  try {
    const [user1, user2] = req.params.chatId.split("_");
    if (!user1 || !user2) {
      return res.status(400).json({ error: "Неверный формат chatId" });
    }
    if (![user1, user2].includes(req.user.username)) {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    const recipient = user1 === req.user.username ? user2 : user1;
    const recipientUser = await User.findOne({ username: recipient });
    if (!recipientUser) {
      return res.status(404).json({ error: "Получатель не найден" });
    }
    const message = new Message({
      chatId: req.params.chatId,
      from: req.user.username,
      to: recipient,
      text,
    });
    await message.save();
    io.to(req.params.chatId).emit("newMessage", message);
    res.json(message);
  } catch (err) {
    res.status(500).json({ error: "Ошибка отправки сообщения" });
  }
});

app.post("/messages/:chatId/read", authMiddleware, async (req, res) => {
  try {
    const [user1, user2] = req.params.chatId.split("_");
    if (![user1, user2].includes(req.user.username)) {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    const updated = await Message.updateMany(
      { chatId: req.params.chatId, to: req.user.username, read: false },
      { read: true }
    );
    io.to(req.params.chatId).emit("messagesRead", { chatId: req.params.chatId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка отметки сообщений" });
  }
});

app.post("/messages/start", authMiddleware, async (req, res) => {
  const { username } = req.body;
  if (!username) {
    return res.status(400).json({ error: "Username обязателен" });
  }
  if (typeof username !== "string" || username.trim() === "") {
    return res.status(400).json({ error: "Username должен быть строкой" });
  }
  try {
    const targetUser = await User.findOne({ username });
    if (!targetUser) {
      return res.status(404).json({ error: "Пользователь не найден" });
    }
    if (req.user.username === username) {
      return res.status(400).json({ error: "Нельзя начать чат с собой" });
    }
    const chatId = generateChatId(req.user.username, username);
    res.json({ chatId });
  } catch (err) {
    res.status(500).json({ error: "Ошибка начала чата" });
  }
});

// Загрузка медиа
app.post("/upload-media", authMiddleware, upload.single("media"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "Файл не загружен" });
    }
    const mediaUrl = `http://localhost:3000/uploads/${req.file.filename}`;
    res.json({ mediaUrl });
  } catch (err) {
    res.status(500).json({ error: err.message || "Ошибка загрузки медиа" });
  }
});

// Проверка подписки
app.get("/check-subscription/:username", authMiddleware, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ error: "Пользователь не найден" });
    res.json({ isSubscribed: user.subscribers.includes(req.user.id) });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Регистрация
app.post("/register", async (req, res) => {
  const { username, password } = req.body;
  try {
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: "Пользователь уже существует" });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, password: hashedPassword });
    await user.save();
    const token = jwt.sign(
      { username, role: user.role, authorNickname: user.authorNickname, id: user._id },
      "secret"
    );
    res.json({ username, role: user.role, authorNickname: user.authorNickname, token });
  } catch (err) {
    res.status(500).json({ error: "Ошибка регистрации" });
  }
});

// Вход
app.post("/login", async (req, res) => {
  const { username, password } = req.body;
  try {
    const user = await User.findOne({ username });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: "Неверный логин или пароль" });
    }
    const token = jwt.sign(
      { username, role: user.role, authorNickname: user.authorNickname, id: user._id },
      "secret"
    );
    res.json({ username, role: user.role, authorNickname: user.authorNickname, token });
  } catch (err) {
    res.status(500).json({ error: "Ошибка входа" });
  }
});

// Стать автором
app.post("/become-author", authMiddleware, async (req, res) => {
  const { authorNickname } = req.body;
  if (!authorNickname) {
    return res.status(400).json({ error: "Никнейм обязателен" });
  }
  try {
    const existingAuthor = await User.findOne({ authorNickname });
    if (existingAuthor) {
      return res.status(400).json({ error: "Никнейм уже занят" });
    }
    const user = await User.findOneAndUpdate(
      { _id: req.user.id },
      { role: "author", authorNickname },
      { new: true }
    );
    const token = jwt.sign(
      { username: user.username, role: user.role, authorNickname: user.authorNickname, id: user._id },
      "secret"
    );
    res.json({
      username: user.username,
      role: user.role,
      authorNickname: user.authorNickname,
      token,
    });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Задать цену подписки
app.post("/subscription-price", authMiddleware, async (req, res) => {
  const { price } = req.body;
  if (price < 0 || isNaN(price)) {
    return res.status(400).json({ error: "Некорректная цена" });
  }
  try {
    const user = await User.findOneAndUpdate(
      { _id: req.user.id },
      { subscriptionPrice: price },
      { new: true }
    );
    res.json({ subscriptionPrice: user.subscriptionPrice });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Подписаться/отписаться
app.post("/subscribe/:username", authMiddleware, async (req, res) => {
  try {
    const author = await User.findOne({ username: req.params.username });
    if (!author) {
      return res.status(404).json({ error: "Автор не найден" });
    }
    if (req.user.id === author._id.toString()) {
      return res.status(400).json({ error: "Нельзя подписаться на себя" });
    }
    const isSubscribed = author.subscribers.includes(req.user.id);
    if (isSubscribed) {
      author.subscribers = author.subscribers.filter(
        (id) => id.toString() !== req.user.id
      );
    } else {
      author.subscribers.push(req.user.id);
      const notification = new Notification({
        userId: author._id,
        type: "subscription",
        fromUserId: req.user.id,
        fromUsername: req.user.username,
      });
      await notification.save();
      io.to(author._id.toString()).emit("newNotification", notification);
    }
    await author.save();
    io.emit("subscriptionUpdate", {
      authorId: author._id,
      subscribers: author.subscribers.length,
    });
    res.json({
      subscribed: !isSubscribed,
      subscriptionPrice: author.subscriptionPrice,
    });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Получить данные пользователя
app.get("/users/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ error: "Пользователь не найден" });
    res.json({
      username: user.username,
      authorNickname: user.authorNickname,
      role: user.role,
      subscriptionPrice: user.subscriptionPrice,
      subscribers: user.subscribers.length,
      avatarUrl: user.avatarUrl,
      coverPhoto: user.coverPhoto,
      about: user.about,
      socialLinks: user.socialLinks,
    });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Получить топ-10 авторов
app.get("/users", async (req, res) => {
  try {
    const users = await User.find(
      { role: "author" },
      "username authorNickname role subscriptionPrice"
    )
      .sort({ balance: -1 })
      .limit(10);
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения пользователей" });
  }
});

// Получить избранное
app.get("/favorites", authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("favorites");
    const favorites = await User.find({
      username: { $in: user.favorites },
    }).select("username authorNickname avatarUrl subscribers");
    res.json({ favorites });
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения избранного" });
  }
});

// Добавить/удалить из избранного
app.post("/toggle-favorite", authMiddleware, async (req, res) => {
  const { username } = req.body;
  if (!username) {
    return res.status(400).json({ error: "Username обязателен" });
  }
  try {
    const user = await User.findById(req.user.id);
    const targetUser = await User.findOne({ username });
    if (!targetUser) {
      return res.status(404).json({ error: "Пользователь не найден" });
    }
    const isFavorite = user.favorites.includes(username);
    if (isFavorite) {
      user.favorites = user.favorites.filter((fav) => fav !== username);
    } else {
      user.favorites.push(username);
    }
    await user.save();
    res.json({ favorites: user.favorites });
  } catch (err) {
    res.status(500).json({ error: "Ошибка обновления избранного" });
  }
});

// Поиск авторов
app.get("/search-authors", authMiddleware, async (req, res) => {
  const { query } = req.query;
  if (!query || query.trim().length < 1) {
    return res.status(400).json({ error: "Запрос поиска обязателен" });
  }
  try {
    const authors = await User.find({
      $or: [
        { username: { $regex: query, $options: "i" } },
        { authorNickname: { $regex: query, $options: "i" } },
      ],
      role: "author",
    }).select("username authorNickname subscriptionPrice subscribers avatarUrl");
    res.json({ authors });
  } catch (err) {
    res.status(500).json({ error: "Ошибка поиска авторов" });
  }
});

// Создание поста
app.post("/posts", authMiddleware, async (req, res) => {
  const { text, type, mediaUrl } = req.body;
  if (req.user.role !== "author") {
    return res.status(403).json({ error: "Только авторы могут публиковать" });
  }
  if (type === "media" && !mediaUrl) {
    return res.status(400).json({ error: "mediaUrl обязателен для медиа-постов" });
  }
  try {
    const post = new Post({
      username: req.user.username,
      text,
      type: type || "text",
      mediaUrl,
    });
    await post.save();
    io.emit("newPost", post);
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: "Ошибка публикации" });
  }
});

// Получение постов пользователя
app.get("/posts/:username", async (req, res) => {
  try {
    const posts = await Post.find({ username: req.params.username }).sort({
      timestamp: -1,
    });
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения постов" });
  }
});

// Получение всех постов
app.get("/posts", async (req, res) => {
  try {
    const posts = await Post.find().sort({ timestamp: -1 });
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения постов" });
  }
});

// Удаление поста
app.delete("/posts/:id", authMiddleware, async (req, res) => {
  try {
    const post = await Post.findOne({ _id: req.params.id });
    if (!post || post.username !== req.user.username || req.user.role !== "author") {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    await Post.deleteOne({ _id: req.params.id });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка удаления" });
  }
});

// Лайк/анлайк поста
app.post("/posts/:id/like", authMiddleware, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) {
      return res.status(404).json({ error: "Пост не найден" });
    }
    const isSubscribed = await checkSubscription(req.user.id, post.username);
    if (!isSubscribed) {
      return res.status(403).json({ error: "Требуется подписка для лайка" });
    }
    const isLiked = post.likes.includes(req.user.id);
    if (isLiked) {
      post.likes = post.likes.filter((id) => id.toString() !== req.user.id);
    } else {
      post.likes.push(req.user.id);
      const author = await User.findOne({ username: post.username });
      if (author && author._id.toString() !== req.user.id) {
        const notification = new Notification({
          userId: author._id,
          type: "like",
          fromUserId: req.user.id,
          fromUsername: req.user.username,
          postId: post._id,
        });
        await notification.save();
        io.to(author._id.toString()).emit("newNotification", notification);
      }
    }
    await post.save();
    io.to(post._id.toString()).emit("likeUpdate", {
      postId: post._id,
      likes: post.likes,
    });
    res.json({ likes: post.likes });
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Добавить комментарий
app.post("/posts/:id/comment", authMiddleware, async (req, res) => {
  const { text } = req.body;
  if (!text) {
    return res.status(400).json({ error: "Текст комментария обязателен" });
  }
  try {
    const post = await Post.findById(req.params.id);
    if (!post) {
      return res.status(404).json({ error: "Пост не найден" });
    }
    const isSubscribed = await checkSubscription(req.user.id, post.username);
    if (!isSubscribed) {
      return res.status(403).json({ error: "Требуется подписка для комментирования" });
    }
    post.comments.push({ userId: req.user.id, text, createdAt: new Date() });
    await post.save();
    const author = await User.findOne({ username: post.username });
    if (author && author._id.toString() !== req.user.id) {
      const notification = new Notification({
        userId: author._id,
        type: "comment",
        fromUserId: req.user.id,
        fromUsername: req.user.username,
        postId: post._id,
        text,
      });
      await notification.save();
      io.to(author._id.toString()).emit("newNotification", notification);
    }
    io.to(post._id.toString()).emit("commentUpdate", {
      postId: post._id,
      comments: post.comments,
    });
    res.json(post.comments);
  } catch (err) {
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Донат
app.post("/donate/:username", authMiddleware, async (req, res) => {
  const { amount } = req.body;
  if (!amount || amount <= 0) {
    return res.status(400).json({ error: "Некорректная сумма" });
  }
  try {
    const recipient = await User.findOne({ username: req.params.username });
    if (!recipient) {
      return res.status(404).json({ error: "Пользователь не найден" });
    }
    await User.updateOne(
      { username: req.params.username },
      { $inc: { balance: amount } }
    );
    io.emit("depositUpdate", { username: req.params.username, amount });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка доната" });
  }
});

// Баланс
app.get("/balance/:username", authMiddleware, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ error: "Пользователь не найден" });
    res.json({ balance: user.balance });
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения баланса" });
  }
});

// Генерация QR-кода
app.get("/generate/:username/qr", authMiddleware, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ error: "Пользователь не найден" });
    const address = user.bitcoinAddress || `bitcoin:${req.params.username}_address`;
    const qr = await QRCode.toDataURL(address);
    res.json({ qr, address });
  } catch (err) {
    res.status(500).json({ error: "Ошибка генерации QR" });
  }
});

// Обновление профиля
app.post("/update-profile", authMiddleware, upload.single("avatar"), async (req, res) => {
  try {
    const { authorNickname, about, socialLinks } = req.body;
    const updateData = { authorNickname, about };
    if (socialLinks) updateData.socialLinks = JSON.parse(socialLinks);
    if (req.file) {
      updateData.avatarUrl = `http://localhost:3000/uploads/${req.file.filename}`;
    }
    const user = await User.findOneAndUpdate(
      { _id: req.user.id },
      updateData,
      { new: true }
    );
    const token = jwt.sign(
      {
        username: user.username,
        role: user.role,
        authorNickname: user.authorNickname,
        id: user._id,
      },
      "secret"
    );
    res.json({
      username: user.username,
      role: user.role,
      authorNickname: user.authorNickname,
      about: user.about,
      socialLinks: user.socialLinks,
      avatarUrl: user.avatarUrl,
      token,
    });
  } catch (err) {
    res.status(500).json({ error: "Ошибка обновления профиля" });
  }
});

// Админ: Получить всех пользователей
app.get("/admin/users", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const users = await User.find();
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения пользователей" });
  }
});

// Админ: Получить все посты
app.get("/admin/posts", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const posts = await Post.find();
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: "Ошибка получения постов" });
  }
});

// Админ: Удалить пользователя
app.delete("/admin/users/:username", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    await User.deleteOne({ username: req.params.username });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка удаления пользователя" });
  }
});

// Админ: Удалить пост
app.delete("/admin/posts/:id", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    await Post.deleteOne({ _id: req.params.id });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: "Ошибка удаления поста" });
  }
});

// Тестовый медиа-пост
async function createTestMediaPost() {
  const post = new Post({
    username: "testuser",
    type: "media",
    mediaUrl: "http://localhost:3000/uploads/test-image.jpg",
    timestamp: new Date(),
    likes: [],
    comments: [],
  });
  await post.save();
  console.log("Test media post created");
}
createTestMediaPost();

server.listen(3000, () => console.log("Server running on port 3000"));







Models/USER.JS:
const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, default: "viewer" },
  authorNickname: { type: String },
  subscriptionPrice: { type: Number, default: 0 },
  subscribers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  balance: { type: Number, default: 0 },
  favorites: [{ type: String }],
  avatarUrl: { type: String },
  coverPhoto: { type: String },
  about: { type: String },
  socialLinks: { type: Object },
  bitcoinAddress: { type: String }, // Новый адрес для депозитов
});

module.exports = mongoose.model("User", UserSchema);





Deposit.js:
import React, { useState, useEffect, useContext } from "react";
import { AuthContext } from "../App";
import axios from "axios";
import { toast } from "react-toastify";
import io from "socket.io-client";
import { Helmet, HelmetProvider } from "react-helmet-async";

const socket = io("http://localhost:3000");

function Deposit() {
  const { user } = useContext(AuthContext);
  const [address, setAddress] = useState("");
  const [qrCode, setQrCode] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [depositStatus, setDepositStatus] = useState(null);

  useEffect(() => {
    if (!user) {
      toast.error("Войдите, чтобы пополнить баланс");
      return;
    }

    async function fetchDepositAddress() {
      try {
        const response = await axios.get("http://localhost:3000/deposit/address");
        setAddress(response.data.address);
        setQrCode(response.data.qrCode);
      } catch (err) {
        toast.error("Ошибка получения адреса для депозита");
      } finally {
        setIsLoading(false);
      }
    }
    fetchDepositAddress();

    socket.emit("joinNotifications", user.id);
    socket.on("depositUpdate", ({ username, amount, txHash }) => {
      if (username === user.username) {
        setDepositStatus({ amount, txHash });
        toast.success(`Депозит на $${amount.toFixed(2)} зачислен!`);
      }
    });

    return () => {
      socket.off("depositUpdate");
    };
  }, [user]);

  if (isLoading) {
    return <div className="spinner-container"><div className="spinner"></div></div>;
  }

  return (
    <HelmetProvider>
      <div className="deposit-container">
        <Helmet>
          <title>Пополнение баланса - CryptoAuthors</title>
          <meta name="description" content="Пополните баланс с помощью Bitcoin на CryptoAuthors." />
        </Helmet>
        <h1>Пополнение баланса</h1>
        <p>Отправьте Bitcoin на указанный адрес (используется testnet):</p>
        {address && (
          <div className="deposit-details">
            <p><strong>Адрес:</strong> {address}</p>
            {qrCode && <img src={qrCode} alt="QR Code" className="deposit-qr" />}
            <p>Минимальная сумма: 0.0001 BTC</p>
          </div>
        )}
        {depositStatus && (
          <div className="deposit-status">
            <p><strong>Статус депозита:</strong> Зачислено ${depositStatus.amount.toFixed(2)}</p>
            <p><strong>Хэш транзакции:</strong> <a href={`https://live.blockcypher.com/btc-testnet/tx/${depositStatus.txHash}`} target="_blank" rel="noopener noreferrer">{depositStatus.txHash}</a></p>
          </div>
        )}
      </div>
    </HelmetProvider>
  );
}

export default Deposit;






.deposit-container {
  max-width: 600px;
  margin: 0 auto;
  padding: 24px;
  text-align: center;
}

.deposit-details {
  background: #ffffff;
  padding: 16px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  margin-top: 16px;
}

.deposit-qr {
  max-width: 200px;
  margin: 16px 0;
}

.deposit-status {
  margin-top: 16px;
  padding: 12px;
  background: #f7fafc;
  border-radius: 8px;
}

.deposit-status a {
  color: #4a90e2;
  text-decoration: none;
}

.deposit-status a:hover {
  text-decoration: underline;
}





BLOCKCYPHER_TOKEN=1e24b629077244a8904360e640527d7c

require("dotenv").config();
ngrok config add-authtoken 2w6FqW4UPaDxLwCSYDJGvJKqgfc_3e253gQUMknzP56a4kqbp
