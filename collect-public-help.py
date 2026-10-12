#!/usr/bin/env python3
"""Admin preparation only: fetch a small allowlist of public VikingTools pages."""
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
import urllib.request

PAGES = ['/', '/restaurant-menu', '/food-menu-generator', '/editable-qr-code', '/flipbook-maker']

class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.parts = []
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style', 'nav', 'footer', 'noscript'):
            self.skip += 1
        if not self.skip and tag in ('p', 'h1', 'h2', 'h3', 'li', 'section', 'div'):
            self.parts.append('\n')
    def handle_endtag(self, tag):
        if tag in ('script', 'style', 'nav', 'footer', 'noscript') and self.skip:
            self.skip -= 1
    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)

out = Path(__file__).resolve().parent / 'public-help-review'
out.mkdir(exist_ok=True)
for page in PAGES:
    url = 'https://vikingtools.no' + page
    req = urllib.request.Request(url, headers={'User-Agent': 'VikingTools admin help snapshot'})
    with urllib.request.urlopen(req, timeout=20) as response:
        if response.url.rstrip('/') != url.rstrip('/'):
            raise ValueError('Unexpected redirect; review manually')
        raw = response.read(1_000_001)
    if len(raw) > 1_000_000:
        raise ValueError('Page too large')
    parser = Text()
    parser.feed(raw.decode('utf-8'))
    lines = [' '.join(s.split()) for s in ''.join(parser.parts).splitlines()]
    text = '\n\n'.join(s for s in lines if s)
    name = (page.strip('/') or 'homepage') + '.txt'
    (out / name).write_text(f'Public source: {url}\nRetrieved: {datetime.now(timezone.utc).isoformat()}\n\n{text[:25000]}\n')
    print(f'Prepared for admin review: {name}')
print('Review these files. Install approved files with: sudo vt-import-help FILE.txt')
