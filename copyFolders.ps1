param (
    [Parameter(Mandatory=$true)]
    [string]$CarpetaOrigen,
    
    [Parameter(Mandatory=$true)]
    [string]$CarpetaDestino,
    
    [Parameter(Mandatory=$false)]
    [string[]]$CarpetasAIgnorar = @(),
    
    [Parameter(Mandatory=$false)]
    [string[]]$ArchivosAIgnorar = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$CrearRegistro,
    
    [Parameter(Mandatory=$false)]
    [string]$ArchivoRegistro = "$env:USERPROFILE\Desktop\CopiarCarpetas_log.txt"
)

function EscribirLog {
    param (
        [string]$mensaje
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMensaje = "[$timestamp] $mensaje"
    
    Write-Host $logMensaje
    
    if ($CrearRegistro) {
        Add-Content -Path $ArchivoRegistro -Value $logMensaje -Encoding UTF8
    }
}

# Iniciar el registro si está habilitado
if ($CrearRegistro) {
    # Asegurar que existe la ruta del log
    $logFolder = Split-Path -Path $ArchivoRegistro -Parent
    if (-not (Test-Path -Path $logFolder -PathType Container)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
    
    $fechaHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "===== INICIO DE COPIA: $fechaHora =====" | Out-File -FilePath $ArchivoRegistro -Force -Encoding UTF8
    "Copiando desde: $CarpetaOrigen" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    "Copiando hacia: $CarpetaDestino" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    
    if ($CarpetasAIgnorar.Count -gt 0) {
        "Carpetas a ignorar: $($CarpetasAIgnorar -join ', ')" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    } else {
        "No se ignorará ninguna carpeta" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    }
    
    if ($ArchivosAIgnorar.Count -gt 0) {
        "Archivos a ignorar: $($ArchivosAIgnorar -join ', ')" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    } else {
        "No se ignorará ningún archivo específico" | Add-Content -Path $ArchivoRegistro -Encoding UTF8
    }
}

# Verificar que la carpeta de origen existe
if (-not (Test-Path -Path $CarpetaOrigen -PathType Container)) {
    EscribirLog "ERROR: La carpeta de origen '$CarpetaOrigen' no existe."
    exit 1
}

# Crear la carpeta de destino si no existe
if (-not (Test-Path -Path $CarpetaDestino -PathType Container)) {
    try {
        New-Item -Path $CarpetaDestino -ItemType Directory -Force | Out-Null
        EscribirLog "Carpeta de destino '$CarpetaDestino' creada."
    } catch {
        EscribirLog "ERROR: No se pudo crear la carpeta de destino '$CarpetaDestino': $($_.Exception.Message)"
        exit 1
    }
}

# Función para verificar si una carpeta debe ignorarse
function CarpetaDebeIgnorarse {
    param (
        [string]$ruta
    )
    
    # Extraer nombre de la carpeta (último segmento de la ruta)
    $nombreCarpeta = Split-Path -Path $ruta -Leaf
    
    # Verificar si el nombre de la carpeta está en la lista de carpetas a ignorar
    foreach ($carpeta in $CarpetasAIgnorar) {
        if ($nombreCarpeta -eq $carpeta) {
            return $true
        }
    }
    
    return $false
}

# Función para verificar si un archivo debe ignorarse
function ArchivoDebeIgnorarse {
    param (
        [string]$rutaArchivo
    )
    
    # Verificar si la carpeta padre debe ignorarse
    $carpetaPadre = Split-Path -Path $rutaArchivo -Parent
    if (CarpetaDebeIgnorarse -ruta $carpetaPadre) {
        return $true
    }
    
    # Verificar si el nombre del archivo está en la lista de archivos a ignorar
    $nombreArchivo = Split-Path -Path $rutaArchivo -Leaf
    
    foreach ($archivo in $ArchivosAIgnorar) {
        # Si tiene comodines, usar un patrón glob
        if ($archivo -match '[*?]') {
            if ($nombreArchivo -like $archivo) {
                return $true
            }
        }
        # Comparación exacta
        elseif ($nombreArchivo -eq $archivo) {
            return $true
        }
    }
    
    return $false
}

# Contador para estadísticas
$script:elementosCopiados = 0
$script:elementosIgnorados = 0
$script:errores = 0

function CopiarRecursivo {
    param (
        [string]$origen,
        [string]$destino
    )
    
    # Verificar si la carpeta actual debe ser ignorada
    if (CarpetaDebeIgnorarse -ruta $origen) {
        EscribirLog "Ignorando carpeta: $origen"
        $script:elementosIgnorados++
        return
    }
    
    # Crear carpeta de destino si no existe
    if (-not (Test-Path -Path $destino -PathType Container)) {
        try {
            New-Item -Path $destino -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            EscribirLog "ERROR al crear carpeta $destino : $($_.Exception.Message)"
            $script:errores++
            return
        }
    }
    
    # Obtener todos los archivos y carpetas en el origen
    try {
        $elementos = Get-ChildItem -Path $origen -Force -ErrorAction Stop
    } catch {
        EscribirLog "ERROR al acceder a $origen : $($_.Exception.Message)"
        $script:errores++
        return
    }
    
    # Procesar cada elemento (archivo o carpeta)
    foreach ($elemento in $elementos) {
        if ($elemento.PSIsContainer) {
            # Es una carpeta
            $carpetaOrigenCompleta = $elemento.FullName
            $carpetaDestinoCompleta = Join-Path -Path $destino -ChildPath $elemento.Name
            
            # Comprobar si debe ignorarse
            if (CarpetaDebeIgnorarse -ruta $carpetaOrigenCompleta) {
                EscribirLog "Ignorando carpeta: $($elemento.Name)"
                $script:elementosIgnorados++
            } else {
                # Continuar con la copia recursiva
                CopiarRecursivo -origen $carpetaOrigenCompleta -destino $carpetaDestinoCompleta
            }
        } else {
            # Es un archivo
            $archivoOrigenCompleto = $elemento.FullName
            $archivoDestinoCompleto = Join-Path -Path $destino -ChildPath $elemento.Name
            
            # Verificar si el archivo debe ignorarse
            if (ArchivoDebeIgnorarse -rutaArchivo $archivoOrigenCompleto) {
                EscribirLog "Ignorando archivo: $($elemento.Name)"
                $script:elementosIgnorados++
            } else {
                try {
                    # Comprobar si el archivo ya existe y es idéntico
                    $debeActualizar = $true
                    if (Test-Path -Path $archivoDestinoCompleto -PathType Leaf) {
                        $archivoOrigen = Get-Item -Path $archivoOrigenCompleto
                        $archivoDestino = Get-Item -Path $archivoDestinoCompleto
                        
                        # Si tienen el mismo tamaño y la misma fecha de modificación, asumimos que son idénticos
                        if (($archivoOrigen.Length -eq $archivoDestino.Length) -and 
                            ($archivoOrigen.LastWriteTime -eq $archivoDestino.LastWriteTime)) {
                            $debeActualizar = $false
                        }
                    }
                    
                    if ($debeActualizar) {
                        Copy-Item -Path $archivoOrigenCompleto -Destination $archivoDestinoCompleto -Force -ErrorAction Stop
                        $script:elementosCopiados++
                        
                        # Mostrar progreso cada 100 archivos
                        if ($script:elementosCopiados % 100 -eq 0) {
                            EscribirLog "Progreso: $($script:elementosCopiados) elementos copiados, $($script:elementosIgnorados) ignorados."
                        }
                    } else {
                        # Archivo idéntico, no es necesario actualizar
                        EscribirLog "Archivo sin cambios (no se actualiza): $($elemento.Name)" -Verbose
                    }
                } catch {
                    EscribirLog "ERROR al copiar $($elemento.Name): $($_.Exception.Message)"
                    $script:errores++
                }
            }
        }
    }
}

# Iniciar el proceso de copia
try {
    $tiempoInicio = Get-Date
    EscribirLog "Iniciando proceso de copia..."
    
    CopiarRecursivo -origen $CarpetaOrigen -destino $CarpetaDestino
    
    $tiempoFin = Get-Date
    $duracion = $tiempoFin - $tiempoInicio
    
    EscribirLog "============= RESUMEN ============="
    EscribirLog "Proceso de copia completado."
    EscribirLog "Elementos copiados: $script:elementosCopiados"
    EscribirLog "Elementos ignorados: $script:elementosIgnorados"
    EscribirLog "Errores: $script:errores"
    EscribirLog "Tiempo total: $($duracion.ToString())"
    
    # Si hubo errores pero también se copiaron archivos, considerarlo parcialmente exitoso
    if ($script:errores -gt 0) {
        if ($script:elementosCopiados -gt 0) {
            EscribirLog "ADVERTENCIA: La operación se completó con algunos errores. Revise el registro para más detalles."
        } else {
            EscribirLog "ERROR: La operación falló completamente."
            exit 1
        }
    }
}
catch {
    EscribirLog "ERROR CRÍTICO: $($_.Exception.Message)"
    exit 1
}

if ($CrearRegistro) {
    EscribirLog "El registro completo se guardó en: $ArchivoRegistro"
}

# Salir con código de error si hubo errores graves
if ($script:errores -gt $script:elementosCopiados) {
    exit 1
} else {
    exit 0
}