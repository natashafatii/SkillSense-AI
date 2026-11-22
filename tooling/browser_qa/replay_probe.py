"""Drive the real MediaRecorder API with a synthetic camera and local upload endpoint."""
import hashlib
import os
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Event, Thread

ROOT = Path(__file__).resolve().parents[2]
FILES = {'/': (ROOT / 'tooling/browser_qa/replay_probe.html', 'text/html'),
         '/interview_replay.js': (ROOT / 'web/interview_replay.js', 'text/javascript')}
done = Event()
received = {}
result = []


class Probe(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in FILES:
            return self.send_error(404)
        path, content_type = FILES[self.path]
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.end_headers()
        self.wfile.write(path.read_bytes())

    def do_PUT(self):
        length = int(self.headers.get('Content-Length', 0))
        if self.path != '/chunk' or not 0 < length <= 2 * 1024 * 1024:
            return self.send_error(400)
        body = self.rfile.read(length)
        nonce = self.headers['X-Nonce']
        elapsed = int(self.headers['X-Elapsed'])
        sequence = int(self.headers['X-Sequence'])
        accepted = received.setdefault(nonce, [])
        if (hashlib.sha256(body).hexdigest() != self.headers['X-Sha256']
                or sequence != len(accepted) or (accepted and elapsed < accepted[-1])):
            return self.send_error(400)
        if self.headers['X-Interrupted'] == 'yes' and sequence == 1:
            return self.send_error(503)
        accepted.append(elapsed)
        self.send_response(204)
        self.end_headers()

    def do_POST(self):
        if self.path != '/result':
            return self.send_error(404)
        result.append(self.rfile.read(min(int(self.headers['Content-Length']), 40)).decode())
        self.send_response(204)
        self.end_headers()
        done.set()

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    browser = os.getenv('QA_BROWSER', r'C:\Program Files\Google\Chrome\Application\chrome.exe')
    with ThreadingHTTPServer(('127.0.0.1', 0), Probe) as server, tempfile.TemporaryDirectory(
            ignore_cleanup_errors=True) as profile:
        Thread(target=server.serve_forever, daemon=True).start()
        process = subprocess.Popen([browser, '--headless=new', '--no-first-run',
                                    '--disable-background-timer-throttling',
                                    '--disable-background-networking', '--user-data-dir=' + profile,
                                    f'http://127.0.0.1:{server.server_port}/'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            if not done.wait(35) or result[0] not in ('passed video/webm', 'passed video/mp4'):
                raise SystemExit('Replay browser probe failed.')
            if len(received) != 2 or sorted(map(len, received.values()))[0] != 1:
                raise SystemExit('Unexpected replay upload manifest.')
            print(f'{Path(browser).name}: {result[0]}, ordered chunks, final flush, interrupted prefix.')
        finally:
            process.terminate()
            process.wait(timeout=8)
            server.shutdown()
