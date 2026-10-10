"""Headless check of Trash Slot (script inventories stand in for the player)."""
import json, shutil, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(ROOT))
from factorio_paths import PATHS  # noqa: E402
from factorio_paths import run_dir  # noqa: E402
RUN = run_dir(Path(__file__).resolve().parent / "run")
MODS = RUN / "ts-mods"
if MODS.exists():
    shutil.rmtree(MODS)
MODS.mkdir(parents=True)
shutil.copytree(HERE.parent, MODS / "trash-slot", ignore=shutil.ignore_patterns("test"))
shutil.copytree(HERE / "ts-test", MODS / "ts-test")
names = ["base", "elevated-rails", "quality", "space-age", "trash-slot", "ts-test"]
(MODS / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in names]}))
out = RUN / "script-output" / "ts-test.txt"
out.unlink(missing_ok=True)
save = RUN / "ts-test.zip"
save.unlink(missing_ok=True)
common = [str(PATHS["factorio_exe"]), "--config", str(RUN / "config.ini"), "--mod-directory", str(MODS)]
for args in (["--create", str(save)], ["--benchmark", str(save), "--benchmark-ticks", "10", "--disable-audio"]):
    p = subprocess.run(common + args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if p.returncode or "non-recoverable" in p.stdout:
        print(p.stdout[-2500:]); sys.exit(1)
print(out.read_text() if out.exists() else "no result")
