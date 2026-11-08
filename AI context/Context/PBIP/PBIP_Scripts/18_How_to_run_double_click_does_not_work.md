Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## How to run (double-click does not work!)
Double-clicking a `.ps1` does not run the script (or the window closes instantly,
without letting you see the result/error). Run it from `cmd` or PowerShell:

```cmd
cd "path\to\project"
powershell -ExecutionPolicy Bypass -File "RenameObjects.ps1"
```

`-ExecutionPolicy Bypass` bypasses the default ban on running
unverified scripts (Windows blocks `.ps1` from the internet/by default).
