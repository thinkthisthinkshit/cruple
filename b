import React, { useState, useEffect, useContext } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import axios from "axios";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { AuthContext } from "../App";
import Chat from "./Chat";

function Messages() {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const location = useLocation();
  const [chats, setChats] = useState([]);
  const [selectedChatId, setSelectedChatId] = useState(null);
  const [tempChat, setTempChat] = useState(null);

  const fetchChats = async () => {
    try {
      const response = await axios.get("http://localhost:3000/messages", {
        headers: { Authorization: `Bearer ${user.token}` },
      });
      console.log("Chats fetched:", response.data);
      setChats(response.data);
    } catch (err) {
      console.error("Fetch chats error:", err);
      toast.error(err.response?.data?.error || "Ошибка загрузки чатов");
    }
  };

  const generateChatId = (user1, user2) => {
    return [user1, user2].sort().join("_");
  };

  useEffect(() => {
    if (!user) {
      toast.error("Войдите, чтобы просматривать чаты");
      navigate("/login");
      return;
    }
    fetchChats();

    const params = new URLSearchParams(location.search);
    const startChatWith = params.get("startChatWith");
    if (startChatWith) {
      console.log("Processing startChatWith:", startChatWith);
      if (startChatWith === user.username) {
        console.error("Cannot start chat with self:", startChatWith);
        toast.error("Нельзя начать чат с собой");
        navigate("/messages");
        return;
      }
      if (!startChatWith || typeof startChatWith !== "string" || startChatWith.trim() === "") {
        console.error("Invalid startChatWith:", startChatWith);
        toast.error("Ошибка: имя пользователя некорректно");
        navigate("/messages");
        return;
      }
      const chatId = generateChatId(user.username, startChatWith);
      console.log("Generated chatId:", chatId, "for user:", startChatWith);
      // Проверяем, существует ли чат
      const existingChat = chats.find((chat) => chat.id === chatId);
      if (existingChat) {
        console.log("Existing chat found:", existingChat);
        setSelectedChatId(chatId);
        setTempChat(null);
        navigate("/messages");
      } else {
        console.log("Creating temporary chat with:", startChatWith);
        setTempChat({
          id: chatId,
          with: startChatWith,
          lastMessage: null,
          timestamp: new Date(),
        });
        setSelectedChatId(chatId);
      }
    }
  }, [user, location, navigate, chats]);

  const handleSelectChat = (chatId) => {
    setSelectedChatId(chatId);
    setTempChat(null);
    navigate("/messages");
  };

  return (
    <div className="messages-container">
      <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      <div className="messages-sidebar">
        <h2>Чаты</h2>
        <ul className="chat-list">
          {tempChat && (
            <li
              className={`chat-item ${selectedChatId === tempChat.id ? "active" : ""}`}
              onClick={() => handleSelectChat(tempChat.id)}
            >
              <div className="chat-info">
                <span className="chat-with">{tempChat.with}</span>
                <span className="chat-preview">Новый чат</span>
              </div>
            </li>
          )}
          {chats.map((chat) => (
            <li
              key={chat.id}
              className={`chat-item ${selectedChatId === chat.id ? "active" : ""}`}
              onClick={() => handleSelectChat(chat.id)}
            >
              <div className="chat-info">
                <span className="chat-with">{chat.with}</span>
                <span className="chat-preview">{chat.lastMessage || "Нет сообщений"}</span>
              </div>
            </li>
          ))}
        </ul>
      </div>
      {selectedChatId && (
        <div className="chat-container">
          <Chat
            chatId={selectedChatId}
            recipient={tempChat ? tempChat.with : chats.find((c) => c.id === selectedChatId)?.with}
            onMessageSent={() => fetchChats()}
          />
        </div>
      )}
    </div>
  );
}

export default Messages;




server.js:
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

const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: "*" } });

// Настройка Multer для сохранения файлов
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
  .then(() => console.log("Connected to MongoDB"));

// Middleware для проверки токена
const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  console.log("authMiddleware - Token:", token ? token.substring(0, 10) + "..." : "undefined");
  if (!token) return res.status(401).json({ error: "Требуется авторизация" });
  try {
    const decoded = jwt.verify(token, "secret");
    console.log("authMiddleware - Decoded user:", decoded);
    req.user = decoded;
    next();
  } catch (err) {
    console.error("authMiddleware - Token verification error:", err);
    res.status(401).json({ error: "Недействительный токен" });
  }
};

// Middleware для админов
const adminMiddleware = (req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ error: "Доступ только для админов" });
  }
  next();
};

// Функция для создания уникального chatId
const generateChatId = (user1, user2) => {
  return [user1, user2].sort().join("_");
};

// Socket.IO события
io.on("connection", (socket) => {
  console.log("Client connected:", socket.id);
  socket.on("joinPost", (postId) => {
    socket.join(postId);
  });
  socket.on("joinChat", (chatId) => {
    socket.join(chatId);
  });
  socket.on("disconnect", () => {
    console.log("Client disconnected:", socket.id);
  });
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

    res.json(
      messages.map((chat) => ({
        id: chat._id,
        with: chat.with,
        lastMessage: chat.lastMessage,
        timestamp: chat.timestamp,
      }))
    );
  } catch (err) {
    console.error("Fetch messages error:", err);
    res.status(500).json({ error: "Ошибка получения чатов" });
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
    console.error("Fetch chat messages error:", err);
    res.status(500).json({ error: "Ошибка получения сообщений" });
  }
});

app.post("/messages/:chatId", authMiddleware, async (req, res) => {
  const { text } = req.body;
  console.log("POST /messages/:chatId called, chatId:", req.params.chatId, "Body:", req.body);
  if (!text) {
    console.log("POST /messages/:chatId - Error: Text is missing");
    return res.status(400).json({ error: "Текст сообщения обязателен" });
  }
  try {
    const [user1, user2] = req.params.chatId.split("_");
    if (![user1, user2].includes(req.user.username)) {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    const recipient = user1 === req.user.username ? user2 : user1;
    const recipientUser = await User.findOne({ username: recipient });
    if (!recipientUser) {
      console.log("POST /messages/:chatId - Error: Recipient not found:", recipient);
      return res.status(404).json({ error: "Получатель не найден" });
    }
    const message = new Message({
      chatId: req.params.chatId,
      from: req.user.username,
      to: recipient,
      text,
    });
    console.log("Saving message:", message);
    await message.save();
    console.log("Message saved:", message);
    io.to(req.params.chatId).emit("newMessage", message);
    res.json(message);
  } catch (err) {
    console.error("Send message error:", err.message, err.stack);
    res.status(500).json({ error: "Ошибка отправки сообщения", details: err.message });
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
    console.error("Fetch unread messages error:", err);
    res.status(500).json({ error: "Ошибка получения непрочитанных сообщений" });
  }
});

app.post("/messages/:chatId/read", authMiddleware, async (req, res) => {
  try {
    const [user1, user2] = req.params.chatId.split("_");
    if (![user1, user2].includes(req.user.username)) {
      return res.status(403).json({ error: "Недостаточно прав" });
    }
    await Message.updateMany(
      { chatId: req.params.chatId, to: req.user.username, read: false },
      { read: true }
    );
    res.json({ success: true });
  } catch (err) {
    console.error("Mark messages read error:", err);
    res.status(500).json({ error: "Ошибка отметки сообщений" });
  }
});

app.post("/messages/start", authMiddleware, async (req, res) => {
  const { username } = req.body;
  console.log("POST /messages/start - Request body:", req.body, "User:", req.user);
  if (!username) {
    console.log("POST /messages/start - Error: Username is missing");
    return res.status(400).json({ error: "Username обязателен" });
  }
  if (typeof username !== "string" || username.trim() === "") {
    console.log("POST /messages/start - Error: Username is invalid:", username);
    return res.status(400).json({ error: "Username должен быть строкой" });
  }
  try {
    const targetUser = await User.findOne({ username });
    if (!targetUser) {
      console.log("POST /messages/start - Error: User not found:", username);
      return res.status(404).json({ error: "Пользователь не найден" });
    }
    if (req.user.username === username) {
      console.log("POST /messages/start - Error: Cannot start chat with self");
      return res.status(400).json({ error: "Нельзя начать чат с собой" });
    }
    const chatId = generateChatId(req.user.username, username);
    console.log("Chat initiated - chatId:", chatId);
    res.json({ chatId });
  } catch (err) {
    console.error("Start chat error:", err);
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
    console.error("Upload media error:", err);
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
    console.error("Check subscription error:", err);
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
    console.error("Register error:", err);
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
    console.error("Login error:", err);
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
    console.error("Become author error:", err);
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
    console.error("Set subscription price error:", err);
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
      author.subscribers = author.subscribers.filter(id => id.toString() !== req.user.id);
    } else {
      author.subscribers.push(req.user.id);
    }
    await author.save();
    io.emit("subscriptionUpdate", { authorId: author._id, subscribers: author.subscribers.length });
    res.json({ subscribed: !isSubscribed, subscriptionPrice: author.subscriptionPrice });
  } catch (err) {
    console.error("Subscribe error:", err);
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
    console.error("Fetch user error:", err);
    res.status(500).json({ error: "Ошибка сервера" });
  }
});

// Получить топ-10 авторов
app.get("/users", async (req, res) => {
  try {
    const users = await User.find({ role: "author" }, "username authorNickname role subscriptionPrice")
      .sort({ balance: -1 })
      .limit(10);
    res.json(users);
  } catch (err) {
    console.error("Fetch users error:", err);
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
    console.error("Fetch favorites error:", err);
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
    console.error("Toggle favorite error:", err);
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
    console.error("Search authors error:", err);
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
    const post = new Post({ username: req.user.username, text, type: type || "text", mediaUrl });
    await post.save();
    io.emit("newPost", post);
    res.json(post);
  } catch (err) {
    console.error("Post error:", err);
    res.status(500).json({ error: "Ошибка публикации" });
  }
});

// Получение постов пользователя
app.get("/posts/:username", async (req, res) => {
  try {
    const posts = await Post.find({ username: req.params.username }).sort({ timestamp: -1 });
    res.json(posts);
  } catch (err) {
    console.error("Fetch posts error:", err);
    res.status(500).json({ error: "Ошибка получения постов" });
  }
});

// Получение всех постов
app.get("/posts", async (req, res) => {
  try {
    const posts = await Post.find().sort({ timestamp: -1 });
    res.json(posts);
  } catch (err) {
    console.error("Fetch all posts error:", err);
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
    console.error("Delete post error:", err);
    res.status(500).json({ error: "Ошибка удаления" });
  }
});

// Лайк/анлайк поста
app.post("/posts/:id/like", authMiddleware, async (req, res) => {
  try {
    const post = await Post.findOne({ _id: req.params.id });
    if (!post) {
      return res.status(404).json({ error: "Пост не найден" });
    }
    const isLiked = post.likes.includes(req.user.id);
    if (isLiked) {
      post.likes = post.likes.filter(id => id.toString() !== req.user.id);
    } else {
      post.likes.push(req.user.id);
    }
    await post.save();
    io.to(post._id.toString()).emit("likeUpdate", { postId: post._id, likes: post.likes });
    res.json({ likes: post.likes });
  } catch (err) {
    console.error("Like post error:", err);
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
    const post = await Post.findOne({ _id: req.params.id });
    if (!post) {
      return res.status(404).json({ error: "Пост не найден" });
    }
    post.comments.push({ userId: req.user.id, text });
    await post.save();
    io.to(post._id.toString()).emit("commentUpdate", {
      postId: post._id,
      comments: post.comments,
    });
    res.json(post.comments);
  } catch (err) {
    console.error("Comment post error:", err);
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
    console.error("Donate error:", err);
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
    console.error("Balance error:", err);
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
    console.error("Generate QR error:", err);
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
      { username: user.username, role: user.role, authorNickname: user.authorNickname, id: user._id },
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
    console.error("Update profile error:", err);
    res.status(500).json({ error: "Ошибка обновления профиля" });
  }
});

// Админ: Получить всех пользователей
app.get("/admin/users", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const users = await User.find();
    res.json(users);
  } catch (err) {
    console.error("Fetch users error:", err);
    res.status(500).json({ error: "Ошибка получения пользователей" });
  }
});

// Админ: Получить все посты
app.get("/admin/posts", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const posts = await Post.find();
    res.json(posts);
  } catch (err) {
    console.error("Fetch posts error:", err);
    res.status(500).json({ error: "Ошибка получения постов" });
  }
});

// Админ: Удалить пользователя
app.delete("/admin/users/:username", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    await User.deleteOne({ username: req.params.username });
    res.json({ success: true });
  } catch (err) {
    console.error("Delete user error:", err);
    res.status(500).json({ error: "Ошибка удаления пользователя" });
  }
});

// Админ: Удалить пост
app.delete("/admin/posts/:id", authMiddleware, adminMiddleware, async (req, res) => {
  try {
    await Post.deleteOne({ _id: req.params.id });
    res.json({ success: true });
  } catch (err) {
    console.error("Delete post error:", err);
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








