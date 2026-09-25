#!/usr/bin/env python3
"""Stamps a web build with its version so phones never run a stale copy.

GitHub Pages lets browsers reuse files for 10 minutes, and the game files
keep the same names every build. This script:
  - asks for index.js and index.pck with ?v=<version>, so a new build is a
    new address the browser has never cached;
  - writes version.txt next to index.html;
  - adds a check to the page: on open it reads version.txt (skipping the
    cache) and, if a newer build is out, reloads once onto it.

Usage: stamp_build.py <folder with index.html> <version>
"""
import json
import pathlib
import sys

folder = pathlib.Path(sys.argv[1])
version = sys.argv[2]
page = folder / "index.html"
html = page.read_text()

html = html.replace('<script src="index.js">', '<script src="index.js?v=%s">' % version, 1)
config = '"executable":"index",'
assert config in html, "Godot config not found in index.html"
html = html.replace(config, config + '"mainPack":"index.pck?v=%s",' % version, 1)

check = """<script>/* Newer build check (tools/stamp_build.py). */(function(){var mine=%s;
fetch('version.txt?t='+Date.now(),{cache:'no-store'}).then(function(r){return r.ok?r.text():'';}).then(function(t){
t=t.trim();if(!t||t===mine)return;var tried='mushroom_moon_reloaded_for';
try{if(sessionStorage.getItem(tried)===t)return;sessionStorage.setItem(tried,t);}catch(e){return;}
var q=new URLSearchParams(location.search);q.set('v',t);location.replace(location.pathname+'?'+q.toString());
}).catch(function(){});})();</script>""" % json.dumps(version)
assert "<head>" in html
html = html.replace("<head>", "<head>" + check, 1)
page.write_text(html)
(folder / "version.txt").write_text(version + "\n")
print("Stamped %s as version %s." % (folder, version))
