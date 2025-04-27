version: "2"
authtoken: YOUR_NGROK_AUTHTOKEN
tunnels:
  frontend:
    proto: http
    addr: https://localhost:5173
  backend:
    proto: http
    addr: 3001
