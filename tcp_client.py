# server.py
import socket, sys
port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', port))
s.listen(1)
print(f"Listening on 127.0.0.1:{port}")
conn, addr = s.accept()
data = b""
while True:
    chunk = conn.recv(4096)
    if not chunk:
        break
    data += chunk
conn.sendall(b"SERVER REPLY: " + data)
conn.close()
s.close()
