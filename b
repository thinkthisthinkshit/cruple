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

    const joinChat = () => {
      socket.emit("joinChat", chatId);
      console.log(`Joined chat: ${chatId}`);
    };

    const fetchMessages = async () => {
      try {
        const response = await axios.get(`http://localhost:3000/messages/${chatId}`, {
          headers: { Authorization: `Bearer ${user.token}` },
        });
        console.log("Messages fetched:", response.data);
        setMessages(response.data);
        const firstMessage = response.data[0];
        if (firstMessage) {
          const otherUser = firstMessage.from === user.username ? firstMessage.to : firstMessage.from;
          setRecipient({ username: otherUser });
        }
      } catch (err) {
        console.error("Fetch messages error:", err);
        toast.error("Не удалось загрузить сообщения");
      }
    };

    fetchMessages();
    joinChat();
    socket.on("newMessage", (message) => {
      console.log("New message received:", message);
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
    const scrollToBottom = () => {
      if (messagesEndRef.current) {
        messagesEndRef.current.scrollIntoView({ behavior: "smooth" });
      }
    };
    scrollToBottom();
  }, [messages]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim()) return;

    try {
      const recipientUsername = recipient?.username;
      if (!recipientUsername) {
        toast.error("Получатель не найден");
        return;
      }
      const messageData = { text: newMessage };
      const response = await axios.post(
        `http://localhost:3000/messages/${chatId}`,
        messageData,
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
      console.log("Message sent:", response.data);
      setMessages((prev) => [...prev, response.data]);
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
          <h1>{recipient?.username || "Чат"}</h1>
        </div>
        <div className="messages-list">
          {messages.map((msg) => (
            <div
              key={msg._id}
              className={`message ${msg.from === user.username ? "sent" : "received"}`}
            >
              <p>{msg.text}</p>
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
