"""Dragging the trash slot in a real client through the fse launcher (fse/dist), with a mocked mouse.
Screenshots land in test/run/script-output/ts-drag-*.png. The game window closes itself when done."""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOD = HERE.parent
ROOT = MOD.parent
sys.path.insert(0, str(ROOT))
from factorio_paths import PATHS  # noqa: E402

from factorio_paths import run_dir, watch_game  # noqa: E402
RUN = run_dir(Path(__file__).resolve().parent / "run")
MODS = RUN / "ts-mods-drag"
OUT = RUN / "script-output"

MODS.mkdir(parents=True, exist_ok=True)
for name in ("wx-trash-slot", "trash-slot", "ts-dragtest", "fse-std"):  # (trash-slot: the name before 0.3.4)
    if (MODS / name).exists():
        shutil.rmtree(MODS / name)
shutil.copytree(MOD, MODS / "wx-trash-slot", ignore=shutil.ignore_patterns("test", ".git"))
shutil.copytree(HERE / "ts-dragtest", MODS / "ts-dragtest")
shutil.copytree(ROOT.parent / "fse" / "mods" / "fse-std", MODS / "fse-std")
names = ["base", "elevated-rails", "quality", "space-age", "fse-std", "wx-trash-slot", "ts-dragtest"]
(MODS / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in names]}))

for f in OUT.glob("ts-drag*"):
    f.unlink()
save = RUN / "ts-drag.zip"
save.unlink(missing_ok=True)
common = [str(PATHS["factorio_exe"]), "--config", str(RUN / "config.ini"), "--mod-directory", str(MODS)]
subprocess.run(common + ["--create", str(save)], capture_output=True, check=True)

# (through the launcher, so fse is in the game)
env = {k: v for k, v in os.environ.items() if k != "FSE_OFF"}
launcher = Path(os.environ.get("FSE_DIR", ROOT.parent / "fse" / "dist")) / "fse-launcher.exe"
game = watch_game([str(launcher)] + common[1:] + ["--load-game", str(save.resolve())], env=env)
start = time.time()
while time.time() - start < 150 and not (OUT / "ts-drag-done.txt").exists() and game.poll() is None:
    time.sleep(1)
time.sleep(3)
game.kill()
log = (RUN / "factorio-current.log").read_text(encoding="utf-8", errors="replace").splitlines()
errors = [l for l in log if "Error" in l or "non-recoverable" in l]
print("screenshots:", sorted(f.name for f in OUT.glob("ts-drag-*.png")))
print((OUT / "ts-drag.txt").read_text() if (OUT / "ts-drag.txt").exists() else "no result")
print("errors:", "\n".join(errors[-10:]) or "none")
