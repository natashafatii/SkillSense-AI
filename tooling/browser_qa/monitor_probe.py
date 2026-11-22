"""Two isolated local Chrome pages, real WebRTC, two synthetic audio sources."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from threading import Event, Thread

root = Path(__file__).resolve().parents[2]
files = {'/': root / 'tooling/browser_qa/monitor_probe.html',
         '/live_monitor.js': root / 'web/live_monitor.js',
         '/bridge.js': root / 'tooling/voice_sdk/bridge.js'}
done = Event()
results = []


class Fixture(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split('?', 1)[0]
        if path not in files:
            return self.send_error(404)
        self.send_response(200)
        self.send_header('Content-Type', 'text/html' if path == '/' else 'text/javascript')
        self.end_headers()
        self.wfile.write(files[path].read_bytes())

    def do_POST(self):
        if self.path != '/result':
            return self.send_error(404)
        results.append(self.rfile.read(min(int(self.headers['Content-Length']), 16)) == b'passed')
        self.send_response(204)
        self.end_headers()
        done.set()

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--scenario', choices=['rejoin', 'relay-failure', 'signal-loss'], default='rejoin')
    scenario = parser.parse_args().scenario
    browser = os.getenv('QA_BROWSER', r'C:\Program Files\Google\Chrome\Application\chrome.exe')
    with ThreadingHTTPServer(('127.0.0.1', 0), Fixture) as server, tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as profile:
        Thread(target=server.serve_forever, daemon=True).start()
        chrome = subprocess.Popen([browser, '--headless=new', '--disable-popup-blocking', '--no-first-run',
            '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
            '--autoplay-policy=no-user-gesture-required', '--user-data-dir=' + profile,
            f'http://127.0.0.1:{server.server_port}/?scenario={scenario}'])
        try:
            if not done.wait(35) or not all(results):
                raise SystemExit('Synthetic camera/audio or teardown assertion failed')
            print(f'PASS: {scenario} with synthetic media and real browser WebRTC.')
        finally:
            chrome.terminate()
            chrome.wait()
            server.shutdown()
