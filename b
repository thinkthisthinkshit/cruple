import React, { useState, useEffect, useContext } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import axios from "axios";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { AuthContext } from "../App";
import Chat from "./Chat";
import { FiUser } from "react-icons/fi";
import "../App.css";

function Messages() {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const location = useLocation();
  const [chats, setChats] = useState([]);
  const [selectedChatId, setSelectedChatId] = useState(null);
  const [tempChat, setTempChat] = useState(null);

  const fetchChats = async () => {
    try {
      console.log("Fetching chats...");
      const response = await axios.get("http://localhost:3000/messages", {
        headers: { Authorization: `Bearer ${user.token}` },
      });
      console.log("Chats fetched:", response.data);
      setChats(response.data);
    } catch (err) {
      console.error("Fetch chats error:", err.message, err.response?.data);
      toast.error(err.response?.data?.error || "Ошибка загрузки чатов");
    }
  };

  const generateChatId = (user1, user2) => {
    return [user1, user2].sort().join("_");
  };

  // Загрузка чатов
  useEffect(() => {
    if (!user) {
      toast.error("Войдите, чтобы просматривать чаты");
      navigate("/login");
      return;
    }
    fetchChats();
  }, [user, navigate]);

  // Обработка startChatWith
  useEffect(() => {
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
          unreadCount: 0,
        });
        setSelectedChatId(chatId);
      }
    }
  }, [user, location, navigate, chats]);

  const handleSelectChat = async (chatId) => {
    setSelectedChatId(chatId);
    setTempChat(null);
    navigate("/messages");
    try {
      console.log("Marking messages as read for chatId:", chatId);
      await axios.post(
        `http://localhost:3000/messages/${chatId}/read`,
        {},
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
      console.log("Messages marked as read for chatId:", chatId);
      fetchChats(); // Обновляем список чатов после отметки
    } catch (err) {
      console.error("Mark messages read error:", err.message, err.response?.data);
      toast.error(err.response?.data?.error || "Ошибка отметки сообщений");
    }
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
              <div className="chat-avatar">
                <FiUser />
              </div>
              <div className="chat-info">
                <span className="chat-with">{tempChat.with}</span>
                <span className="chat-last-message">Новый чат</span>
                {tempChat.unreadCount > 0 && (
                  <span className="badge">{tempChat.unreadCount}</span>
                )}
              </div>
            </li>
          )}
          {chats.map((chat) => (
            <li
              key={chat.id}
              className={`chat-item ${selectedChatId === chat.id ? "active" : ""}`}
              onClick={() => handleSelectChat(chat.id)}
            >
              <div className="chat-avatar">
                <FiUser />
              </div>
              <div className="chat-info">
                <span className="chat-with">{chat.with}</span>
                <span className="chat-last-message">{chat.lastMessage || "Нет сообщений"}</span>
                {chat.unreadCount > 0 && (
                  <span className="badge">{chat.unreadCount}</span>
                )}
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

.badge {
  position: absolute;
  top: -8px;
  right: -8px;
  background: #ff4d4f;
  color: #ffffff;
  border-radius: 50%;
  font-size: 12px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
}


CSS:
/* Сообщения */
.messages-container {
  display: flex;
  height: calc(100vh - 60px); /* Учитываем высоту навбара */
  max-width: 1200px;
  margin: 0 auto;
  padding: 0;
  background: #ffffff;
}

.messages-sidebar {
  width: 300px;
  background: #f7f9fc;
  padding: 20px;
  border-right: 1px solid #e2e8f0;
  overflow-y: auto;
}

.messages-sidebar h2 {
  font-size: 20px;
  font-weight: 600;
  margin-bottom: 16px;
  color: #1a202c;
}

.chat-list {
  list-style: none;
  padding: 0;
}

.chat-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.2s ease;
  position: relative;
}

.chat-item:hover {
  background: #edf2f7;
}

.chat-item.active {
  background: #e2e8f0;
}

.chat-avatar {
  font-size: 24px;
  color: #4a90e2;
  margin-right: 12px;
}

.chat-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  position: relative;
}

.chat-with {
  font-weight: 600;
  font-size: 16px;
  color: #1a202c;
}

.chat-last-message {
  font-size: 14px;
  color: #4a5568;
  margin-top: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-item .badge {
  position: absolute;
  top: 50%;
  right: 12px;
  transform: translateY(-50%);
  background: #ff4d4f;
  color: #ffffff;
  border-radius: 50%;
  font-size: 12px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.chat-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 20px;
}

@media (max-width: 768px) {
  .messages-container {
    flex-direction: column;
    height: calc(100vh - 120px); /* Учитываем навбар и bottom-nav */
  }

  .messages-sidebar {
    width: 100%;
    max-height: 200px;
    border-right: none;
    border-bottom: 1px solid #e2e8f0;
  }

  .chat-container {
    flex: 1;
    padding: 10px;
  }

  .chat-item .badge {
    right: 10px;
    width: 16px;
    height: 16px;
    font-size: 10px;
  }
}

@media (max-width: 480px) {
  .messages-sidebar {
    padding: 10px;
  }

  .chat-item {
    padding: 10px;
  }

  .chat-with {
    font-size: 14px;
  }

  .chat-last-message {
    font-size: 12px;
  }

  .chat-avatar {
    font-size: 20px;
    margin-right: 10px;
  }
}


Chat.js:
import React, { useState, useEffect, useContext } from "react";
import axios from "axios";
import { AuthContext } from "../App";
import { FiSend, FiArrowLeft } from "react-icons/fi";
import { useNavigate } from "react-router-dom";
import "../App.css";

function Chat({ chatId, recipient, onMessageSent }) {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState("");

  const fetchMessages = async () => {
    try {
      const response = await axios.get(`http://localhost:3000/messages/${chatId}`, {
        headers: { Authorization: `Bearer ${user.token}` },
      });
      setMessages(response.data);
      // Отмечаем сообщения как прочитанные
      await axios.post(
        `http://localhost:3000/messages/${chatId}/read`,
        {},
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
    } catch (err) {
      console.error("Fetch messages error:", err.message, err.response?.data);
    }
  };

  useEffect(() => {
    if (chatId) {
      fetchMessages();
    }
  }, [chatId]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim()) return;
    try {
      const response = await axios.post(
        `http://localhost:3000/messages/${chatId}`,
        { text: newMessage },
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
      setMessages([...messages, response.data]);
      setNewMessage("");
      onMessageSent(); // Обновляем список чатов
    } catch (err) {
      console.error("Send message error:", err.message, err.response?.data);
    }
  };

  return (
    <div className="chat-container">
      <div className="chat-header">
        <button className="back-button" onClick={() => navigate("/messages")}>
          <FiArrowLeft />
        </button>
        <h3>{recipient}</h3>
      </div>
      <div className="messages-list">
        {messages.map((msg, index) => (
          <div
            key={index}
            className={`message ${msg.from === user.username ? "sent" : "received"}`}
          >
            <p>{msg.text}</p>
            <small>{new Date(msg.timestamp).toLocaleTimeString()}</small>
          </div>
        ))}
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
    </div>
  );
}

export default Chat;




