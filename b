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
  const { user, setUser } = useContext(AuthContext);
  const navigate = useNavigate();
  const [showAuthorModal, setShowAuthorModal] = useState(false);
  const [authorNickname, setAuthorNickname] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);
  const [showSidebar, setShowSidebar] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [unreadMessagesCount, setUnreadMessagesCount] = useState(0);
  const dropdownRef = useRef(null);
  const touchStartX = useRef(null);

  // Загрузка unreadCount и unreadMessagesCount
  const fetchCounts = async () => {
    try {
      console.log("Fetching counts...");
      const [notificationsRes, messagesRes] = await Promise.all([
        axios.get("http://localhost:3000/notifications/unread", {
          headers: { Authorization: `Bearer ${user.token}` },
        }),
        axios.get("http://localhost:3000/messages/unread", {
          headers: { Authorization: `Bearer ${user.token}` },
        }),
      ]);
      console.log("Notifications count:", notificationsRes.data.unreadCount);
      console.log("Messages count:", messagesRes.data.unreadMessagesCount);
      setUnreadCount(notificationsRes.data.unreadCount);
      setUnreadMessagesCount(messagesRes.data.unreadMessagesCount);
    } catch (err) {
      console.error("Fetch counts error:", err.message, err.response?.data);
    }
  };

  useEffect(() => {
    if (user) {
      fetchCounts();
      socket.emit("joinChat", user.username);
    }
  }, [user]);

  // Socket.IO: Обработка новых сообщений и отметки прочитанных
  useEffect(() => {
    socket.on("newMessage", (message) => {
      if (message.to === user.username) {
        console.log("Socket.IO: New message received:", message);
        fetchCounts();
      }
    });

    socket.on("messagesRead", () => {
      console.log("Socket.IO: Messages read, refetching unread count");
      fetchCounts();
    });

    return () => {
      socket.off("newMessage");
      socket.off("messagesRead");
    };
  }, [user]);

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
        { authorNickname },
        { headers: { Authorization: `Bearer ${user.token}` } }
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
              {unreadCount > 0 && <span className="badge">{unreadCount}</span>}
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
          <button
            className="bottom-nav-item pulse"
            onClick={() => navigate("/notifications")}
            title="Уведомления"
          >
            <FiBell />
            {unreadCount > 0 && <span className="badge">{unreadCount}</span>}
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
