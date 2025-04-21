/* Навбар */
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #ffffff;
  padding: 10px 20px;
  border-bottom: 1px solid #e2e8f0;
  position: fixed;
  top: 0;
  width: 100%;
  z-index: 1000;
  height: 60px;
  box-sizing: border-box;
}

.nav-logo {
  font-size: 24px;
  font-weight: bold;
  color: #1a202c;
  cursor: pointer;
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: 16px;
}

.nav-home-button,
.nav-search-button,
.nav-notifications-button,
.nav-messages-button,
.nav-favorites-button,
.nav-menu-button {
  background: none;
  border: none;
  font-size: 20px;
  color: #4a5568;
  cursor: pointer;
  position: relative;
  padding: 8px;
  transition: color 0.2s ease;
}

.nav-home-button:hover,
.nav-search-button:hover,
.nav-notifications-button:hover,
.nav-messages-button:hover,
.nav-favorites-button:hover,
.nav-menu-button:hover {
  color: #2d3748;
}

.nav-messages-button .badge,
.nav-notifications-button .badge,
.bottom-nav-item .badge {
  position: absolute;
  top: -4px;
  right: -4px;
  background: #ff4d4f;
  color: #ffffff;
  border-radius: 50%;
  font-size: 12px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}

.nav-header {
  display: flex;
  align-items: center;
  gap: 16px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 16px;
  color: #1a202c;
}

.login-button {
  background: #4a90e2;
  color: #ffffff;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 16px;
}

.dropdown-menu {
  position: absolute;
  top: 60px;
  right: 20px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  z-index: 1000;
  min-width: 200px;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 8px;
  background: none;
  border: none;
  width: 100%;
  padding: 12px 16px;
  text-align: left;
  font-size: 16px;
  color: #1a202c;
  cursor: pointer;
}

.dropdown-item:hover {
  background: #f7f9fc;
}

.bottom-nav {
  display: none;
  position: fixed;
  bottom: 0;
  width: 100%;
  background: #ffffff;
  border-top: 1px solid #e2e8f0;
  padding: 10px 0;
  z-index: 1000;
  justify-content: space-around;
}

.bottom-nav-item {
  background: none;
  border: none;
  font-size: 20px;
  color: #4a5568;
  cursor: pointer;
  position: relative;
  padding: 8px;
  transition: color 0.2s ease;
}

.bottom-nav-item:hover {
  color: #2d3748;
}

@media (max-width: 768px) {
  .navbar {
    padding: 10px;
  }

  .nav-actions {
    display: none;
  }

  .bottom-nav {
    display: flex;
  }

  .nav-logo {
    font-size: 20px;
  }

  .nav-menu-button {
    display: block;
  }

  .nav-messages-button .badge,
  .nav-notifications-button .badge,
  .bottom-nav-item .badge {
    width: 16px;
    height: 16px;
    font-size: 10px;
    top: -2px;
    right: -2px;
  }
}

@media (max-width: 480px) {
  .navbar {
    padding: 8px;
  }

  .nav-logo {
    font-size: 18px;
  }

  .bottom-nav-item {
    font-size: 18px;
    padding: 6px;
  }
}
.nav-messages-button .badge,
.nav-notifications-button .badge,
.bottom-nav-item .badge {
  position: absolute;
  top: -4px;
  right: -4px;
  background: #ff4d4f;
  color: #ffffff;
  border-radius: 50%;
  font-size: 12px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}
