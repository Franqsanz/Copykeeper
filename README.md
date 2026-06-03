# CopyKeeper

*Language: **English** · [Español](./README.es.md)*

A configurable **Windows CLI for incremental folder backups**, with an arrow-key menu to pick what gets copied or ignored.

CopyKeeper mirrors a source folder into a destination (e.g. a local drive or your OneDrive folder), skipping files that haven't changed. You manage everything — source, destination, ignore lists, and extra paths — from a simple interactive menu. No need to edit code.

---

## Features

- **Interactive menu** navigated entirely with the **arrow keys** (`↑ ↓` + `Enter`, `Esc` to go back).
- **Visual picker**: see the real contents of your source folder split into two live lists — **what gets copied** and **what gets ignored** — and toggle items with `Enter`.
- **Incremental copy**: files with the same size and modification date are skipped, so re-runs are fast.
- **Extras**: include folders or files located *outside* the main source folder.
- **Activity log** with a summary (copied / ignored / errors / total time).
- **Config lives outside the code** in a JSON file, so your settings survive updates and reinstalls.
- **Installer** that adds a `copykeeper` command to your PATH — run it from any terminal.
- **No administrator privileges required.**

---

## Requirements

- Windows with **PowerShell 5.1+** (included in Windows 10/11) or PowerShell 7+.
- That's it — no other dependencies.

---

## Installation

1. Download or clone this repository.
2. Double-click **`install.bat`**.

The installer will:

- Copy the program to `%LOCALAPPDATA%\Programs\CopyKeeper`.
- Create the `copykeeper` launcher and add it to your **user PATH**.
- Create the config folder at `%APPDATA%\CopyKeeper` (seeded from `backup-config.example.json`).

Then open a **new** terminal (CMD or PowerShell) and run:

```sh
copykeeper
```

> The PATH change only applies to **new** terminals, so close any open ones first.

### Run without installing

You can also just double-click **`backup.bat`** to open the menu without installing anything.

---

## Usage

When you launch CopyKeeper you get the main menu:

```
============================================================
                    CopyKeeper - Projects
============================================================
 Origen : C:\Users\YourUser\Projects
 Destino: C:\Users\YourUser\OneDrive\Projects-backup
 Registro (log): ACTIVADO
 Carpetas ignoradas: 5    Archivos ignorados: 2    Extras: 0
------------------------------------------------------------
    Elegir QUE SE COPIA del origen  (ver y marcar)
    Ver configuracion completa
    Cambiar carpeta de ORIGEN
    Cambiar carpeta de DESTINO
    Carpetas a ignorar  (agregar / quitar a mano)
    Archivos a ignorar  (agregar / quitar a mano)
    Carpetas/archivos EXTRA a incluir  (agregar / quitar)
    Activar / desactivar registro (log)
  > >> EJECUTAR COPIA AHORA <<
    Salir
  (flechas para moverte - ENTER elige - ESC sale)
```

The title shows `CopyKeeper - <source folder name>`, updating automatically when you change the source.

### The visual picker (option 1)

This is the easiest way to choose what to back up. It lists the **actual** items in your source folder, split into two sections:

```
 SE COPIAN  (13):        <- will be copied (green)
  > [CARPETA]  app-frontend
    [CARPETA]  app-backend
    ...
 SE IGNORAN  (11):       <- will be skipped (gray)
    [CARPETA]  node_modules
    ...
```

- `↑ ↓` to move through both lists.
- `Enter` moves the selected item to the **other** list (copy ⇄ ignore).
- `Esc` saves and returns.

### Extras

Use **"Carpetas/archivos EXTRA a incluir"** to add full paths to folders or files that live *outside* the source folder. On each run:

- A **folder** is copied into the destination under its own name.
- A **file** is copied to the root of the destination.
- A missing path is reported and skipped.

### Running a backup

Choose **`>> EJECUTAR COPIA AHORA <<`** (highlighted in green). After a confirmation, CopyKeeper copies the source (minus ignored items) and then any extras, printing a summary at the end.

---

## Configuration

Settings are stored in:

```
%APPDATA%\CopyKeeper\backup-config.json
```

You normally never edit this by hand — the menu does it for you — but here is the shape:

| Key | Description |
|-----|-------------|
| `origen` | Source folder to back up. |
| `destino` | Destination folder. |
| `crearRegistro` | `true` to write a log file. |
| `archivoLog` | Path of the log file. |
| `carpetasAIgnorar` | Folder names to skip (matched anywhere in the tree). |
| `archivosAIgnorar` | File names to skip (supports `*` and `?` wildcards). |
| `extras` | Full paths (folders/files) to include in addition to the source. |

See [`backup-config.example.json`](./backup-config.example.json) for a starting point.

---

## How it works

- **`backup.ps1`** — the interactive CLI (menu, pickers, config management).
- **`copyFolders.ps1`** — the copy engine. It walks the source recursively, applies the ignore lists, and copies only files that are new or changed (same size **and** last-write-time = skipped).

The CLI simply calls the engine with the values from your config. Extras are handled by calling the same engine once per extra path.

---

## Uninstall

Double-click **`uninstall.bat`**. It will:

1. Remove CopyKeeper from your PATH.
2. Delete the program folder.
3. Ask whether to also delete your configuration (`%APPDATA%\CopyKeeper`).

---

## Project structure

```
CopyKeeper/
├── backup.ps1                   # Interactive CLI
├── backup.bat                   # Launch the menu without installing
├── copyFolders.ps1              # Copy engine (incremental)
├── install.bat / install.ps1    # Installer (adds the 'copykeeper' command)
├── uninstall.bat / uninstall.ps1
├── backup-config.example.json   # Example config (yours stays local & git-ignored)
└── README.md
```

---

## Notes

- The menu uses `[Console]::ReadKey()` for arrow-key navigation, so always launch it through a real console window (`backup.bat`, `install.bat`, or the `copykeeper` command).
- Your personal `backup-config.json` and logs are excluded via `.gitignore` and never committed.

---

## License

MIT — feel free to use and adapt.
