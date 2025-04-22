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
    const address = user.address || `bitcoin:${req.params.username}_address`;
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







App.js:
import React, { createContext, useState, useEffect } from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import axios from "axios";
import Navbar from "./components/Navbar";
import Home from "./components/Home";
import AuthorProfile from "./components/AuthorProfile";
import Content from "./components/Content";
import Deposit from "./components/Deposit";
import Settings from "./components/Settings";
import Login from "./components/Login";
import Messages from "./components/Messages";
import Chat from "./components/Chat";
import Search from "./components/Search";
import Notifications from "./components/Notifications";
import Feed from "./components/Feed";
import PostPage from "./components/PostPage";
import Favorites from "./components/Favorites";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./App.css";

export const AuthContext = createContext();

function App() {
  const [user, setUser] = useState(null);
  const [unreadMessagesCount, setUnreadMessagesCount] = useState(0);
  const [unreadNotificationsCount, setUnreadNotificationsCount] = useState(0);

  useEffect(() => {
    const storedUser = localStorage.getItem("user");
    if (storedUser) {
      try {
        const parsedUser = JSON.parse(storedUser);
        if (parsedUser && parsedUser.token) {
          setUser(parsedUser);
        } else {
          localStorage.removeItem("user");
        }
      } catch (err) {
        console.error("Error parsing stored user:", err);
        localStorage.removeItem("user");
      }
    }
  }, []);

  useEffect(() => {
    const interceptor = axios.interceptors.request.use((config) => {
      if (user?.token) {
        config.headers.Authorization = `Bearer ${user.token}`;
      }
      return config;
    });
    return () => {
      axios.interceptors.request.eject(interceptor);
    };
  }, [user]);

  useEffect(() => {
    if (user) {
      const fetchUnread = async () => {
        try {
          const messagesRes = await axios.get("http://localhost:3000/messages/unread");
          setUnreadMessagesCount(messagesRes.data.unreadMessagesCount);
          const notificationsRes = await axios.get("http://localhost:3000/notifications/unread");
          setUnreadNotificationsCount(notificationsRes.data.unreadCount);
        } catch (err) {
          console.error("Fetch unread error:", err);
        }
      };
      fetchUnread();
      const interval = setInterval(fetchUnread, 30000);
      return () => clearInterval(interval);
    } else {
      setUnreadMessagesCount(0);
      setUnreadNotificationsCount(0);
    }
  }, [user]);

  return (
    <AuthContext.Provider
      value={{ user, setUser, unreadMessagesCount, unreadNotificationsCount }}
    >
      <Router>
        <Navbar />
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/author/:username" element={<AuthorProfile />} />
          <Route path="/content" element={<Content />} />
          <Route path="/deposit" element={<Deposit />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/login" element={<Login />} />
          <Route path="/messages" element={<Messages />} />
          <Route path="/messages/:chatId" element={<Chat />} />
          <Route path="/search" element={<Search />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/feed" element={<Feed />} />
          <Route path="/post/:postId" element={<PostPage />} />
          <Route path="/favorites" element={<Favorites />} />
        </Routes>
        <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      </Router>
    </AuthContext.Provider>
  );
}

export default App;





Navbar.js:
import React, { useContext, useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";
import { AuthContext } from "../App";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import {
  FiHome,
  FiUser,
  FiEdit,
  FiLogIn,
  FiLogOut,
  FiFeather,
  FiSettings,
  FiDollarSign,
  FiSearch,
  FiMessageSquare,
  FiBell,
  FiMenu,
  FiStar,
} from "react-icons/fi";
import io from "socket.io-client";

const socket = io("http://localhost:3000");

function Navbar() {
  const { user, setUser, unreadMessagesCount, unreadNotificationsCount } = useContext(AuthContext);
  const navigate = useNavigate();
  const [showAuthorModal, setShowAuthorModal] = useState(false);
  const [authorNickname, setAuthorNickname] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const [showSidebar, setShowSidebar] = useState(false);
  const dropdownRef = useRef(null);
  const touchStartX = useRef(null);

  useEffect(() => {
    if (user && user.username) {
      socket.emit("joinChat", user.username);
      socket.emit("joinNotifications", user.id);
    }
  }, [user]);

  useEffect(() => {
    socket.on("newMessage", (message) => {
      if (user && message.to === user.username) {
        toast.info(`Новое сообщение от ${message.from}`);
      }
    });

    socket.on("newNotification", (notification) => {
      if (user && notification.userId === user.id) {
        toast.info(`Новое уведомление от ${notification.fromUsername}`);
      }
    });

    return () => {
      socket.off("newMessage");
      socket.off("newNotification");
    };
  }, [user]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setShowDropdown(false);
        setShowSidebar(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  useEffect(() => {
    const handleTouchStart = (e) => {
      touchStartX.current = e.touches[0].clientX;
    };
    const handleTouchMove = (e) => {
      if (touchStartX.current === null) return;
      const touchEndX = e.touches[0].clientX;
      const diffX = touchEndX - touchStartX.current;
      if (diffX > 50 && window.innerWidth <= 768 && !showSidebar) {
        setShowSidebar(true);
        touchStartX.current = null;
      } else if (diffX < -50 && window.innerWidth <= 768 && showSidebar) {
        setShowSidebar(false);
        touchStartX.current = null;
      }
    };
    document.addEventListener("touchstart", handleTouchStart);
    document.addEventListener("touchmove", handleTouchMove);
    return () => {
      document.removeEventListener("touchstart", handleTouchStart);
      document.removeEventListener("touchmove", handleTouchMove);
    };
  }, [showSidebar]);

  const handleLogout = () => {
    setUser(null);
    localStorage.removeItem("user");
    setShowDropdown(false);
    setShowSidebar(false);
    navigate("/login");
  };

  const handleBecomeAuthor = async (e) => {
    e.preventDefault();
    if (!authorNickname) {
      toast.error("Введите никнейм");
      return;
    }
    try {
      const response = await axios.post("http://localhost:3000/become-author", {
        authorNickname,
      });
      const newUser = {
        username: response.data.username,
        token: response.data.token,
        role: response.data.role,
        authorNickname: response.data.authorNickname,
      };
      setUser(newUser);
      localStorage.setItem("user", JSON.stringify(newUser));
      toast.success("Вы стали автором!");
      setShowAuthorModal(false);
      setAuthorNickname("");
      navigate("/content");
    } catch (err) {
      toast.error(err.response?.data?.error || "Ошибка");
    }
  };

  const toggleDropdown = () => {
    setShowDropdown((prev) => !prev);
  };

  const toggleSidebar = () => {
    setShowSidebar((prev) => !prev);
    setShowDropdown(false);
  };

  return (
    <>
      <nav className="navbar">
        {user && (
          <>
            <button
              className="nav-home-button"
              onClick={() => navigate("/")}
              title="Главная"
            >
              <FiHome />
            </button>
            <button className="nav-menu-button" onClick={toggleSidebar} title="Меню">
              <FiMenu />
            </button>
          </>
        )}
        <div
          className="nav-logo"
          onClick={window.innerWidth > 768 ? () => navigate("/") : undefined}
        >
          CryptoAuthors
        </div>
        {user && (
          <div className="nav-actions">
            <button
              className="nav-search-button"
              onClick={() => navigate("/search")}
              title="Поиск"
            >
              <FiSearch />
            </button>
            <button
              className="nav-notifications-button"
              onClick={() => navigate("/notifications")}
              title="Уведомления"
            >
              <FiBell />
              {unreadNotificationsCount > 0 && (
                <span className="badge">
                  {unreadNotificationsCount > 20 ? "20+" : unreadNotificationsCount}
                </span>
              )}
            </button>
            <button
              className="nav-messages-button"
              onClick={() => navigate("/messages")}
              title="Сообщения"
            >
              <FiMessageSquare />
              {unreadMessagesCount > 0 && (
                <span className="badge">
                  {unreadMessagesCount > 20 ? "20+" : unreadMessagesCount}
                </span>
              )}
            </button>
            <button
              className="nav-favorites-button"
              onClick={() => navigate("/favorites")}
              title="Избранное"
            >
              <FiStar />
            </button>
          </div>
        )}
        <div className="nav-header">
          {user && (
            <div
              className="user-info"
              onClick={() => {
                if (window.innerWidth > 768) {
                  toggleDropdown();
                } else {
                  navigate(`/author/${user.username}`);
                }
              }}
              ref={dropdownRef}
            >
              <FiUser />
              <span>{user.username}</span>
              {showDropdown && (
                <div className="dropdown-menu">
                  <button
                    className="dropdown-item"
                    onClick={() => {
                      navigate("/");
                      setShowDropdown(false);
                    }}
                  >
                    <FiHome /> Главная
                  </button>
                  <button
                    className="dropdown-item"
                    onClick={() => {
                      navigate(`/author/${user.username}`);
                      setShowDropdown(false);
                    }}
                  >
                    <FiUser /> Моя страница
                  </button>
                  <button
                    className="dropdown-item"
                    onClick={() => {
                      navigate("/settings");
                      setShowDropdown(false);
                    }}
                  >
                    <FiSettings /> Настройки
                  </button>
                  <button
                    className="dropdown-item"
                    onClick={() => {
                      navigate("/deposit");
                      setShowDropdown(false);
                    }}
                  >
                    <FiDollarSign /> Монетизация
                  </button>
                  {user.role === "viewer" && (
                    <button
                      className="dropdown-item"
                      onClick={() => {
                        setShowAuthorModal(true);
                        setShowDropdown(false);
                      }}
                    >
                      <FiFeather /> Стать создателем
                    </button>
                  )}
                  <button className="dropdown-item" onClick={handleLogout}>
                    <FiLogOut /> Выйти
                  </button>
                </div>
              )}
            </div>
          )}
          {!user && (
            <button className="login-button" onClick={() => navigate("/login")}>
              <FiLogIn /> Войти
            </button>
          )}
        </div>
      </nav>
      {user && (
        <div className="bottom-nav">
          <button
            className="bottom-nav-item"
            onClick={() => navigate("/")}
            title="Главная"
          >
            <FiHome />
          </button>
          <button
            className="bottom-nav-item"
            onClick={() => navigate("/search")}
            title="Поиск"
          >
            <FiSearch />
          </button>
          <button
            className="bottom-nav-item pulse"
            onClick={() => navigate("/messages")}
            title="Сообщения"
          >
            <FiMessageSquare />
            {unreadMessagesCount > 0 && (
              <span className="badge">
                {unreadMessagesCount > 20 ? "20+" : unreadMessagesCount}
              </span>
            )}
          </button>
          <button
            className="bottom-nav-item pulse"
            onClick={() => navigate("/notifications")}
            title="Уведомления"
          >
            <FiBell />
            {unreadNotificationsCount > 0 && (
              <span className="badge">
                {unreadNotificationsCount > 20 ? "20+" : unreadNotificationsCount}
              </span>
            )}
          </button>
        </div>
      )}
      <div className={`sidebar ${showSidebar ? "active" : ""}`}>
        <div className="sidebar-links">
          <button
            className="sidebar-button"
            onClick={() => {
              navigate("/");
              setShowSidebar(false);
            }}
          >
            <FiHome /> Главная
          </button>
          <button
            className="sidebar-button"
            onClick={() => {
              navigate(`/author/${user?.username}`);
              setShowSidebar(false);
            }}
          >
            <FiUser /> Профиль
          </button>
          {user?.role === "author" && (
            <button
              className="sidebar-button"
              onClick={() => {
                navigate("/content");
                setShowSidebar(false);
              }}
            >
              <FiEdit /> Контент
            </button>
          )}
          <button
            className="sidebar-button"
            onClick={() => {
              navigate("/favorites");
              setShowSidebar(false);
            }}
          >
            <FiStar /> Избранное
          </button>
          <button
            className="sidebar-button"
            onClick={() => {
              navigate("/deposit");
              setShowSidebar(false);
            }}
          >
            <FiDollarSign /> Монетизация
          </button>
          <button
            className="sidebar-button"
            onClick={() => {
              navigate("/settings");
              setShowSidebar(false);
            }}
          >
            <FiSettings /> Настройки
          </button>
          {user && (
            <button className="sidebar-button" onClick={handleLogout}>
              <FiLogOut /> Выйти
            </button>
          )}
        </div>
      </div>
      {showAuthorModal && (
        <div className="modal-overlay">
          <div className="modal">
            <h2>Стать автором</h2>
            <form onSubmit={handleBecomeAuthor}>
              <input
                type="text"
                value={authorNickname}
                onChange={(e) => setAuthorNickname(e.target.value)}
                placeholder="Введите никнейм автора"
                required
              />
              <div className="modal-buttons">
                <button type="submit" className="publish-button">
                  Подтвердить
                </button>
                <button
                  type="button"
                  className="close-button"
                  onClick={() => setShowAuthorModal(false)}
                >
                  Отмена
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
    </>
  );
}

export default Navbar;








Post.js:
import React, { useState, useEffect, useContext } from "react";
import { AuthContext } from "../App";
import LikeButton from "./LikeButton";
import SubscribeButton from "./SubscribeButton";
import { FiMessageSquare } from "react-icons/fi";
import { useNavigate } from "react-router-dom";
import axios from "axios";

function Post({ post }) {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [postData] = useState({
    ...post,
    likes: post.likes || [],
    comments: post.comments || [],
  });
  const [isSubscribed, setIsSubscribed] = useState(false);

  const isAuthor = user?.username === postData.username;

  useEffect(() => {
    async function checkSubscription() {
      if (!user || isAuthor) return;
      try {
        const response = await axios.get(
          `http://localhost:3000/check-subscription/${postData.username}`
        );
        setIsSubscribed(response.data.isSubscribed);
      } catch (error) {
        console.error("Ошибка проверки подписки:", error);
      }
    }
    checkSubscription();
  }, [user, postData.username, isAuthor]);

  const handlePostClick = () => {
    navigate(`/post/${postData._id}`);
  };

  return (
    <div className="post-item" onClick={handlePostClick}>
      {postData.mediaUrl && (
        <div className="post-media-container">
          {postData.mediaUrl.endsWith(".mp4") ? (
            <video
              src={postData.mediaUrl}
              controls={isSubscribed || isAuthor || !user}
              className={`post-media ${!isSubscribed && !isAuthor && user ? "blurred" : ""}`}
              loading="lazy"
            />
          ) : (
            <img
              src={postData.mediaUrl}
              alt="Post Media"
              className={`post-media ${!isSubscribed && !isAuthor && user ? "blurred" : ""}`}
              loading="lazy"
            />
          )}
          {!isSubscribed && !isAuthor && user && (
            <div className="blur-overlay">Подпишитесь, чтобы увидеть контент</div>
          )}
        </div>
      )}
      {postData.text && <p>{postData.text}</p>}
      <div className="post-actions">
        <LikeButton postId={postData._id} likes={postData.likes} />
        <button
          className="comment-button"
          onClick={(e) => {
            e.stopPropagation();
            navigate(`/post/${postData._id}`);
          }}
        >
          <FiMessageSquare /> {postData.comments.length}
        </button>
      </div>
      {!isAuthor && (
        <SubscribeButton
          authorUsername={postData.username}
          subscriptionPrice={postData.subscriptionPrice || 5}
        />
      )}
    </div>
  );
}

export default Post;





LikeButton.js:
import React, { useState, useEffect, useContext } from "react";
import { AuthContext } from "../App";
import axios from "axios";
import { FiHeart } from "react-icons/fi";
import { toast } from "react-toastify";

function LikeButton({ postId, likes }) {
  const { user } = useContext(AuthContext);
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(likes?.length || 0);

  useEffect(() => {
    if (user && likes) {
      setIsLiked(likes.includes(user.id));
      setLikeCount(likes.length);
    }
  }, [user, likes]);

  const handleLike = async (e) => {
    e.stopPropagation();
    if (!user) {
      toast.error("Войдите, чтобы поставить лайк");
      return;
    }
    try {
      const res = await axios.post(`http://localhost:3000/posts/${postId}/like`, {});
      setIsLiked(!isLiked);
      setLikeCount(res.data.likes.length);
    } catch (err) {
      toast.error(err.response?.data?.error || "Ошибка при установке лайка");
    }
  };

  return (
    <button
      className={`like-button ${isLiked ? "liked" : ""}`}
      onClick={handleLike}
      disabled={!user}
      title={user ? "Лайк" : "Войдите, чтобы поставить лайк"}
    >
      <FiHeart /> {likeCount}
    </button>
  );
}

export default LikeButton;









CommentForm.js:
import React, { useState, useContext } from "react";
import { AuthContext } from "../App";
import axios from "axios";
import { toast } from "react-toastify";

function CommentForm({ postId }) {
  const { user } = useContext(AuthContext);
  const [text, setText] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!user) {
      toast.error("Войдите, чтобы комментировать");
      return;
    }
    if (!text.trim()) {
      toast.error("Введите текст комментария");
      return;
    }
    try {
      const response = await axios.post(`http://localhost:3000/posts/${postId}/comment`, {
        text,
      });
      setText("");
      toast.success("Комментарий добавлен");
    } catch (error) {
      toast.error(error.response?.data?.error || "Ошибка добавления комментария");
    }
  };

  return (
    <form className="comment-form" onSubmit={handleSubmit}>
      <input
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Ваш комментарий..."
        className="comment-input"
      />
      <button type="submit" className="comment-button">
        Отправить
      </button>
    </form>
  );
}

export default CommentForm;








CommentList.js:
import React, { useEffect, useState } from "react";
import axios from "axios";

function CommentList({ comments }) {
  const [userMap, setUserMap] = useState({});

  useEffect(() => {
    async function fetchUsernames() {
      const userIds = comments.map((comment) => comment.userId);
      if (userIds.length === 0) return;
      try {
        const response = await axios.post("http://localhost:3000/users/usernames", {
          userIds,
        });
        setUserMap(response.data);
      } catch (error) {
        console.error("Ошибка загрузки имен пользователей:", error);
      }
    }
    fetchUsernames();
  }, [comments]);

  if (!comments || !Array.isArray(comments) || comments.length === 0) {
    return <p>Комментариев пока нет</p>;
  }

  return (
    <ul className="comment-list">
      {comments.map((comment) => (
        <li key={comment._id} className="comment-item">
          <p>
            <strong>{userMap[comment.userId] || "Загрузка..."}</strong>: {comment.text}
          </p>
          <span>{new Date(comment.createdAt).toLocaleString()}</span>
        </li>
      ))}
    </ul>
  );
}

export default CommentList;






SubscribeButton.js:
import React, { useState, useEffect, useContext } from "react";
import { AuthContext } from "../App";
import { FiDollarSign } from "react-icons/fi";
import axios from "axios";
import { toast } from "react-toastify";
import io from "socket.io-client";

const socket = io("http://localhost:3000");

function SubscribeButton({ authorUsername, subscriptionPrice }) {
  const { user } = useContext(AuthContext);
  const [subscribed, setSubscribed] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    async function checkSubscription() {
      if (!user) return;
      try {
        const response = await axios.get(
          `http://localhost:3000/check-subscription/${authorUsername}`
        );
        setSubscribed(response.data.isSubscribed);
      } catch (error) {
        console.error("Ошибка проверки подписки:", error);
      }
    }
    checkSubscription();

    socket.on("subscriptionUpdate", () => {
      checkSubscription();
    });

    return () => {
      socket.off("subscriptionUpdate");
    };
  }, [authorUsername, user]);

  if (!user) {
    return <span className="guest-message">Войдите, чтобы подписаться</span>;
  }

  const handleSubscribe = async () => {
    setIsLoading(true);
    try {
      const response = await axios.post(
        `http://localhost:3000/subscribe/${authorUsername}`,
        {}
      );
      setSubscribed(response.data.subscribed);
      toast.success(response.data.subscribed ? "Вы подписались!" : "Вы отписались");
    } catch (error) {
      toast.error(error.response?.data?.error || "Ошибка подписки");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <button
      className={`subscribe-button ${subscribed ? "subscribed" : ""}`}
      onClick={handleSubscribe}
      disabled={isLoading}
    >
      <FiDollarSign />
      {subscribed ? "Отписаться" : `Подписаться за $${subscriptionPrice}/мес`}
    </button>
  );
}

export default SubscribeButton;





PostPage.js:
import React, { useState, useEffect, useContext } from "react";
import { useParams, useNavigate } from "react-router-dom";
import axios from "axios";
import { AuthContext } from "../App";
import LikeButton from "./LikeButton";
import CommentForm from "./CommentForm";
import CommentList from "./CommentList";
import { FiArrowLeft } from "react-icons/fi";
import { Helmet, HelmetProvider } from "react-helmet-async";
import { ToastContainer, toast } from "react-toastify";
import io from "socket.io-client";

const socket = io("http://localhost:3000");

function PostPage() {
  const { postId } = useParams();
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [post, setPost] = useState(null);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [visibleComments, setVisibleComments] = useState(5);

  useEffect(() => {
    async function fetchPost() {
      try {
        const res = await axios.get(`http://localhost:3000/posts/${postId}`);
        setPost({ ...res.data, likes: res.data.likes || [], comments: res.data.comments || [] });
        if (user && user.username !== res.data.username) {
          const subRes = await axios.get(
            `http://localhost:3000/check-subscription/${res.data.username}`
          );
          setIsSubscribed(subRes.data.isSubscribed);
        } else {
          setIsSubscribed(true);
        }
      } catch (err) {
        toast.error("Не удалось загрузить пост");
      } finally {
        setIsLoading(false);
      }
    }
    fetchPost();

    socket.emit("joinPost", postId);
    socket.on("likeUpdate", ({ postId: updatedPostId, likes }) => {
      if (updatedPostId === postId) {
        setPost((prev) => ({ ...prev, likes }));
      }
    });
    socket.on("commentUpdate", ({ postId: updatedPostId, comments }) => {
      if (updatedPostId === postId) {
        setPost((prev) => ({ ...prev, comments }));
      }
    });

    return () => {
      socket.off("likeUpdate");
      socket.off("commentUpdate");
    };
  }, [postId, user]);

  const handleLoadMore = () => {
    setVisibleComments((prev) => prev + 5);
  };

  if (isLoading) {
    return <div className="spinner-container"><div className="spinner"></div></div>;
  }

  if (!post) {
    return <p>Пост не найден</p>;
  }

  return (
    <HelmetProvider>
      <div className="post-page-container">
        <Helmet>
          <title>Пост - CryptoAuthors</title>
          <meta name="description" content="Просмотрите пост и комментарии на CryptoAuthors." />
        </Helmet>
        <div className="post-page-header">
          <button className="back-button" onClick={() => navigate(-1)}>
            <FiArrowLeft /> Назад
          </button>
        </div>
        <div className="post-content">
          {post.type === "media" && post.mediaUrl && (
            <div className="post-media-container">
              {post.mediaUrl.endsWith(".mp4") ? (
                <video
                  src={post.mediaUrl}
                  controls={isSubscribed}
                  className={`post-media ${!isSubscribed ? "blurred" : ""}`}
                  loading="lazy"
                />
              ) : (
                <img
                  src={post.mediaUrl}
                  alt="Post Media"
                  className={`post-media ${!isSubscribed ? "blurred" : ""}`}
                  loading="lazy"
                />
              )}
              {!isSubscribed && (
                <div className="blur-overlay">Подпишитесь, чтобы увидеть контент</div>
              )}
            </div>
          )}
          {post.text && <p className="post-text">{post.text}</p>}
          <div className="post-actions">
            <LikeButton postId={post._id} likes={post.likes} />
            <span>Комментариев: {post.comments?.length || 0}</span>
          </div>
          <CommentForm postId={post._id} />
          <CommentList comments={post.comments.slice(0, visibleComments)} />
          {post.comments.length > visibleComments && (
            <button className="load-more-button" onClick={handleLoadMore}>
              Ещё
            </button>
          )}
        </div>
        <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      </div>
    </HelmetProvider>
  );
}

export default PostPage;







Notifications.js:
import React, { useState, useEffect, useContext } from "react";
import { useNavigate } from "react-router-dom";
import { AuthContext } from "../App";
import axios from "axios";
import { Helmet, HelmetProvider } from "react-helmet-async";
import { toast } from "react-toastify";
import io from "socket.io-client";

const socket = io("http://localhost:3000");

function Notifications() {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      navigate("/login");
      return;
    }

    async function fetchNotifications() {
      try {
        const res = await axios.get("http://localhost:3000/notifications");
        setNotifications(res.data);
      } catch (err) {
        toast.error("Не удалось загрузить уведомления");
      } finally {
        setIsLoading(false);
      }
    }
    fetchNotifications();

    socket.emit("joinNotifications", user.id);
    socket.on("newNotification", (notification) => {
      setNotifications((prev) => [notification, ...prev]);
    });
    socket.on("notificationsRead", () => {
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    });

    return () => {
      socket.off("newNotification");
      socket.off("notificationsRead");
    };
  }, [user, navigate]);

  const handleMarkAsRead = async () => {
    try {
      await axios.post("http://localhost:3000/notifications/read", {});
      toast.success("Уведомления отмечены как прочитанные");
    } catch (err) {
      toast.error("Ошибка при отметке уведомлений");
    }
  };

  const handleNotificationClick = (notification) => {
    if (notification.postId) {
      navigate(`/post/${notification.postId}`);
    }
  };

  if (isLoading) {
    return <div className="spinner-container"><div className="spinner"></div></div>;
  }

  return (
    <HelmetProvider>
      <div className="notifications-container">
        <Helmet>
          <title>Уведомления - CryptoAuthors</title>
          <meta name="description" content="Просмотрите ваши уведомления на CryptoAuthors." />
        </Helmet>
        <h1>Уведомления</h1>
        {notifications.length === 0 ? (
          <div className="notification-placeholder">
            <p>Уведомлений пока нет</p>
          </div>
        ) : (
          <>
            <button className="publish-button" onClick={handleMarkAsRead}>
              Отметить все как прочитанные
            </button>
            <ul className="notifications-list">
              {notifications.map((notification) => (
                <li
                  key={notification._id}
                  className={`notification-item ${notification.read ? "read" : "unread"}`}
                  onClick={() => handleNotificationClick(notification)}
                >
                  {notification.type === "like" && (
                    <p>
                      <strong>{notification.fromUsername}</strong> лайкнул ваш пост
                    </p>
                  )}
                  {notification.type === "comment" && (
                    <p>
                      <strong>{notification.fromUsername}</strong> прокомментировал ваш пост: "
                      {notification.text}"
                    </p>
                  )}
                  {notification.type === "subscription" && (
                    <p>
                      <strong>{notification.fromUsername}</strong> подписался на вас
                    </p>
                  )}
                  <small>{new Date(notification.timestamp).toLocaleString()}</small>
                </li>
              ))}
            </ul>
          </>
        )}
      </div>
    </HelmetProvider>
  );
}

export default Notifications;





App.css:
.post-media-container {
  position: relative;
  max-width: 100%;
  margin-bottom: 12px;
}

.post-media {
  width: 100%;
  max-height: 400px;
  object-fit: cover;
  border-radius: 8px;
}

.post-media.blurred {
  filter: blur(8px);
}

.blur-overlay {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background: rgba(0, 0, 0, 0.6);
  color: white;
  padding: 8px 16px;
  border-radius: 4px;
  font-size: 14px;
}

.comment-form {
  display: flex;
  margin-top: 12px;
}

.comment-input {
  flex: 1;
  padding: 8px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 14px;
}

.comment-button {
  padding: 8px 16px;
  margin-left: 8px;
  background: #4a90e2;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.comment-button:hover {
  background: #357abd;
}

.notifications-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
}

.notifications-list {
  list-style: none;
  padding: 0;
  margin-top: 16px;
}

.notification-item {
  background: #ffffff;
  padding: 12px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  margin-bottom: 12px;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.notification-item:hover {
  transform: scale(1.02);
}

.notification-item.unread {
  background: #f7fafc;
  border-left: 4px solid #4a90e2;
}

.notification-item p {
  margin: 0;
  font-size: 16px;
}

.notification-item small {
  font-size: 12px;
  color: #4a5568;
  margin-top: 4px;
  display: block;
}

.notification-placeholder {
  text-align: center;
  padding: 24px;
  color: #4a5568;
}



