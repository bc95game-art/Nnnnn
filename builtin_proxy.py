"""
پروکسی SOCKS5 داخلی — بدون نیاز به سرور خارجی
برای تست کامل سیستم در Termux
"""

import socket
import threading
import select
import struct
import sys
import os

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1080

SOCKS_VERSION = 5

def handle_client(conn: socket.socket):
    try:
        # ── مرحله ۱: احراز هویت (بدون رمز) ──
        header = conn.recv(2)
        if len(header) < 2:
            return
        ver, nmethods = header[0], header[1]
        methods = conn.recv(nmethods)
        # انتخاب روش بدون رمز (0x00)
        conn.sendall(b"\x05\x00")

        # ── مرحله ۲: دریافت درخواست اتصال ──
        req = conn.recv(4)
        if len(req) < 4:
            return
        ver, cmd, rsv, atyp = req

        if atyp == 0x01:        # IPv4
            raw = conn.recv(4)
            addr = socket.inet_ntoa(raw)
        elif atyp == 0x03:      # Domain
            length = conn.recv(1)[0]
            addr = conn.recv(length).decode("utf-8", errors="replace")
        elif atyp == 0x04:      # IPv6
            raw = conn.recv(16)
            addr = socket.inet_ntop(socket.AF_INET6, raw)
        else:
            conn.close()
            return

        port_raw = conn.recv(2)
        port = struct.unpack(">H", port_raw)[0]

        if cmd != 0x01:         # فقط CONNECT
            conn.sendall(b"\x05\x07\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return

        # ── مرحله ۳: اتصال به مقصد ──
        try:
            remote = socket.create_connection((addr, port), timeout=10)
        except Exception:
            conn.sendall(b"\x05\x05\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return

        # پاسخ موفق
        conn.sendall(b"\x05\x00\x00\x01" + b"\x00"*4 + b"\x00\x00")

        # ── مرحله ۴: ریلی دوطرفه ──
        _relay(conn, remote)

    except Exception:
        pass
    finally:
        try: conn.close()
        except: pass


def _relay(a: socket.socket, b: socket.socket):
    a.setblocking(False)
    b.setblocking(False)
    try:
        while True:
            r, _, _ = select.select([a, b], [], [], 60)
            if not r:
                break
            for s in r:
                other = b if s is a else a
                try:
                    data = s.recv(65536)
                    if not data:
                        return
                    other.sendall(data)
                except Exception:
                    return
    finally:
        try: b.close()
        except: pass


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(100)

    print(f"[SOCKS5] سرور محلی فعال روی {HOST}:{PORT}", flush=True)

    while True:
        try:
            conn, _ = server.accept()
            conn.settimeout(30)
            t = threading.Thread(target=handle_client, args=(conn,), daemon=True)
            t.start()
        except KeyboardInterrupt:
            print("[SOCKS5] متوقف شد")
            break
        except Exception:
            pass
    server.close()


if __name__ == "__main__":
    main()
