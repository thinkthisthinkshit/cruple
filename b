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

  useEffect(() => {
    const storedUser = localStorage.getItem("user");
    if (storedUser) {
      try {
        const parsedUser = JSON.parse(storedUser);
        console.log("App.js - Loaded user from localStorage:", parsedUser);
        if (parsedUser && parsedUser.token) {
          setUser(parsedUser);
        } else {
          console.warn("App.js - Invalid user data, missing token:", parsedUser);
          localStorage.removeItem("user");
        }
      } catch (err) {
        console.error("App.js - Error parsing stored user:", err);
        localStorage.removeItem("user");
      }
    } else {
      console.log("App.js - No user in localStorage");
    }
  }, []);

  useEffect(() => {
    const interceptor = axios.interceptors.request.use(
      (config) => {
        const token = user?.token;
        console.log("App.js - Axios interceptor - URL:", config.url, "Token:", token || "undefined");
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        } else {
          console.log("App.js - Axios interceptor - No token available");
        }
        return config;
      },
      (error) => {
        console.error("App.js - Axios interceptor error:", error);
        return Promise.reject(error);
      }
    );

    return () => {
      axios.interceptors.request.eject(interceptor);
    };
  }, [user]);

  return (
    <AuthContext.Provider value={{ user, setUser }}>
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


