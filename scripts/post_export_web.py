#!/usr/bin/env python3
"""Post-process Godot web export for cache-safe deploys.

Heavy files (wasm/pck/js) get a build id in the filename so browsers keep
them cached until you ship a new version. index.html and version.json stay
small and always point at the latest build id.

Usage (CI): BUILD_ID=$GITHUB_SHA SIM_VERSION=6 python3 scripts/post_export_web.py
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path


def main() -> int:
	web = Path(os.environ.get("WEB_DIR", "build/web"))
	if not web.is_dir():
		print(f"error: web dir not found: {web}", file=sys.stderr)
		return 1

	build = os.environ.get("BUILD_ID") or os.environ.get("GITHUB_SHA") or "dev"
	build = build.strip()[:12]
	sim_version = int(os.environ.get("SIM_VERSION", "11"))
	prefix = f"index.{build}"

	# Versioned copies of the large artifacts (cached long-term by URL).
	for ext in (".wasm", ".pck", ".js"):
		src = web / f"index{ext}"
		if not src.is_file():
			print(f"warning: missing {src}")
			continue
		dst = web / f"{prefix}{ext}"
		shutil.copy2(src, dst)
		src.unlink()

	# Godot 4 web audio loads worklets next to the versioned main JS (index.{build}.audio*.js).
	for suffix in (".audio.worklet.js", ".audio.position.worklet.js"):
		src = web / f"index{suffix}"
		if not src.is_file():
			print(f"warning: missing {src}")
			continue
		dst = web / f"{prefix}{suffix}"
		shutil.copy2(src, dst)
		src.unlink()

	html_path = web / "index.html"
	if not html_path.is_file():
		print(f"error: missing {html_path}", file=sys.stderr)
		return 1

	html = html_path.read_text(encoding="utf-8")

	html = html.replace('src="index.js"', f'src="{prefix}.js"')
	html = re.sub(r'"executable"\s*:\s*"index"', f'"executable":"{prefix}"', html)
	html = re.sub(r'"index\.pck"', f'"{prefix}.pck"', html)
	html = re.sub(r'"index\.wasm"', f'"{prefix}.wasm"', html)
	html = html.replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')

	meta = (
		f'<meta name="runner-build" content="{build}">\n'
		f'\t\t<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n'
	)
	if 'name="runner-build"' not in html:
		html = html.replace("<head>", f"<head>\n\t\t{meta}", 1)

	html = html.replace(
		"width=device-width, user-scalable=no, initial-scale=1.0",
		"width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, viewport-fit=cover",
	)

	mobile_css = """
\t\t<style id="runner-mobile-fix">
html, body {
\twidth: 100%;
\theight: 100%;
\tposition: fixed;
\toverflow: hidden;
\t-webkit-touch-callout: none;
}
#canvas {
\tposition: fixed;
\tleft: 0;
\ttop: 0;
\twidth: 100%;
\theight: 100%;
\ttouch-action: none;
}
#status {
\tpointer-events: none;
}
#status-notice {
\tpointer-events: auto;
}
\t\t</style>
"""
	if "runner-mobile-fix" not in html:
		html = html.replace("</head>", f"{mobile_css}\t</head>", 1)

	if "setStatusMode('hidden');" in html and "canvas.focus" not in html.split("setStatusMode('hidden')")[1][:120]:
		html = html.replace(
			"setStatusMode('hidden');",
			"setStatusMode('hidden');\n\t\t\tvar __c=document.getElementById('canvas');"
			"if(__c){try{__c.focus({preventScroll:true});}catch(e){try{__c.focus();}catch(e2){}}}",
		)

	apple_boot = """
\t\t<script>
(function () {
\tvar ua = navigator.userAgent || '';
\twindow.__runnerAppleWeb = /iPhone|iPad|iPod/.test(ua)
\t\t|| (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
})();
\t\t</script>
"""
	if "__runnerAppleWeb" not in html:
		html = html.replace("<head>", f"<head>{apple_boot}", 1)

	audio_unlock = """
\t\t<script id="runner-audio-unlock">
document.addEventListener('pointerdown', function () {
\ttry {
\t\tvar ctx = (window.Godot && Godot.audioCtx) || window.__godot_audio_ctx;
\t\tif (ctx && ctx.state === 'suspended') ctx.resume();
\t} catch (e) {}
}, { once: true, capture: true });
\t\t</script>
"""
	if "runner-audio-unlock" not in html:
		html = html.replace("</head>", f"{audio_unlock}\t</head>", 1)

	ios_webgl = """
\t\t<script>
(function () {
\tvar canvas = document.getElementById('canvas');
\tif (!canvas) return;
\tcanvas.addEventListener('webglcontextlost', function (e) {
\t\te.preventDefault();
\t\tvar notice = document.getElementById('status-notice');
\t\tvar overlay = document.getElementById('status');
\t\tif (notice) notice.textContent = 'Graphics reset — reloading…';
\t\tif (overlay) { overlay.style.visibility = 'visible'; }
\t\tsetTimeout(function () { location.reload(); }, 600);
\t}, false);
})();
\t\t</script>
"""
	if "webglcontextlost" not in html:
		html = html.replace("</head>", f"{ios_webgl}\t</head>", 1)

	check_script = f"""
\t\t<script>
(function () {{
\tvar pageBuild = document.querySelector('meta[name="runner-build"]')?.content;
\tif (!pageBuild) return;
\tfetch('version.json?_=' + Date.now(), {{ cache: 'no-store' }})
\t\t.then(function (r) {{ return r.json(); }})
\t\t.then(function (v) {{
\t\t\tif (v.build && v.build !== pageBuild) {{
\t\t\t\tvar key = 'runner_html_reload_' + v.build;
\t\t\t\tif (!sessionStorage.getItem(key)) {{
\t\t\t\t\tsessionStorage.setItem(key, '1');
\t\t\t\t\tlocation.replace(location.pathname + '?b=' + v.build);
\t\t\t\t}}
\t\t\t}}
\t\t}})
\t\t.catch(function () {{}});
}})();
\t\t</script>
"""
	if "runner_html_reload_" not in html:
		html = html.replace("<body>", f"<body>{check_script}", 1)

	html_path.write_text(html, encoding="utf-8")

	(web / ".nojekyll").write_text("", encoding="utf-8")

	cname_src = Path(os.environ.get("REPO_ROOT", web.parent.parent)) / "CNAME"
	if cname_src.is_file():
		shutil.copy2(cname_src, web / "CNAME")
		print(f"post_export_web: copied {cname_src.name}")

	(web / "version.json").write_text(
		json.dumps({"build": build, "sim_version": sim_version}, indent=2) + "\n",
		encoding="utf-8",
	)

	print(f"post_export_web: build={build} sim_version={sim_version}")
	for ext in (".wasm", ".pck", ".js", ".audio.worklet.js", ".audio.position.worklet.js"):
		p = web / f"{prefix}{ext}"
		if not p.is_file():
			print(f"error: missing required artifact {p.name}", file=sys.stderr)
			return 1
		print(f"  {p.name} ({p.stat().st_size // 1024} KiB)")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
