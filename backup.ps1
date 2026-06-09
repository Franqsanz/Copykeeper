# ============================================================
#  BACKUP CLI  -  Gestor interactivo de copias (GoodApps)
#  Navegacion con flechas (UP/DOWN) + ENTER.  ESC = volver/salir.
#  La config vive en: backup-config.json
#  El motor de copia es: copyFolders.ps1
#
#  Uso normal:  abre el menu interactivo.
#  Uso con -Run: ejecuta la copia sin menu (lo usa la tarea programada).
# ============================================================

param(
    [switch]$Run   # ejecuta la copia en modo silencioso (sin menu) y sale
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Script:AppNombre  = 'CopyKeeper'   # nombre de la app (cambialo aca si queres otro)
$Script:Raiz       = $PSScriptRoot
$Script:MotorPath  = Join-Path $Script:Raiz 'copyFolders.ps1'

# La config vive en la carpeta de datos del usuario (sobrevive reinstalaciones)
$Script:DataDir    = Join-Path $env:APPDATA $Script:AppNombre
$Script:ConfigPath = Join-Path $Script:DataDir 'backup-config.json'

# ---- Config por defecto (si no existe el JSON, se crea con esto) ----
function Get-ConfigPorDefecto {
    return [ordered]@{
        origen           = (Join-Path $env:USERPROFILE 'Documents')
        destino          = (Join-Path $env:USERPROFILE 'OneDrive\Backup')
        crearRegistro    = $true
        archivoLog       = (Join-Path $env:USERPROFILE 'Desktop\CopyKeeper_log.txt')
        carpetasAIgnorar = @('node_modules', '.git', 'dist', 'bin', 'obj')
        archivosAIgnorar = @('package-lock.json', 'pnpm-lock.yaml')
        extras           = @()
    }
}

# ---- Carga / guardado de configuracion ----
function Cargar-Config {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        # Migracion: si hay un backup-config.json junto al script, usarlo como base
        $configLocal = Join-Path $Script:Raiz 'backup-config.json'
        if ((Test-Path -LiteralPath $configLocal) -and
            ((Resolve-Path $configLocal).Path -ne (Join-Path $Script:DataDir 'backup-config.json'))) {
            if (-not (Test-Path -LiteralPath $Script:DataDir -PathType Container)) {
                New-Item -Path $Script:DataDir -ItemType Directory -Force | Out-Null
            }
            Copy-Item -LiteralPath $configLocal -Destination $Script:ConfigPath -Force
        } else {
            $cfg = Get-ConfigPorDefecto
            Guardar-Config $cfg
            return $cfg
        }
    }
    try {
        $raw = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8
        $obj = $raw | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: backup-config.json esta corrupto o mal formado." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
    $cfg = [ordered]@{
        origen           = [string]$obj.origen
        destino          = [string]$obj.destino
        crearRegistro    = [bool]$obj.crearRegistro
        archivoLog       = [string]$obj.archivoLog
        carpetasAIgnorar = @($obj.carpetasAIgnorar | Where-Object { $_ -ne $null })
        archivosAIgnorar = @($obj.archivosAIgnorar | Where-Object { $_ -ne $null })
        extras           = @($obj.extras | Where-Object { $_ -ne $null })
    }
    return $cfg
}

function Guardar-Config {
    param($cfg)
    if (-not (Test-Path -LiteralPath $Script:DataDir -PathType Container)) {
        New-Item -Path $Script:DataDir -ItemType Directory -Force | Out-Null
    }
    $salida = [ordered]@{
        origen           = $cfg.origen
        destino          = $cfg.destino
        crearRegistro    = $cfg.crearRegistro
        archivoLog       = $cfg.archivoLog
        carpetasAIgnorar = [string[]]@($cfg.carpetasAIgnorar)
        archivosAIgnorar = [string[]]@($cfg.archivosAIgnorar)
        extras           = [string[]]@($cfg.extras)
    }
    $json = $salida | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $Script:ConfigPath -Value $json -Encoding UTF8
}

# ============================================================
#  NUCLEO DE NAVEGACION CON FLECHAS
#  Show-Menu: dibuja un menu, devuelve el indice elegido (ENTER)
#             o -1 si se presiona ESC.
# ============================================================
function Centrar {
    param([string]$texto, [int]$ancho = 60)
    if ($texto.Length -ge $ancho) { return $texto }
    $pad = [int](($ancho - $texto.Length) / 2)
    return (' ' * $pad) + $texto
}

# Escribe una linea y rellena hasta el ancho de la consola con espacios
# (con color por defecto) para borrar lo que hubiera escrito antes -> sin parpadeo.
function Write-Linea {
    param([string]$texto, $fore, $back)
    $ancho = 80
    try { $ancho = [Console]::WindowWidth - 1 } catch {}
    if ($ancho -lt 1) { $ancho = 80 }
    if ($texto.Length -gt $ancho) { $texto = $texto.Substring(0, $ancho) }

    $p = @{ Object = $texto; NoNewline = $true }
    if ($fore) { $p.ForegroundColor = $fore }
    if ($back) { $p.BackgroundColor = $back }
    Write-Host @p

    $resto = $ancho - $texto.Length
    if ($resto -gt 0) { Write-Host (' ' * $resto) -NoNewline }
    Write-Host ""   # salto de linea con colores por defecto
}

function Show-Menu {
    param(
        [string]$Titulo,
        [string[]]$Opciones,
        [string[]]$Info = @(),     # lineas informativas arriba del menu
        [int]$Inicial = 0,
        [string]$Ayuda = "(flechas para moverte - ENTER elige - ESC vuelve)",
        [hashtable]$ColorOpcion = @{}   # indice -> color (ej: @{6='Green'})
    )

    $sel = $Inicial
    try { [Console]::CursorVisible = $false } catch {}
    try { Clear-Host } catch {}   # limpieza inicial unica (luego se reescribe encima, sin parpadeo)
    try {
        while ($true) {
            # Reposicionar el cursor arriba en vez de borrar toda la pantalla -> evita el titileo
            try { [Console]::SetCursorPosition(0, 0) } catch {}

            Write-Linea "============================================================" Cyan $null
            Write-Linea (Centrar $Titulo 60) Cyan $null
            Write-Linea "============================================================" Cyan $null
            foreach ($l in $Info) { Write-Linea $l $null $null }
            if ($Info.Count -gt 0) {
                Write-Linea "------------------------------------------------------------" DarkGray $null
            }

            for ($i = 0; $i -lt $Opciones.Count; $i++) {
                if ($i -eq $sel) {
                    Write-Linea ("  > " + $Opciones[$i] + " ") Black Cyan
                } elseif ($ColorOpcion.ContainsKey($i)) {
                    Write-Linea ("    " + $Opciones[$i]) $ColorOpcion[$i] $null
                } else {
                    Write-Linea ("    " + $Opciones[$i]) $null $null
                }
            }
            Write-Linea "" $null $null
            Write-Linea "  $Ayuda" DarkGray $null

            $tecla = [Console]::ReadKey($true)
            switch ($tecla.Key) {
                'UpArrow'   { $sel = ($sel - 1 + $Opciones.Count) % $Opciones.Count }
                'DownArrow' { $sel = ($sel + 1) % $Opciones.Count }
                'Enter'     { return $sel }
                'Escape'    { return -1 }
                'Home'      { $sel = 0 }
                'End'       { $sel = $Opciones.Count - 1 }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
    }
}

function Pausar {
    Write-Host ""
    Write-Host "Presiona una tecla para continuar..." -ForegroundColor DarkGray
    [void][Console]::ReadKey($true)
}

function Confirmar {
    param([string]$Pregunta, [string[]]$Info = @())
    $r = Show-Menu -Titulo $Pregunta -Info $Info -Opciones @("Si, continuar", "No, cancelar") -Inicial 1
    return ($r -eq 0)
}

# ---- Titulo dinamico segun la carpeta de origen ----
function Get-TituloPrincipal {
    param($cfg)
    $nombre = ''
    if (-not [string]::IsNullOrWhiteSpace($cfg.origen)) {
        $nombre = Split-Path -Path $cfg.origen -Leaf
    }
    if ([string]::IsNullOrWhiteSpace($nombre)) {
        return $Script:AppNombre
    }
    return ("{0} - {1}" -f $Script:AppNombre, $nombre)
}

# ---- Lineas de estado para el encabezado del menu principal ----
function Get-InfoEstado {
    param($cfg)
    $estadoLog = if ($cfg.crearRegistro) { "ACTIVADO" } else { "desactivado" }
    return @(
        (" Origen : {0}" -f $cfg.origen),
        (" Destino: {0}" -f $cfg.destino),
        (" Registro (log): {0}" -f $estadoLog),
        (" Carpetas ignoradas: {0}    Archivos ignorados: {1}    Extras: {2}" -f `
            @($cfg.carpetasAIgnorar).Count, @($cfg.archivosAIgnorar).Count, @($cfg.extras).Count)
    )
}

# ---- Submenu para administrar una lista (carpetas o archivos) ----
function Administrar-Lista {
    param(
        [ref]$lista,
        [string]$titulo,
        [string]$ejemplo
    )
    $huboCambios = $false

    do {
        $items = @($lista.Value)
        $info = @()
        if ($items.Count -eq 0) {
            $info += "  (lista vacia)"
        } else {
            for ($i = 0; $i -lt $items.Count; $i++) {
                $info += ("   - {0}" -f $items[$i])
            }
        }

        $op = Show-Menu -Titulo $titulo -Info $info -Opciones @("Agregar nuevo", "Quitar uno", "Volver")
        switch ($op) {
            0 {  # Agregar
                Clear-Host
                Write-Host "==== Agregar a: $titulo ====" -ForegroundColor Cyan
                Write-Host ("Ejemplo: {0}" -f $ejemplo) -ForegroundColor DarkGray
                Write-Host "(dejalo vacio y ENTER para cancelar)" -ForegroundColor DarkGray
                $nuevo = (Read-Host "Nombre a agregar").Trim()
                if ([string]::IsNullOrWhiteSpace($nuevo)) {
                    # cancelado
                } elseif ($items -contains $nuevo) {
                    Write-Host "Ya estaba en la lista." -ForegroundColor Yellow; Pausar
                } else {
                    $lista.Value = @($items) + $nuevo
                    $huboCambios = $true
                    Write-Host ("Agregado: {0}" -f $nuevo) -ForegroundColor Green; Pausar
                }
            }
            1 {  # Quitar (elegir con flechas)
                if ($items.Count -eq 0) {
                    Show-Menu -Titulo $titulo -Info @("  No hay nada para quitar.") -Opciones @("Volver") | Out-Null
                } else {
                    $opcionesQuitar = @($items) + "<< Cancelar"
                    $idx = Show-Menu -Titulo "Quitar de: $titulo" `
                        -Info @("Elegi el elemento a quitar:") -Opciones $opcionesQuitar
                    if ($idx -ge 0 -and $idx -lt $items.Count) {
                        $quitado = $items[$idx]
                        $lista.Value = @($items | Where-Object { $_ -ne $quitado })
                        $huboCambios = $true
                        Write-Host ("Quitado: {0}" -f $quitado) -ForegroundColor Green; Pausar
                    }
                }
            }
            default { return $huboCambios }   # 2 (Volver) o ESC (-1)
        }
    } while ($true)
}

# ---- Selector visual: ver el contenido del ORIGEN y elegir que se copia ----
function Elegir-Contenido {
    param($cfg)

    if (-not (Test-Path -LiteralPath $cfg.origen -PathType Container)) {
        Show-Menu -Titulo "QUE SE COPIA DEL ORIGEN" -Opciones @("Volver") `
            -Info @("ERROR: la carpeta de origen no existe:", ("  " + $cfg.origen)) | Out-Null
        return $false
    }

    try {
        $items = @(Get-ChildItem -LiteralPath $cfg.origen -Force -ErrorAction Stop |
                   Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name)
    } catch {
        Show-Menu -Titulo "QUE SE COPIA DEL ORIGEN" -Opciones @("Volver") `
            -Info @(("ERROR al leer el origen: " + $_.Exception.Message)) | Out-Null
        return $false
    }

    if ($items.Count -eq 0) {
        Show-Menu -Titulo "QUE SE COPIA DEL ORIGEN" -Opciones @("Volver") `
            -Info @("La carpeta de origen esta vacia.") | Out-Null
        return $false
    }

    # Determina si un elemento esta actualmente ignorado
    function _EstaIgnorado {
        param($it, $cfg)
        if ($it.PSIsContainer) { return (@($cfg.carpetasAIgnorar) -contains $it.Name) }
        else                   { return (@($cfg.archivosAIgnorar) -contains $it.Name) }
    }

    $sel = 0
    $cambios = $false
    try { [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            # Separar en dos grupos; el orden visual es: primero los que se copian, luego los ignorados
            $copiados = @($items | Where-Object { -not (_EstaIgnorado $_ $cfg) })
            $ignorados = @($items | Where-Object { _EstaIgnorado $_ $cfg })
            $orden = @($copiados) + @($ignorados)
            if ($sel -ge $orden.Count) { $sel = $orden.Count - 1 }
            if ($sel -lt 0) { $sel = 0 }

            Clear-Host
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host (Centrar "QUE SE COPIA DEL ORIGEN" 60) -ForegroundColor Cyan
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host (" Origen: {0}" -f $cfg.origen)
            Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

            $idx = 0
            $fmt = { param($it) ("{0}  {1}" -f $(if ($it.PSIsContainer) {"[CARPETA]"} else {"[ archivo]"}), $it.Name) }

            Write-Host (" SE COPIAN  ({0}):" -f $copiados.Count) -ForegroundColor Green
            if ($copiados.Count -eq 0) { Write-Host "    (ninguno)" -ForegroundColor DarkGray }
            foreach ($it in $copiados) {
                $linea = (& $fmt $it)
                if ($idx -eq $sel) { Write-Host ("  > " + $linea + " ") -ForegroundColor Black -BackgroundColor Cyan }
                else               { Write-Host ("    " + $linea) -ForegroundColor Green }
                $idx++
            }

            Write-Host ""
            Write-Host (" SE IGNORAN  ({0}):" -f $ignorados.Count) -ForegroundColor Yellow
            if ($ignorados.Count -eq 0) { Write-Host "    (ninguno)" -ForegroundColor DarkGray }
            foreach ($it in $ignorados) {
                $linea = (& $fmt $it)
                if ($idx -eq $sel) { Write-Host ("  > " + $linea + " ") -ForegroundColor Black -BackgroundColor Cyan }
                else               { Write-Host ("    " + $linea) -ForegroundColor DarkGray }
                $idx++
            }

            Write-Host ""
            Write-Host "  (flechas para moverte - ENTER pasa de una lista a la otra - ESC vuelve)" -ForegroundColor DarkGray

            $tecla = [Console]::ReadKey($true)
            switch ($tecla.Key) {
                'UpArrow'   { $sel = ($sel - 1 + $orden.Count) % $orden.Count }
                'DownArrow' { $sel = ($sel + 1) % $orden.Count }
                'Home'      { $sel = 0 }
                'End'       { $sel = $orden.Count - 1 }
                'Escape'    { return $cambios }
                'Enter' {
                    $it = $orden[$sel]
                    if ($it.PSIsContainer) {
                        if (@($cfg.carpetasAIgnorar) -contains $it.Name) {
                            $cfg.carpetasAIgnorar = @($cfg.carpetasAIgnorar | Where-Object { $_ -ne $it.Name })
                        } else {
                            $cfg.carpetasAIgnorar = @($cfg.carpetasAIgnorar) + $it.Name
                        }
                    } else {
                        if (@($cfg.archivosAIgnorar) -contains $it.Name) {
                            $cfg.archivosAIgnorar = @($cfg.archivosAIgnorar | Where-Object { $_ -ne $it.Name })
                        } else {
                            $cfg.archivosAIgnorar = @($cfg.archivosAIgnorar) + $it.Name
                        }
                    }
                    $cambios = $true
                    # Hacer que el cursor "siga" al elemento que acaba de cambiar de lista
                    $nuevoCopiados = @($items | Where-Object { -not (_EstaIgnorado $_ $cfg) })
                    $nuevoIgnorados = @($items | Where-Object { _EstaIgnorado $_ $cfg })
                    $nuevoOrden = @($nuevoCopiados) + @($nuevoIgnorados)
                    for ($k = 0; $k -lt $nuevoOrden.Count; $k++) {
                        if ($nuevoOrden[$k].Name -eq $it.Name -and $nuevoOrden[$k].PSIsContainer -eq $it.PSIsContainer) {
                            $sel = $k; break
                        }
                    }
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
    }
}

# ---- Nucleo de la copia (sin prompts). Devuelve $true si fue OK. ----
function Invoke-Copia {
    param($cfg)

    if (-not (Test-Path -LiteralPath $Script:MotorPath)) {
        Write-Host ("ERROR: no se encontro el motor de copia: {0}" -f $Script:MotorPath) -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path -LiteralPath $cfg.origen -PathType Container)) {
        Write-Host ("ERROR: la carpeta de origen no existe: {0}" -f $cfg.origen) -ForegroundColor Red
        return $false
    }

    $ignorarCarpetas = [string[]]@($cfg.carpetasAIgnorar)
    $ignorarArchivos = [string[]]@($cfg.archivosAIgnorar)

    $params = @{
        CarpetaOrigen    = $cfg.origen
        CarpetaDestino   = $cfg.destino
        CarpetasAIgnorar = $ignorarCarpetas
        ArchivosAIgnorar = $ignorarArchivos
    }
    if ($cfg.crearRegistro) {
        $params.CrearRegistro   = $true
        $params.ArchivoRegistro = $cfg.archivoLog
    }

    Write-Host "----- INICIANDO COPIA (origen principal) -----" -ForegroundColor Cyan
    try {
        & $Script:MotorPath @params

        # ---- Copiar las rutas EXTRA (fuera del origen principal) ----
        $extras = @($cfg.extras)
        if ($extras.Count -gt 0) {
            Write-Host ""
            Write-Host "----- COPIANDO EXTRAS -----" -ForegroundColor Cyan
            foreach ($ex in $extras) {
                if ([string]::IsNullOrWhiteSpace($ex)) { continue }
                $nombre = Split-Path -Path $ex -Leaf
                if (Test-Path -LiteralPath $ex -PathType Container) {
                    # Carpeta extra: se copia dentro del destino con su mismo nombre
                    $destExtra = Join-Path $cfg.destino $nombre
                    Write-Host ("  Carpeta: {0}" -f $ex) -ForegroundColor DarkGray
                    $pExtra = @{
                        CarpetaOrigen    = $ex
                        CarpetaDestino   = $destExtra
                        CarpetasAIgnorar = $ignorarCarpetas
                        ArchivosAIgnorar = $ignorarArchivos
                    }
                    if ($cfg.crearRegistro) {
                        $pExtra.CrearRegistro   = $true
                        $pExtra.ArchivoRegistro = $cfg.archivoLog
                    }
                    & $Script:MotorPath @pExtra
                } elseif (Test-Path -LiteralPath $ex -PathType Leaf) {
                    # Archivo extra: se copia directo a la raiz del destino
                    Write-Host ("  Archivo: {0}" -f $ex) -ForegroundColor DarkGray
                    if (-not (Test-Path -LiteralPath $cfg.destino -PathType Container)) {
                        New-Item -Path $cfg.destino -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $ex -Destination (Join-Path $cfg.destino $nombre) -Force
                } else {
                    Write-Host ("  AVISO: no existe, se omite -> {0}" -f $ex) -ForegroundColor Yellow
                }
            }
        }

        Write-Host ""
        Write-Host "----- COPIA FINALIZADA -----" -ForegroundColor Green
        if ($cfg.crearRegistro) {
            Write-Host ("Registro: {0}" -f $cfg.archivoLog) -ForegroundColor DarkGray
        }
        return $true
    } catch {
        Write-Host ""
        Write-Host ("ERROR durante la copia: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# ---- Ejecutar la copia desde el menu (con validacion y confirmacion) ----
function Ejecutar-Copia {
    param($cfg)

    if (-not (Test-Path -LiteralPath $Script:MotorPath)) {
        Show-Menu -Titulo "EJECUTAR COPIA" -Opciones @("Volver") `
            -Info @("ERROR: no se encontro el motor de copia:", "  $Script:MotorPath") | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $cfg.origen -PathType Container)) {
        Show-Menu -Titulo "EJECUTAR COPIA" -Opciones @("Volver") `
            -Info @(("ERROR: la carpeta de origen no existe:"), ("  " + $cfg.origen)) | Out-Null
        return
    }

    $info = @(
        (" Origen : {0}" -f $cfg.origen),
        (" Destino: {0}" -f $cfg.destino),
        (" Ignorando {0} carpeta(s) y {1} archivo(s)." -f `
            @($cfg.carpetasAIgnorar).Count, @($cfg.archivosAIgnorar).Count),
        (" Extras a incluir: {0}" -f @($cfg.extras).Count)
    )
    if (-not (Confirmar -Pregunta "Confirmar e iniciar la copia?" -Info $info)) {
        return
    }

    Clear-Host
    [void](Invoke-Copia $cfg)
    Pausar
}

# ---- Ver configuracion completa ----
function Ver-Config {
    param($cfg)
    $info = @(
        (" Origen : {0}" -f $cfg.origen),
        (" Destino: {0}" -f $cfg.destino),
        (" Registro: {0}" -f $(if ($cfg.crearRegistro) {"ACTIVADO"} else {"desactivado"})),
        (" Archivo de log: {0}" -f $cfg.archivoLog),
        "",
        " Carpetas a ignorar:"
    )
    if (@($cfg.carpetasAIgnorar).Count -eq 0) { $info += "   (ninguna)" }
    else { @($cfg.carpetasAIgnorar) | ForEach-Object { $info += "   - $_" } }
    $info += ""
    $info += " Archivos a ignorar:"
    if (@($cfg.archivosAIgnorar).Count -eq 0) { $info += "   (ninguno)" }
    else { @($cfg.archivosAIgnorar) | ForEach-Object { $info += "   - $_" } }
    $info += ""
    $info += " Carpetas/archivos EXTRA a incluir:"
    if (@($cfg.extras).Count -eq 0) { $info += "   (ninguno)" }
    else { @($cfg.extras) | ForEach-Object { $info += "   - $_" } }
    $info += ""
    $info += (" Archivo de config: {0}" -f $Script:ConfigPath)

    Show-Menu -Titulo "CONFIGURACION COMPLETA" -Info $info -Opciones @("Volver") | Out-Null
}

function Cambiar-Ruta {
    param([string]$etiqueta, [bool]$validarExiste)
    Clear-Host
    Write-Host "==== Cambiar carpeta de $etiqueta ====" -ForegroundColor Cyan
    Write-Host "(dejalo vacio y ENTER para cancelar)" -ForegroundColor DarkGray
    $nuevo = (Read-Host "Nueva ruta").Trim()
    if ([string]::IsNullOrWhiteSpace($nuevo)) { return $null }
    if ($validarExiste -and -not (Test-Path -LiteralPath $nuevo -PathType Container)) {
        Write-Host "ADVERTENCIA: esa carpeta no existe (se guarda igual)." -ForegroundColor Yellow
        Pausar
    }
    return $nuevo
}

# ============================================================
#  COPIA AUTOMATICA (Programador de tareas de Windows)
# ============================================================
$Script:TareaNombre = 'CopyKeeper Backup'

function Get-TareaCopy {
    try { return Get-ScheduledTask -TaskName $Script:TareaNombre -ErrorAction Stop }
    catch { return $null }
}

function Convertir-Dias {
    param([int]$mascara)
    $mapa = @{ 1='Domingo'; 2='Lunes'; 4='Martes'; 8='Miercoles';
               16='Jueves'; 32='Viernes'; 64='Sabado' }
    $dias = @()
    foreach ($bit in ($mapa.Keys | Sort-Object)) {
        if ($mascara -band $bit) { $dias += $mapa[$bit] }
    }
    if ($dias.Count -eq 0) { return "$mascara" }
    return ($dias -join ', ')
}

function Describir-Tarea {
    param($tarea)
    if (-not $tarea) { return "Estado: NO hay copia automatica programada." }
    try {
        $trg  = @($tarea.Triggers)[0]
        $clase = $trg.CimClass.CimClassName
        $tipo = if ($clase -like '*Daily*')      { "Diaria" }
                elseif ($clase -like '*Weekly*') { "Semanal" }
                else                              { "Programada" }
        $hora = ''
        if ($trg.StartBoundary) { $hora = ([datetime]$trg.StartBoundary).ToString('HH:mm') }
        $extra = ''
        if ($tipo -eq 'Semanal' -and $trg.DaysOfWeek) {
            $extra = (" - {0}" -f (Convertir-Dias $trg.DaysOfWeek))
        }
        return ("Estado: PROGRAMADA ({0} a las {1}){2}" -f $tipo, $hora, $extra)
    } catch {
        return "Estado: PROGRAMADA (no se pudo leer el detalle)."
    }
}

function Pedir-Hora {
    Clear-Host
    Write-Host "==== Horario de la copia ====" -ForegroundColor Cyan
    Write-Host "(formato 24hs HH:mm, ej 22:00 - vacio = cancelar)" -ForegroundColor DarkGray
    $txt = (Read-Host "Hora").Trim()
    if ([string]::IsNullOrWhiteSpace($txt)) { return $null }
    $dt = [datetime]::MinValue
    if ([datetime]::TryParseExact($txt, 'HH:mm', $null, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) {
        return $dt
    }
    Write-Host "Hora invalida. Usa el formato HH:mm (ej 09:30 o 22:00)." -ForegroundColor Red
    Pausar
    return $null
}

function Pedir-Dia {
    $dias = @('Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo')
    $mapa = @{ 'Lunes'='Monday'; 'Martes'='Tuesday'; 'Miercoles'='Wednesday';
               'Jueves'='Thursday'; 'Viernes'='Friday'; 'Sabado'='Saturday'; 'Domingo'='Sunday' }
    $i = Show-Menu -Titulo "DIA DE LA SEMANA" -Info @("Elegi el dia para la copia semanal:") `
        -Opciones (@($dias) + "<< Cancelar")
    if ($i -ge 0 -and $i -lt $dias.Count) { return $mapa[$dias[$i]] }
    return $null
}

function Crear-Tarea {
    param([string]$frecuencia, [datetime]$hora, [string]$dia)

    $scriptPath = $PSCommandPath
    $arg = ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Run' -f $scriptPath)
    $accion = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg

    if ($frecuencia -eq 'Weekly') {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $dia -At $hora
    } else {
        $trigger = New-ScheduledTaskTrigger -Daily -At $hora
    }

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $Script:TareaNombre -Action $accion -Trigger $trigger `
        -Settings $settings -Description 'CopyKeeper: copia de respaldo automatica' -Force | Out-Null
}

function Programar-Copia {
    do {
        $tarea = Get-TareaCopy
        $info = @(
            (Describir-Tarea $tarea),
            "",
            ("Se ejecutara este script en modo silencioso:"),
            ("  {0}" -f $PSCommandPath)
        )
        $op = Show-Menu -Titulo "COPIA AUTOMATICA" -Info $info -Opciones @(
            "Programar copia DIARIA",
            "Programar copia SEMANAL",
            "Quitar la copia automatica",
            "Volver"
        )
        switch ($op) {
            0 {
                $h = Pedir-Hora
                if ($h) {
                    try {
                        Crear-Tarea -frecuencia 'Daily' -hora $h
                        Write-Host ("Copia DIARIA programada a las {0}." -f $h.ToString('HH:mm')) -ForegroundColor Green
                    } catch {
                        Write-Host ("ERROR al programar: {0}" -f $_.Exception.Message) -ForegroundColor Red
                    }
                    Pausar
                }
            }
            1 {
                $dia = Pedir-Dia
                if ($dia) {
                    $h = Pedir-Hora
                    if ($h) {
                        try {
                            Crear-Tarea -frecuencia 'Weekly' -hora $h -dia $dia
                            Write-Host ("Copia SEMANAL programada ({0} a las {1})." -f $dia, $h.ToString('HH:mm')) -ForegroundColor Green
                        } catch {
                            Write-Host ("ERROR al programar: {0}" -f $_.Exception.Message) -ForegroundColor Red
                        }
                        Pausar
                    }
                }
            }
            2 {
                if ($tarea) {
                    try {
                        Unregister-ScheduledTask -TaskName $Script:TareaNombre -Confirm:$false
                        Write-Host "Copia automatica eliminada." -ForegroundColor Green
                    } catch {
                        Write-Host ("ERROR al quitar: {0}" -f $_.Exception.Message) -ForegroundColor Red
                    }
                } else {
                    Write-Host "No habia ninguna copia automatica programada." -ForegroundColor Yellow
                }
                Pausar
            }
            default { return }   # Volver / ESC
        }
    } while ($true)
}

# =====================  PROGRAMA PRINCIPAL  =====================
$cfg = Cargar-Config

# --- Modo silencioso (-Run): ejecuta la copia y sale (lo usa la tarea programada) ---
if ($Run) {
    Write-Host ("[{0}] CopyKeeper -Run: iniciando copia automatica..." -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $ok = Invoke-Copia $cfg
    if ($ok) { exit 0 } else { exit 1 }
}

$opcionesMenu = @(
    "Elegir QUE SE COPIA del origen  (ver y marcar)",
    "Ver configuracion completa",
    "Cambiar carpeta de ORIGEN",
    "Cambiar carpeta de DESTINO",
    "Carpetas a ignorar  (agregar / quitar a mano)",
    "Archivos a ignorar  (agregar / quitar a mano)",
    "Carpetas/archivos EXTRA a incluir  (agregar / quitar)",
    "Activar / desactivar registro (log)",
    "Programar copia automatica  (Windows)",
    ">> EJECUTAR COPIA AHORA <<",
    "Salir"
)

$seleccion = 0
$salir = $false
do {
    $seleccion = Show-Menu -Titulo (Get-TituloPrincipal $cfg) -Info (Get-InfoEstado $cfg) `
        -Opciones $opcionesMenu -Inicial $seleccion `
        -Ayuda "(flechas para moverte - ENTER elige - ESC sale)" `
        -ColorOpcion @{ 9 = 'Green' }

    switch ($seleccion) {
        0 {
            $cambio = Elegir-Contenido $cfg
            if ($cambio) { Guardar-Config $cfg }
        }
        1 { Ver-Config $cfg }
        2 {
            $r = Cambiar-Ruta -etiqueta "ORIGEN" -validarExiste $true
            if ($r) { $cfg.origen = $r; Guardar-Config $cfg }
        }
        3 {
            $r = Cambiar-Ruta -etiqueta "DESTINO" -validarExiste $false
            if ($r) { $cfg.destino = $r; Guardar-Config $cfg }
        }
        4 {
            $ref = [ref]$cfg.carpetasAIgnorar
            $cambio = Administrar-Lista -lista $ref -titulo "CARPETAS A IGNORAR" -ejemplo "node_modules"
            $cfg.carpetasAIgnorar = $ref.Value
            if ($cambio) { Guardar-Config $cfg }
        }
        5 {
            $ref = [ref]$cfg.archivosAIgnorar
            $cambio = Administrar-Lista -lista $ref -titulo "ARCHIVOS A IGNORAR" -ejemplo "package-lock.json  (admite * y ?)"
            $cfg.archivosAIgnorar = $ref.Value
            if ($cambio) { Guardar-Config $cfg }
        }
        6 {
            $ref = [ref]$cfg.extras
            $cambio = Administrar-Lista -lista $ref -titulo "EXTRAS A INCLUIR" `
                -ejemplo "C:\Users\Usuario\Documents\Contratos  (ruta completa de carpeta o archivo)"
            $cfg.extras = $ref.Value
            if ($cambio) { Guardar-Config $cfg }
        }
        7 {
            $cfg.crearRegistro = -not $cfg.crearRegistro
            Guardar-Config $cfg
        }
        8 { Programar-Copia }
        9 { Ejecutar-Copia $cfg }
        10 { $salir = $true }   # Salir
        -1 { $salir = $true }   # ESC = salir
    }
} while (-not $salir)

Clear-Host
Write-Host "Hasta luego!" -ForegroundColor Cyan
