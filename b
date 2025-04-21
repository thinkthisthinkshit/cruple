const express = require("express");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const cors = require("cors");
const path = require("path");
const QRCode = require("qrcode");
const http = require("http");
const socketIo = require("socket.io");
const multer = require("multer");
const User = require("./models/User");
const Post = require("./models/Post");
const Message = require("./models/Message");

const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

mongoose.connect("mongodb://localhost:27017/cryptoauthors", {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/"),
  filename: (req, file, cb) => cb(null, Date.now() + path.extname(file.originalname)),
});
const upload = multer({ storage });

const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "No token provided" });
  try {
    const decoded = jwt.verify(token, "secret");
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: "Invalid token" });
  }
};

// Регистрация
app.post("/register", async (req, res) => {
  try {
    const { username, password } = req.body;
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, password: hashedPassword, role: "viewer" });
    await user.save();
    res.status(201).json({ message: "User registered" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Логин
app.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;
    const user = await User.findOne({ username });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: "Invalid credentials" });
    }
    const token = jwt.sign(
      { username: user.username, role: user.role, authorNickname: user.authorNickname, id: user._id },
      "secret",
      { expiresIn: "1h" }
    );
    res.json({ token, role: user.role, authorNickname: user.authorNickname || "" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Стать автором
app.post("/become-author", authMiddleware, async (req, res) => {
  try {
    const { authorNickname } = req.body;
    const user = await User.findOne({ _id: req.user.id });
    if (!user) return res.status(404).json({ error: "User not found" });
    user.role = "author";
    user.authorNickname = authorNickname;
    await user.save();
    const token = jwt.sign(
      { username: user.username, role: user.role, authorNickname: user.authorNickname, id: user._id },
      "secret",
      { expiresIn: "1h" }
    );
    res.json({ username: user.username, role: user.role, authorNickname, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

// Получение топ-10 пользователей
app.get("/users", async (req, res) => {
  try {
    const users = await User.find({ role: "author" })
      .sort({ subscribers: -1 })
      .limit(10);
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Генерация QR-кода
app.get("/generate/:username/qr", authMiddleware, async (req, res) => {
  try {
    const { username } = req.params;
    if (req.user.username !== username) {
      return res.status(403).json({ error: "Unauthorized" });
    }
    const address = `bitcoin:${username}_address`; // Замените на реальный адрес
    const qr = await QRCode.toDataURL(address);
    res.json({ qr });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Получение баланса
app.get("/balance", authMiddleware, async (req, res) => {
  res.json({ balance: 0 }); // Заглушка
});

// Профиль автора
app.get("/author/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ error: "User not found" });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Посты автора
app.get("/author/:username/posts", async (req, res) => {
  try {
    const posts = await Post.find({ username: req.params.username }).sort({ createdAt: -1 });
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Подписка
app.post("/subscribe/:username", authMiddleware, async (req, res) => {
  try {
    const user = await User.findOne({ _id: req.user.id });
    const author = await User.findOne({ username: req.params.username });
    if (!author) return res.status(404).json({ error: "Author not found" });
    if (user.subscribers.includes(author._id)) {
      return res.status(400).json({ error: "Already subscribed" });
    }
    user.subscribers.push(author._id);
    author.subscribers = author.subscribers || [];
    author.subscribers.push(user._id);
    await Promise.all([user.save(), author.save()]);
    res.json({ message: "Subscribed" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Отписка
app.post("/unsubscribe/:username", authMiddleware, async (req, res) => {
  try {
    const user = await User.findOne({ _id: req.user.id });
    const author = await User.findOne({ username: req.params.username });
    if (!author) return res.status(404).json({ error: "Author not found" });
    user.subscribers = user.subscribers.filter(
      (id) => id.toString() !== author._id.toString()
    );
    author.subscribers = author.subscribers.filter(
      (id) => id.toString() !== user._id.toString()
    );
    await Promise.all([user.save(), author.save()]);
    res.json({ message: "Unsubscribed" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Создание поста
app.post("/posts", authMiddleware, upload.single("media"), async (req, res) => {
  try {
    const { text, type } = req.body;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const post = new Post({
      username: req.user.username,
      text,
      type,
      mediaUrl,
      authorNickname: req.user.authorNickname,
    });
    await post.save();
    io.emit("newPost", post);
    res.status(201).json(post);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Получение всех постов
app.get("/posts", async (req, res) => {
  try {
    const posts = await Post.find().sort({ createdAt: -1 });
    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Получение поста по ID
app.get("/posts/:id", async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ error: "Post not found" });
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Лайк поста
app.post("/posts/:id/like", authMiddleware, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ error: "Post not found" });
    const userId = req.user.id;
    const index = post.likes.indexOf(userId);
    if (index === -1) {
      post.likes.push(userId);
    } else {
      post.likes.splice(index, 1);
    }
    await post.save();
    io.emit("likeUpdate", { postId: req.params.id, likes: post.likes });
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Комментарии к посту
app.post("/posts/:id/comments", authMiddleware, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ error: "Post not found" });
    const comment = {
      username: req.user.username,
      text: req.body.text,
      createdAt: new Date(),
    };
    post.comments.push(comment);
    await post.save();
    io.emit("newComment", { postId: req.params.id, comment });
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Получение списка чатов пользователя
app.get("/messages", authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const messages = await Message.find({
      $or: [{ sender: userId }, { recipient: userId }],
    })
      .populate("sender", "username authorNickname")
      .populate("recipient", "username authorNickname")
      .sort({ timestamp: -1 });

    const chats = {};
    messages.forEach((msg) => {
      if (!chats[msg.chatId]) {
        chats[msg.chatId] = {
          chatId: msg.chatId,
          with: msg.sender._id.toString() === userId ? msg.recipient : msg.sender,
          lastMessage: msg.content,
          timestamp: msg.timestamp,
        };
      }
    });

    res.json(Object.values(chats));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Получение сообщений в чате
app.get("/messages/:chatId", authMiddleware, async (req, res) => {
  try {
    const { chatId } = req.params;
    const userId = req.user.id;
    const messages = await Message.find({ chatId })
      .populate("sender", "username authorNickname")
      .populate("recipient", "username authorNickname")
      .sort({ timestamp: 1 });

    const isParticipant = messages.some(
      (msg) =>
        msg.sender._id.toString() === userId || msg.recipient._id.toString() === userId
    );
    if (!isParticipant) {
      return res.status(403).json({ error: "Unauthorized" });
    }

    res.json(messages);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Начало нового чата
app.post("/messages/start", authMiddleware, async (req, res) => {
  try {
    const { recipientUsername } = req.body;
    const senderId = req.user.id;
    const recipient = await User.findOne({ username: recipientUsername, role: "author" });
    if (!recipient) {
      return res.status(404).json({ error: "Recipient not found or not an author" });
    }
    const chatId = [senderId, recipient._id].sort().join("_");
    const existingChat = await Message.findOne({ chatId });
    if (existingChat) {
      return res.json({ chatId });
    }
    res.json({ chatId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Socket.IO для сообщений
io.on("connection", (socket) => {
  socket.on("joinChat", (chatId) => {
    socket.join(chatId);
  });

  socket.on("sendMessage", async ({ chatId, senderId, recipientId, content }) => {
    try {
      const sender = await User.findById(senderId);
      const recipient = await User.findById(recipientId);
      if (!sender || !recipient || recipient.role !== "author") {
        socket.emit("error", { message: "Invalid sender or recipient" });
        return;
      }
      const message = new Message({
        sender: senderId,
        recipient: recipientId,
        content,
        chatId,
      });
      await message.save();
      const populatedMessage = await Message.findById(message._id)
        .populate("sender", "username authorNickname")
        .populate("recipient", "username authorNickname");
      io.to(chatId).emit("newMessage", populatedMessage);
    } catch (err) {
      socket.emit("error", { message: err.message });
    }
  });
});

server.listen(3000, () => console.log("Server running on port 3000"));

import React, { useState, useEffect, useContext, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { AuthContext } from "../App";
import { Helmet, HelmetProvider } from "react-helmet-async";
import axios from "axios";
import io from "socket.io-client";
import { FiSend, FiArrowLeft } from "react-icons/fi";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

const socket = io("http://localhost:3000");

function Chat() {
  const { chatId } = useParams();
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState("");
  const [recipient, setRecipient] = useState(null);
  const messagesEndRef = useRef(null);

  useEffect(() => {
    if (!user) {
      navigate("/login");
      return;
    }

    const fetchMessages = async () => {
      try {
        const response = await axios.get(`http://localhost:3000/messages/${chatId}`, {
          headers: { Authorization: `Bearer ${user.token}` },
        });
        setMessages(response.data);
        const otherUser = response.data[0]?.sender._id.toString() === user.id
          ? response.data[0].recipient
          : response.data[0].sender;
        setRecipient(otherUser);
      } catch (err) {
        console.error("Fetch messages error:", err);
        toast.error("Не удалось загрузить сообщения");
      }
    };

    fetchMessages();
    socket.emit("joinChat", chatId);
    socket.on("newMessage", (message) => {
      setMessages((prev) => [...prev, message]);
    });
    socket.on("error", ({ message }) => {
      toast.error(message);
    });

    return () => {
      socket.off("newMessage");
      socket.off("error");
    };
  }, [chatId, user, navigate]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim()) return;

    try {
      const recipientId = recipient?._id;
      if (!recipientId) {
        toast.error("Получатель не найден");
        return;
      }
      socket.emit("sendMessage", {
        chatId,
        senderId: user.id,
        recipientId,
        content: newMessage,
      });
      setNewMessage("");
    } catch (err) {
      console.error("Send message error:", err);
      toast.error("Не удалось отправить сообщение");
    }
  };

  if (!user) return null;

  return (
    <HelmetProvider>
      <div className="chat-container">
        <Helmet>
          <title>Чат - CryptoAuthors</title>
          <meta
            name="description"
            content="Общайтесь с авторами на CryptoAuthors."
          />
        </Helmet>
        <div className="chat-header">
          <button className="back-button" onClick={() => navigate("/messages")}>
            <FiArrowLeft />
          </button>
          <h1>{recipient?.authorNickname || recipient?.username}</h1>
        </div>
        <div className="messages-list">
          {messages.map((msg) => (
            <div
              key={msg._id}
              className={`message ${msg.sender._id.toString() === user.id ? "sent" : "received"}`}
            >
              <p>{msg.content}</p>
              <small>{new Date(msg.timestamp).toLocaleTimeString()}</small>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>
        <form className="message-form" onSubmit={handleSendMessage}>
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Введите сообщение..."
          />
          <button type="submit" disabled={!newMessage.trim()}>
            <FiSend />
          </button>
        </form>
        <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      </div>
    </HelmetProvider>
  );
}

export default Chat;
