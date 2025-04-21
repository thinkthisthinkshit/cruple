import React, { useState, useEffect, useContext, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import axios from "axios";
import { Helmet, HelmetProvider } from "react-helmet-async";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import DepositModal from "./DepositModal";
import SubscribeButton from "./SubscribeButton";
import Post from "./Post";
import Media from "./Media";
import { AuthContext } from "../App";
import { FiEdit, FiLink, FiShare2, FiLogIn, FiMessageSquare } from "react-icons/fi";

function AuthorProfile() {
  const { username } = useParams();
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [author, setAuthor] = useState(null);
  const [authorPosts, setAuthorPosts] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [qrData, setQrData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("posts");
  const [error, setError] = useState(null);

  const fetchAuthor = useCallback(async () => {
    try {
      const res = await axios.get(`http://localhost:3000/users/${username}`);
      console.log("Author fetched:", res.data);
      setAuthor(res.data);
      setError(null);
    } catch (err) {
      console.error("Fetch author error:", err);
      setError(err.response?.data?.error || "Не удалось загрузить автора");
      toast.error(err.response?.data?.error || "Не удалось загрузить автора");
    }
  }, [username]);

  const fetchPosts = useCallback(async () => {
    try {
      const res = await axios.get(`http://localhost:3000/posts/${username}`);
      console.log("Posts fetched:", res.data);
      setAuthorPosts(res.data);
    } catch (err) {
      console.error("Fetch posts error:", err);
      toast.error("Не удалось загрузить посты");
    } finally {
      setIsLoading(false);
    }
  }, [username]);

  useEffect(() => {
    setIsLoading(true);
    fetchAuthor();
    if (user) fetchPosts();
    else setIsLoading(false);
  }, [fetchAuthor, fetchPosts, user]);

  const handleDonate = async () => {
    if (!user) {
      toast.error("Войдите, чтобы поддержать автора");
      navigate("/login");
      return;
    }
    try {
      const res = await axios.get(`http://localhost:3000/generate/${username}/qr`, {
        headers: { Authorization: `Bearer ${user.token}` },
      });
      console.log("QR data fetched:", res.data);
      setQrData(res.data);
      setShowModal(true);
    } catch (err) {
      console.error("Ошибка при генерации QR-кода:", err);
      toast.error("Не удалось сгенерировать адрес");
    }
  };

  const handleEditProfile = () => {
    navigate("/settings");
  };

  const handleShareProfile = () => {
    const profileUrl = `${window.location.origin}/author/${username}`;
    navigator.clipboard.writeText(profileUrl);
    toast.success("Ссылка на профиль скопирована!");
  };

  const handleStartChat = async () => {
    if (!user) {
      toast.error("Войдите, чтобы начать чат");
      navigate("/login");
      return;
    }
    try {
      const response = await axios.post(
        "http://localhost:3000/messages/start",
        { username },
        { headers: { Authorization: `Bearer ${user.token}` } }
      );
      console.log("Chat started:", response.data);
      navigate(`/messages/${response.data.chatId}`);
    } catch (err) {
      console.error("Start chat error:", err);
      toast.error(err.response?.data?.error || "Ошибка начала чата");
    }
  };

  if (error) {
    return (
      <HelmetProvider>
        <div className="author-profile-container">
          <Helmet>
            <title>Ошибка - CryptoAuthors</title>
            <meta name="description" content="Ошибка загрузки профиля автора." />
          </Helmet>
          <div className="error-message">
            <h2>Ошибка</h2>
            <p>{error}</p>
            <button onClick={() => navigate("/")}>Вернуться на главную</button>
          </div>
          <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
        </div>
      </HelmetProvider>
    );
  }

  if (!author) {
    return (
      <HelmetProvider>
        <div className="author-profile-container">
          <Helmet>
            <title>Загрузка - CryptoAuthors</title>
            <meta name="description" content="Загрузка профиля автора..." />
          </Helmet>
          <div className="spinner-container">
            <div className="spinner"></div>
          </div>
          <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
        </div>
      </HelmetProvider>
    );
  }

  const isOwnProfile = user && user.username === username;

  return (
    <HelmetProvider>
      <div className="author-profile-container">
        <Helmet>
          <title>
            {activeTab === "posts"
              ? `Контент ${author.authorNickname || username} - CryptoAuthors`
              : `Галерея ${author.authorNickname || username} - CryptoAuthors`}
          </title>
          <meta
            name="description"
            content={
              activeTab === "posts"
                ? `Просмотрите контент автора ${author.authorNickname || username} и поддержите их донатом в BTC.`
                : `Просмотрите медиа-галерею автора ${author.authorNickname || username} на CryptoAuthors.`
            }
          />
        </Helmet>
        <div className="author-profile-header">
          <div className="author-cover">
            <img
              src={author.coverPhoto || "/default-cover.jpg"}
              alt="Author Cover"
              className="cover-photo"
            />
            <div className="cover-overlay">
              <h2 className="cover-nickname">{author.authorNickname || username}</h2>
              <p className="cover-subscribers">{author.subscribers || 0} подписчиков</p>
            </div>
          </div>
          <div className="author-avatar-section">
            <div className="author-avatar">
              <img src={author.avatarUrl || "/logo.png"} alt="Author Avatar" />
            </div>
            <h2 className="author-nickname">{author.authorNickname || username}</h2>
            <div className="author-actions">
              {user && (
                <button className="share-profile-button" onClick={handleShareProfile}>
                  <FiShare2 /> Поделиться
                </button>
              )}
              {!isOwnProfile && user && (
                <button className="message-button" onClick={handleStartChat}>
                  <FiMessageSquare /> Сообщение
                </button>
              )}
              {isOwnProfile && (
                <button className="edit-profile-button" onClick={handleEditProfile}>
                  <FiEdit /> Редактировать профиль
                </button>
              )}
            </div>
          </div>
          {isOwnProfile && user.role === "author" && (
            <button className="content-button" onClick={() => navigate("/content")}>
              <FiEdit /> Создать контент
            </button>
          )}
        </div>
        {user ? (
          <>
            {!isOwnProfile && (
              <div className="subscribe-section">
                <SubscribeButton
                  authorUsername={username}
                  subscriptionPrice={author.subscriptionPrice || 5}
                />
              </div>
            )}
            <div className="author-about-section">
              <h3>О себе</h3>
              <p>{author.about || "Автор пока не добавил информацию о себе."}</p>
              {author.socialLinks && author.socialLinks.length > 0 && (
                <div className="social-links">
                  <h4>Социальные сети</h4>
                  <ul>
                    {author.socialLinks.slice(0, 5).map((link, index) => (
                      <li key={index}>
                        <a href={link} target="_blank" rel="noopener noreferrer">
                          <FiLink /> {link}
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
            <div className="donate-section">
              <button
                className="donate-button"
                onClick={handleDonate}
                disabled={!user}
                title={!user ? "Войдите, чтобы поддержать" : "Поддержать автора (QR)"}
              >
                Поддержать автора (QR)
              </button>
            </div>
            <div className="content-tabs">
              <button
                className={`tab-button ${activeTab === "posts" ? "active" : ""}`}
                onClick={() => setActiveTab("posts")}
              >
                Контент
              </button>
              <button
                className={`tab-button ${activeTab === "media" ? "active" : ""}`}
                onClick={() => setActiveTab("media")}
              >
                Галерея
              </button>
            </div>
            {activeTab === "posts" ? (
              <>
                {isLoading ? (
                  <div className="skeleton-list">
                    {[...Array(3)].map((_, i) => (
                      <div key={i} className="skeleton skeleton-post"></div>
                    ))}
                  </div>
                ) : authorPosts.length ? (
                  <ul className="post-list">
                    {authorPosts.map((post) => (
                      <li key={post._id}>
                        {post.type === "media" ? <Media post={post} /> : <Post post={post} />}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p>У этого автора пока нет контента</p>
                )}
              </>
            ) : (
              <>
                {isLoading ? (
                  <div className="skeleton-list">
                    {[...Array(3)].map((_, i) => (
                      <div key={i} className="skeleton skeleton-post"></div>
                    ))}
                  </div>
                ) : authorPosts.filter((post) => post.type === "media").length ? (
                  <div className="media-gallery">
                    {authorPosts
                      .filter((post) => post.type === "media")
                      .map((post) => (
                        <div key={post._id} className="media-gallery-item">
                          {post.mediaUrl.endsWith(".mp4") ? (
                            <video
                              src={post.mediaUrl}
                              controls
                              className="media-gallery-content"
                              loading="lazy"
                            />
                          ) : (
                            <img
                              src={post.mediaUrl}
                              alt="Media"
                              className="media-gallery-content"
                              loading="lazy"
                            />
                          )}
                        </div>
                      ))}
                  </div>
                ) : (
                  <p>У этого автора пока нет медиа</p>
                )}
              </>
            )}
          </>
        ) : (
          <div className="guest-message">
            <p>Войдите, чтобы увидеть контент и поддержать автора.</p>
            <button onClick={() => navigate("/login")} className="login-button">
              <FiLogIn /> Войти
            </button>
          </div>
        )}
        {showModal && qrData && (
          <DepositModal qrData={qrData} onClose={() => setShowModal(false)} />
        )}
        <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} />
      </div>
    </HelmetProvider>
  );
}

export default AuthorProfile;
