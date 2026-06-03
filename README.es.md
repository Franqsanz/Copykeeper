# CopyKeeper

*Idioma: [English](./README.md) · **Español***

Un **CLI para Windows que hace copias de respaldo incrementales** de carpetas, con un menú navegable por flechas para elegir qué se copia y qué se ignora.

CopyKeeper hace un "espejo" de una carpeta de origen hacia un destino (por ejemplo otra unidad o tu carpeta de OneDrive), salteando los archivos que no cambiaron. Manejás todo —origen, destino, listas de ignorados y rutas extra— desde un menú interactivo. No hace falta tocar código.

---

## Características

- **Menú interactivo** navegable con las **flechas** (`↑ ↓` + `Enter`, `Esc` para volver).
- **Selector visual**: ves el contenido real de tu carpeta de origen separado en dos listas vivas — **lo que se copia** y **lo que se ignora** — y movés ítems entre ellas con `Enter`.
- **Copia incremental**: los archivos con el mismo tamaño y fecha de modificación se saltean, así las copias siguientes son rápidas.
- **Extras**: incluí carpetas o archivos que estén *fuera* de la carpeta de origen.
- **Registro (log)** con un resumen (copiados / ignorados / errores / tiempo total).
- **La config vive fuera del código** en un archivo JSON, así tus ajustes sobreviven actualizaciones y reinstalaciones.
- **Instalador** que agrega el comando `copykeeper` al PATH — lo abrís desde cualquier terminal.
- **No requiere permisos de administrador.**

---

## Requisitos

- Windows con **PowerShell 5.1+** (viene en Windows 10/11) o PowerShell 7+.
- Nada más — sin otras dependencias.

---

## Instalación

1. Descargá o cloná este repositorio.
2. Doble clic en **`install.bat`**.

El instalador va a:

- Copiar el programa a `%LOCALAPPDATA%\Programs\CopyKeeper`.
- Crear el lanzador `copykeeper` y agregarlo a tu **PATH de usuario**.
- Crear la carpeta de config en `%APPDATA%\CopyKeeper` (a partir de `backup-config.example.json`).

Después abrí una terminal **nueva** (CMD o PowerShell) y ejecutá:

```sh
copykeeper
```

> El cambio en el PATH solo aplica a terminales **nuevas**, así que cerrá las que tengas abiertas.

### Usarlo sin instalar

También podés hacer doble clic en **`backup.bat`** para abrir el menú sin instalar nada.

---

## Uso

Al abrir CopyKeeper ves el menú principal:

```
============================================================
                    CopyKeeper - Projects
============================================================
 Origen : C:\Users\TuUsuario\Projects
 Destino: C:\Users\TuUsuario\OneDrive\Projects-backup
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

El título muestra `CopyKeeper - <nombre de la carpeta de origen>` y se actualiza solo cuando cambiás el origen.

### El selector visual (opción 1)

Es la forma más fácil de elegir qué respaldar. Lista los ítems **reales** de tu carpeta de origen, separados en dos secciones:

```
 SE COPIAN  (13):        <- se van a copiar (verde)
  > [CARPETA]  app-frontend
    [CARPETA]  app-backend
    ...
 SE IGNORAN  (11):       <- se saltean (gris)
    [CARPETA]  node_modules
    ...
```

- `↑ ↓` para moverte por las dos listas.
- `Enter` mueve el ítem seleccionado a la **otra** lista (copiar ⇄ ignorar).
- `Esc` guarda y vuelve.

### Extras

Usá **"Carpetas/archivos EXTRA a incluir"** para agregar rutas completas de carpetas o archivos que estén *fuera* del origen. En cada copia:

- Una **carpeta** se copia dentro del destino con su propio nombre.
- Un **archivo** se copia a la raíz del destino.
- Si una ruta no existe, se avisa y se saltea.

### Ejecutar una copia

Elegí **`>> EJECUTAR COPIA AHORA <<`** (resaltado en verde). Tras una confirmación, CopyKeeper copia el origen (menos lo ignorado) y luego los extras, mostrando un resumen al final.

---

## Configuración

Los ajustes se guardan en:

```
%APPDATA%\CopyKeeper\backup-config.json
```

Normalmente nunca lo editás a mano —lo hace el menú por vos— pero esta es su estructura:

| Clave | Descripción |
|-------|-------------|
| `origen` | Carpeta de origen a respaldar. |
| `destino` | Carpeta de destino. |
| `crearRegistro` | `true` para escribir un archivo de log. |
| `archivoLog` | Ruta del archivo de log. |
| `carpetasAIgnorar` | Nombres de carpetas a saltear (en cualquier nivel del árbol). |
| `archivosAIgnorar` | Nombres de archivos a saltear (admite comodines `*` y `?`). |
| `extras` | Rutas completas (carpetas/archivos) a incluir además del origen. |

Mirá [`backup-config.example.json`](./backup-config.example.json) como punto de partida.

---

## Cómo funciona

- **`backup.ps1`** — el CLI interactivo (menú, selectores, manejo de la config).
- **`copyFolders.ps1`** — el motor de copia. Recorre el origen recursivamente, aplica las listas de ignorados y copia solo los archivos nuevos o modificados (mismo tamaño **y** misma fecha de modificación = se saltea).

El CLI simplemente llama al motor con los valores de tu config. Los extras se procesan llamando al mismo motor una vez por cada ruta extra.

---

## Desinstalar

Doble clic en **`uninstall.bat`**. Va a:

1. Quitar CopyKeeper del PATH.
2. Borrar la carpeta del programa.
3. Preguntarte si también querés borrar tu configuración (`%APPDATA%\CopyKeeper`).

---

## Estructura del proyecto

```
CopyKeeper/
├── backup.ps1                   # CLI interactivo
├── backup.bat                   # Abre el menú sin instalar
├── copyFolders.ps1              # Motor de copia (incremental)
├── install.bat / install.ps1    # Instalador (agrega el comando 'copykeeper')
├── uninstall.bat / uninstall.ps1
├── backup-config.example.json   # Config de ejemplo (la tuya queda local y git-ignored)
└── README.md
```

---

## Notas

- El menú usa `[Console]::ReadKey()` para la navegación con flechas, así que abrilo siempre desde una consola real (`backup.bat`, `install.bat` o el comando `copykeeper`).
- Tu `backup-config.json` personal y los logs están excluidos por `.gitignore` y nunca se suben.

---

## Licencia

MIT — usalo y adaptalo libremente.
