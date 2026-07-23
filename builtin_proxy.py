"""
پروکسی SOCKS5 داخلی — بدون نیاز به سرور خارجی
با مدیریت خطای کامل
"""

import socket
import threading
import select
import struct
import sys
import os
import logging

logging.basicConfig(
    level=logging.INFO,
    format="[SOCKS5] %(message)s",
    stream=sys.stdout
)
log = logging.getLogger("socks5")

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1080
MAX_CONNECTIONS = 200
RELAY_TIMEOUT = 60
CONNECT_TIMEOUT = 10


def handle_client(conn: socket.socket, addr: tuple):
    try:
        # ── مرحله ۱: مذاکره احراز هویت ──
        conn.settimeout(10)
        header = conn.recv(2)
        if len(header) < 2:
            return
        ver, nmethods = header[0], header[1]
        if ver != 5:
            log.warning(f"نسخه SOCKS نادرست: {ver}")
            return
        methods = conn.recv(nmethods)
        conn.sendall(b"\x05\x00")  # بدون رمز

        # ── مرحله ۲: دریافت درخواست ──
        req = conn.recv(4)
        if len(req) < 4:
            return
        ver, cmd, rsv, atyp = req

        if atyp == 0x01:        # IPv4
            raw = conn.recv(4)
            if len(raw) < 4:
                return
            addr = socket.inet_ntoa(raw)
        elif atyp == 0x03:      # Domain
            length_b = conn.recv(1)
            if not length_b:
                return
            length = length_b[0]
            addr = conn.recv(length).decode("utf-8", errors="replace")
        elif atyp == 0x04:      # IPv6
            raw = conn.recv(16)
            if len(raw) < 16:
                return
            addr = socket.inet_ntop(socket.AF_INET6, raw)
        else:
            conn.sendall(b"\x05\x08\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return

        port_raw = conn.recv(2)
        if len(port_raw) < 2:
            return
        port = struct.unpack(">H", port_raw)[0]

        if cmd != 0x01:         # فقط CONNECT پشتیبانی می‌شود
            conn.sendall(b"\x05\x07\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return

        # ── مرحله ۳: اتصال به مقصد ──
        try:
            remote = socket.create_connection((addr, port), timeout=CONNECT_TIMEOUT)
        except socket.timeout:
            log.warning(f"timeout اتصال به {addr}:{port}")
            conn.sendall(b"\x05\x04\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return
        except (socket.gaierror, OSError) as e:
            log.warning(f"خطا اتصال به {addr}:{port} — {e}")
            conn.sendall(b"\x05\x05\x00\x01" + b"\x00"*4 + b"\x00\x00")
            return

        # پاسخ موفق
        conn.sendall(b"\x05\x00\x00\x01" + b"\x00"*4 + b"\x00\x00")
        log.info(f"اتصال: {addr}:{port}")

        # ── مرحله ۴: ریلی دوطرفه ──
        _relay(conn, remote)

    except (ConnectionResetError, BrokenPipeError):
        pass
    except Exception as e:
        log.debug(f"خطای غیرمنتظره: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass


def _relay(a: socket.socket, b: socket.socket):
    a.setblocking(False)
    b.setblocking(False)
    try:
        while True:
            try:
                r, _, err_socks = select.select([a, b], [], [a, b], RELAY_TIMEOUT)
            except (ValueError, OSError):
                break

            if err_socks:
                break
            if not r:
                break  # timeout

            for s in r:
                other = b if s is a else a
                try:
                    data = s.recv(65536)
                    if not data:
                        return
                    other.sendall(data)
                except (ConnectionResetError, BrokenPipeError, OSError):
                    return
    finally:
        try:
            b.close()
        except Exception:
            pass


def main():
    # بررسی پورت
    try:
        test_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        test_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        test_sock.bind((HOST, PORT))
        test_sock.close()
    except OSError:
        log.error(f"پورت {PORT} اشغال است!")
        sys.exit(1)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(MAX_CONNECTIONS)
    server.settimeout(1)

    log.info(f"سرور محلی فعال روی {HOST}:{PORT}")

    active = 0
    while True:
        try:
            conn, addr = server.accept()
            conn.settimeout(30)
            active += 1
            t = threading.Thread(
                target=handle_client,
                args=(conn, addr),
                daemon=True,
                name=f"socks-{active}"
            )
            t.start()
        except socket.timeout:
            continue
        except KeyboardInterrupt:
            log.info("متوقف شد")
            break
        except Exception as e:
            log.debug(f"خطا در accept: {e}")

    server.close()


if __name__ == "__main__":
    main()
