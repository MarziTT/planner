#!/usr/bin/env python3
"""
持久 HTTP 服务器，为 Pixel Planner v3.3 mockup 提供静态文件服务。
运行在 0.0.0.0:8080，不会自动退出。
"""
import http.server
import socketserver
import os
import sys
import signal

PORT = 8080
DIR = os.path.dirname(os.path.abspath(__file__))

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # 静默日志，只输出错误
        pass
    
    def log_error(self, format, *args):
        print(f"[ERROR] {format % args}", file=sys.stderr)

def signal_handler(sig, frame):
    print(f"\n服务器收到终止信号，正在关闭...")
    sys.exit(0)

if __name__ == "__main__":
    os.chdir(DIR)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    with socketserver.TCPServer(("", PORT), QuietHandler) as httpd:
        print("=" * 60)
        print(f"Pixel Planner v3.3 Mockup 服务器已启动")
        print(f"本地访问: http://localhost:{PORT}/v3.3-mockup.html")
        print(f"局域网访问: http://<你的IP>:{PORT}/v3.3-mockup.html")
        print(f"按 Ctrl+C 停止服务器")
        print("=" * 60)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务器已停止")
            sys.exit(0)