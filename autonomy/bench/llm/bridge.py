#!/usr/bin/env python3
"""Byte-level TCP <-> Unix-socket forwarder that carries exactly one port into the sandbox.

usage: bridge.py tcp2unix PORT SOCK        (inside: listen 127.0.0.1:PORT, connect SOCK)
       bridge.py unix2tcp SOCK HOST PORT   (outside: listen SOCK, connect HOST:PORT)

pi-run runs bwrap with --unshare-net, so the sandbox has only its own loopback. One
bridge on each side of a bind-mounted socket gives pi the model endpoint without
sharing the host network. Sharing it would expose the internet and every host-loopback
service.
"""
import os
import socket
import sys
import threading


def pump(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def handle(client, connect):
    try:
        upstream = connect()
    except OSError:
        client.close()
        return
    t = threading.Thread(target=pump, args=(upstream, client), daemon=True)
    t.start()
    pump(client, upstream)
    t.join()
    client.close()
    upstream.close()


def serve(listener, connect):
    listener.listen(64)
    while True:
        client, _ = listener.accept()
        threading.Thread(target=handle, args=(client, connect), daemon=True).start()


def main(argv):
    if len(argv) == 3 and argv[0] == "tcp2unix":
        port, path = int(argv[1]), argv[2]
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("127.0.0.1", port))

        def connect():
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(path)
            return s
    elif len(argv) == 4 and argv[0] == "unix2tcp":
        path, host, port = argv[1], argv[2], int(argv[3])
        if os.path.exists(path):
            os.unlink(path)
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(path)

        def connect():
            return socket.create_connection((host, port), timeout=None)
    else:
        print(__doc__, file=sys.stderr)
        return 2
    serve(listener, connect)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
