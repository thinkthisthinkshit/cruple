const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  console.log("authMiddleware - Token:", token ? token.substring(0, 20) + "..." : "undefined");
  if (!token) {
    console.log("authMiddleware - No token provided");
    return res.status(401).json({ error: "Требуется авторизация" });
  }
  try {
    const decoded = jwt.verify(token, "secret");
    console.log("authMiddleware - Decoded user:", decoded);
    req.user = decoded;
    next();
  } catch (err) {
    console.error("authMiddleware - Token verification error:", err.message, "Token:", token);
    res.status(401).json({ error: "Недействительный токен" });
  }
};



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
  FiStar,
} from "react-icons/fi";
import io from "socket.io-client";

const socket = io("http://localhost:3000");

function Navbar() {
  const { user, setUser } = useContext(AuthContext);
  const navigate = useNavigate();
  const [showAuthorModal, setShowAuthorModal] = useState(false);
  const [authorNickname, setAuthorNickname] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const [showSidebar, setShowSidebar] = useState(false);
  const [unreadMessagesCount, setUnreadMessagesCount] = useState(0);
  const dropdownRef = useRef(null);
  const touchStartX = useRef(null);

  // Загрузка unreadMessagesCount
  const fetchCounts = async () => {
    if (!user || !user.token) {
      console.log("fetchCounts skipped: No user or token");
      return;
    }
    try {
      console.log("Fetching counts for user:", user.username);
      const messagesRes = await axios.get("http://localhost:3000/messages/unread");
      console.log("Messages response:", messagesRes.data);
      setUnreadMessagesCount(messagesRes.data.unreadMessagesCount);
    } catch (err) {
      console.error("Fetch messages count error:", err.message, err.response?.data);
      if (err.response?.status === 401 || err.response?.status === 403) {
        console.log(`${err.response.status} Error: Invalid or missing token`);
        toast.error("Сессия истекла, пожалуйста, войдите снова");
        // Не вызываем logout автоматически
      }
    }
  };

  useEffect(() => {
    console.log("Navbar useEffect - User:", user);
    if (user && user.username && user.token) {
      console.log("Navbar - User ready, scheduling fetchCounts");
      const timer = setTimeout(() => {
        fetchCounts();
        socket.emit("joinChat", user.username);
        console.log("Joined chat for user:", user.username);
      }, 500);
      return () => clearTimeout(timer);
    } else {
      console.log("Navbar - User not ready, skipping fetchCounts");
    }
  }, [user]);

  // Socket.IO: Обработка новых сообщений и отметки прочитанных
  useEffect(() => {
    socket.on("newMessage", (message) => {
      console.log("Socket.IO: New message received:", message);
      if (user && message.to === user.username) {
        console.log("New message for current user, refetching counts");
        fetchCounts();
      }
    });

    socket.on("messagesRead", ({ chatId }) => {
      console.log("Socket.IO: Messages read for chatId:", chatId);
      fetchCounts();
    });

    return () => {
      socket.off("newMessage");
      socket.off("messagesRead");
    };
  }, [user, fetchCounts]);

  // Обработка кликов вне дропдауна и сайдбара
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

  // Обработка свайпа для сайдбара
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
      const response = await axios.post(
        "http://localhost:3000/become-author",
        { authorNickname }
      );
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
              <FiHome />
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
              className="nav-messages-button"
              onClick={() => navigate("/messages")}
              title="Сообщения"
            >
              <FiMessageSquare />
              {unreadMessagesCount > 0 && (
                <span className="badge">{unreadMessagesCount}</span>
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
            <button
              className="login-button"
              onClick={() => navigate("/login")}
            >
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
              <span className="badge">{unreadMessagesCount}</span>
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





import React, { useState, useContext } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";
import { AuthContext } from "../App";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { FiLogIn } from "react-icons/fi";

function Login() {
  const { setUser } = useContext(AuthContext);
  const navigate = useNavigate();
  const [isLogin, setIsLogin] = useState(true);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    console.log(`Login.js - Submitting ${isLogin ? "login" : "register"} with:`, { username, password });
    try {
      const endpoint = isLogin ? "/login" : "/register";
      const response = await axios.post(`http://localhost:3000${endpoint}`, {
        username,
        password,
      });
      console.log("Login.js - Response:", response.data);
      if (isLogin) {
        const { token, role, authorNickname } = response.data;
        const newUser = { username, token, role, authorNickname: authorNickname || "" };
        console.log("Login.js - Saving user:", newUser);
        setUser(newUser);
        localStorage.setItem("user", JSON.stringify(newUser));
        toast.success("Вход успешен!");
        navigate("/");
      } else {
        toast.success("Регистрация успешна! Теперь войдите.");
        setIsLogin(true);
      }
      setUsername("");
      setPassword("");
    } catch (err) {
      console.error("Login.js - Error:", err.response?.data);
      toast.error(err.response?.data?.error || "Ошибка");
    }
  };

  return (
    <div className="login-container">
      <h1>{isLogin ? "Вход" : "Регистрация"}</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Имя пользователя"
          required
        />
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Пароль"
          required
        />
        <button type="submit" className="login-button">
          <FiLogIn /> {isLogin ? "Войти" : "Зарегистрироваться"}
        </button>
      </form>
      <button className="toggle-button" onClick={() => setIsLogin(!isLogin)}>
        {isLogin ? "Нет аккаунта? Зарегистрируйтесь" : "Уже есть аккаунт? Войдите"}
      </button>
      <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
    </div>
  );
}

export default Login;
