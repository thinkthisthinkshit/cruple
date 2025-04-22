Navbar.js:
useEffect(() => {
  if (user && user.username && user.token) {
    console.log("Navbar useEffect - User:", user);
    fetchCounts();
    socket.emit("joinChat", user.username);
  }
}, [user]);




useEffect(() => {
  const interceptor = axios.interceptors.request.use((config) => {
    console.log(`Axios interceptor - URL: ${config.url}, Token: ${user?.token || "none"}`);
    if (user?.token) {
      config.headers.Authorization = `Bearer ${user.token}`;
    }
    return config;
  });
  return () => {
    axios.interceptors.request.eject(interceptor);
  };
}, [user]);
