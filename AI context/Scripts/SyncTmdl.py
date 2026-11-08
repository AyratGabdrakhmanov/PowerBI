"""Write a serialized TMDL folder (live model via TmdlSerializer.SerializeDatabaseToFolder, or an offline-TOM result)
into the PBIP definition folder: copy changed / new files, move files of
deleted tables to the backup folder, keep database.tmdl (Desktop writes it without the workspace id).
python -I -X utf8 SyncTmdl.py <serialized folder> <X.SemanticModel\definition> <backup folder> [extra paths to skip, e.g. cultures\en-US.tmdl]
Refuses an incomplete source (no model.tmdl / relationships.tmdl / tables). SCRIPT_VERSION: 2026-10-26.1"""
import filecmp, os, shutil, sys

src, dst, bak = sys.argv[1:4]
SKIP = {'database.tmdl'} | set(sys.argv[4:])
for need in ('model.tmdl', 'relationships.tmdl', 'tables'):
    if not os.path.exists(os.path.join(src, need)):
        sys.exit('source is not a complete TMDL folder (no %s): %s - nothing changed' % (need, src))
os.makedirs(bak, exist_ok=True)
changed, removed = [], []
for root, _, files in os.walk(src):
    for fn in files:
        rel = os.path.relpath(os.path.join(root, fn), src)
        if rel in SKIP:
            continue
        d = os.path.join(dst, rel)
        if not os.path.exists(d) or not filecmp.cmp(os.path.join(src, rel), d, shallow=False):
            if os.path.exists(d):
                os.makedirs(os.path.dirname(os.path.join(bak, rel)), exist_ok=True); shutil.copy2(d, os.path.join(bak, rel))
            os.makedirs(os.path.dirname(d), exist_ok=True); shutil.copy2(os.path.join(src, rel), d); changed.append(rel)
for root, _, files in os.walk(dst):
    for fn in files:
        rel = os.path.relpath(os.path.join(root, fn), dst)
        if rel not in SKIP and not os.path.exists(os.path.join(src, rel)):
            os.makedirs(os.path.dirname(os.path.join(bak, rel)), exist_ok=True); shutil.move(os.path.join(dst, rel), os.path.join(bak, rel)); removed.append(rel)
print('changed:', ', '.join(changed) or '-'); print('removed:', ', '.join(removed) or '-')
