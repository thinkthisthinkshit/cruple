Message.js:
const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  content: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  chatId: { type: String, required: true }, // Уникальный идентификатор чата (например, "senderId_recipientId")
});

module.exports = mongoose.model("Message", messageSchema);

server.js:
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
const Message = require("./models/Message"); // Новая модель

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

    // Группировка сообщений по chatId
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

    // Проверка, что пользователь участвует в чате
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

Messages.js:
import React, { useContext, useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { AuthContext } from "../App";
import { Helmet, HelmetProvider } from "react-helmet-async";
import axios from "axios";
import { FiMessageSquare } from "react-icons/fi";

function Messages() {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [chats, setChats] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchChats = async () => {
      try {
        const response = await axios.get("http://localhost:3000/messages", {
          headers: { Authorization: `Bearer ${user.token}` },
        });
        setChats(response.data);
      } catch (err) {
        console.error("Fetch chats error:", err);
      } finally {
        setLoading(false);
      }
    };
    if (user) fetchChats();
  }, [user]);

  if (!user) {
    navigate("/login");
    return null;
  }

  return (
    <HelmetProvider>
      <div className="messages-container">
        <Helmet>
          <title>Сообщения - CryptoAuthors</title>
          <meta
            name="description"
            content="Общайтесь с авторами и другими пользователями на CryptoAuthors."
          />
        </Helmet>
        <h1>Сообщения</h1>
        <div className="chat-list">
          {loading ? (
            <p>Загрузка...</p>
          ) : chats.length ? (
            <ul>
              {chats.map((chat) => (
                <li
                  key={chat.chatId}
                  className="chat-item"
                  onClick={() => navigate(`/messages/${chat.chatId}`)}
                >
                  <div className="chat-avatar">
                    <FiMessageSquare />
                  </div>
                  <div className="chat-info">
                    <span className="chat-with">
                      {chat.with.authorNickname || chat.with.username}
                    </span>
                    <p className="chat-last-message">{chat.lastMessage}</p>
                    <small>{new Date(chat.timestamp).toLocaleString()}</small>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <p>Нет чатов</p>
          )}
        </div>
      </div>
    </HelmetProvider>
  );
}

export default Messages;

Chat.js:
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

    if (user) {
      fetchMessages();
      socket.emit("joinChat", chatId);
      socket.on("newMessage", (message) => {
        setMessages((prev) => [...prev, message]);
      });
      socket.on("error", ({ message }) => {
        toast.error(message);
      });
    } else {
      navigate("/login");
    }

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

AuthorProfile.js:
import React, { useState, useEffect, useContext } from "react";
import { useParams, useNavigate } from "react-router-dom";
import axios from "axios";
import { AuthContext } from "../App";
import { Helmet, HelmetProvider } from "react-helmet-async";
import Post from "./Post";
import Media from "./Media";
import SubscribeButton from "./SubscribeButton";
import { FiEdit, FiShare2, FiMessageSquare } from "react-icons/fi";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

function AuthorProfile() {
  const { username } = useParams();
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [author, setAuthor] = useState(null);
  const [posts, setPosts] = useState([]);
  const [media, setMedia] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("posts");

  useEffect(() => {
    async function fetchAuthorData() {
      try {
        const [authorRes, postsRes] = await Promise.all([
          axios.get(`http://localhost:3000/author/${username}`),
          axios.get(`http://localhost:3000/author/${username}/posts`),
        ]);
        setAuthor(authorRes.data);
        const allPosts = postsRes.data;
        setPosts(allPosts.filter((post) => post.type === "text"));
        setMedia(allPosts.filter((post) => post.type === "media"));
      } catch (err) {
        console.error("Fetch author data error:", err);
        toast.error("Не удалось загрузить данные автора");
      } finally {
        setIsLoading(false);
      }
    }
    fetchAuthorData();
  }, [username]);

  const handleStartChat = async () => {
    if (!user) {
      toast.error("Войдите, чтобы начать чат");
      return;
    }
    try {
      const response = await axios.post(
        "http://localhost:3000/messages/start",
        { recipientUsername: username },
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
      navigate(`/messages/${response.data.chatId}`);
    } catch (err) {
      console.error("Start chat error:", err);
      toast.error(err.response?.data?.error || "Не удалось начать чат");
    }
  };

  if (isLoading) {
    return <div className="spinner-container"><div className="spinner"></div></div>;
  }

  if (!author) {
    return <p>Автор не найден</p>;
  }

  const isOwnProfile = user && user.username === username;

  return (
    <HelmetProvider>
      <div className="author-profile-container">
        <Helmet>
          <title>{author.authorNickname || username} - CryptoAuthors</title>
          <meta
            name="description"
            content={`Профиль ${author.authorNickname || username} на CryptoAuthors.`}
          />
        </Helmet>
        <div className="author-profile-header">
          <div className="author-cover">
            <img
              src={author.coverPhoto || "https://via.placeholder.com/1200x200"}
              alt="Cover"
              className="cover-photo"
            />
            <div className="cover-overlay">
              <h1 className="cover-nickname">{author.authorNickname || username}</h1>
              <p className="cover-subscribers">Подписчиков: {author.subscribers?.length || 0}</p>
            </div>
          </div>
          <div className="author-avatar-section">
            <div className="author-avatar">
              <img
                src={author.avatarUrl || "https://via.placeholder.com/120"}
                alt="Avatar"
              />
            </div>
            <div className="author-actions">
              {isOwnProfile ? (
                <button
                  className="edit-profile-button"
                  onClick={() => navigate("/settings")}
                >
                  <FiEdit /> Редактировать профиль
                </button>
              ) : (
                <>
                  <SubscribeButton
                    authorUsername={username}
                    subscriptionPrice={author.subscriptionPrice || 5}
                  />
                  <button className="message-button" onClick={handleStartChat}>
                    <FiMessageSquare /> Написать
                  </button>
                </>
              )}
              <button
                className="share-profile-button"
                onClick={() => {
                  navigator.clipboard.writeText(window.location.href);
                  toast.success("Ссылка скопирована!");
                }}
              >
                <FiShare2 /> Поделиться
              </button>
            </div>
          </div>
        </div>
        <div className="author-about-section">
          <h3>О себе</h3>
          <p>{author.about || "Информация отсутствует"}</p>
          {author.socialLinks?.length > 0 && (
            <div className="social-links">
              <h4>Социальные сети</h4>
              <ul>
                {author.socialLinks.map((link, index) => (
                  <li key={index}>
                    <a href={link} target="_blank" rel="noopener noreferrer">
                      {link}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
        <div className="content-tabs">
          <button
            className={`tab-button ${activeTab === "posts" ? "active" : ""}`}
            onClick={() => setActiveTab("posts")}
          >
            Посты
          </button>
          <button
            className={`tab-button ${activeTab === "media" ? "active" : ""}`}
            onClick={() => setActiveTab("media")}
          >
            Медиа
          </button>
        </div>
        {activeTab === "posts" ? (
          posts.length ? (
            <div className="post-list">
              {posts.map((post) => (
                <Post key={post._id} post={post} />
              ))}
            </div>
          ) : (
            <p>Посты отсутствуют</p>
          )
        ) : media.length ? (
          <div className="media-list">
            {media.map((post) => (
              <Media key={post._id} post={post} />
            ))}
          </div>
        ) : (
          <p>Медиа отсутствуют</p>
        )}
        <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      </div>
    </HelmetProvider>
  );
}

export default AuthorProfile;

User.js BACK:
const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, default: "viewer" },
  authorNickname: { type: String },
  subscribers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  about: { type: String, default: "" },
  socialLinks: [{ type: String }],
  avatarUrl: { type: String, default: "" },
  coverPhoto: { type: String, default: "" },
});

module.exports = mongoose.model("User", userSchema);




