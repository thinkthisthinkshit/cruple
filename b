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
