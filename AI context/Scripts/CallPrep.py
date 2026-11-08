"""Call recording -> transcript + screen keyframes + OCR, for "Make summary" (PBIP_Recipes.md).

Run:  py -3.12 CallPrep.py "<Calls\\yyyy-mm-dd hh-mm-ss.mkv>" [en|ru|he]   (default en)
      long calls: start with pythonw so it survives the session (whisper ~1 min per 4 min of audio on CPU)
Out:  Calls\\transcripts\\<video>.txt / .srt / .log (DONE / ERROR at the end)
      Calls\\<yyyy-mm-dd>\\prep\\kf\\*.png (shared-screen keyframes), ocr.md, transcript.md (30 s blocks)

Change log
- 2026-10-29: created (whisper via C:\\DAX\\Yury\\transcribe.py, keyframes / OCR via prep.py).
"""
import os
import subprocess
import sys

os.environ["FOR_DISABLE_CONSOLE_CTRL_HANDLER"] = "1"
sys.path.insert(0, r"C:\DAX\Yury")
sys.path.insert(0, r"C:\DAX\Yury\Скрипты_конспектов")
import prep
import transcribe

video = os.path.abspath(sys.argv[1])
language = sys.argv[2] if len(sys.argv) > 2 else "en"
calls = os.path.dirname(video)
name = os.path.splitext(os.path.basename(video))[0]
srt = os.path.join(calls, "transcripts", name + ".srt")
out = os.path.join(calls, name[:10], "prep")
os.makedirs(out, exist_ok=True)

transcribe.main(video, language)
prep.transcript(srt, os.path.join(out, "transcript.md"))

kf_dir, ocr_dir = os.path.join(out, "kf"), os.path.join(out, "_ocr")
saved = prep.keyframes(video, kf_dir, ocr_dir)
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                os.path.join(prep.HERE, "ocr.ps1"), "-Dir", ocr_dir], check=True)
prep.build_ocr_md(saved, ocr_dir, os.path.join(out, "ocr.md"))
for f in os.listdir(ocr_dir):
    if f.endswith(".png"):
        os.remove(os.path.join(ocr_dir, f))
print(f"{len(saved)} keyframes, transcript -> {out}")
