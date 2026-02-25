Add-Type -AssemblyName System.Drawing

$size = 256
$bitmap = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = 'HighQuality'
$graphics.TextRenderingHint = 'AntiAliasGridFit'

# Black background with rounded feel
$graphics.Clear([System.Drawing.Color]::FromArgb(10, 10, 10))

# Red accent square in center
$redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 38, 38))
$graphics.FillRectangle($redBrush, 20, 20, 216, 216)

# Black inner square
$blackBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(10, 10, 10))
$graphics.FillRectangle($blackBrush, 28, 28, 200, 200)

# "SQ" text
$font = New-Object System.Drawing.Font("Segoe UI", 90, [System.Drawing.FontStyle]::Bold)
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = 'Center'
$format.LineAlignment = 'Center'
$rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
$graphics.DrawString("SQ", $font, $whiteBrush, $rect, $format)

$graphics.Dispose()

# Save as PNG first, then convert to ICO
$pngPath = "F:\CLAUDE\APPGaming\resources\icon.png"
$bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Create ICO from bitmap
$icoPath = "F:\CLAUDE\APPGaming\resources\icon.ico"
$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
$stream = [System.IO.File]::Create($icoPath)
$icon.Save($stream)
$stream.Close()
$icon.Dispose()
$bitmap.Dispose()

Write-Host "Icon saved to $icoPath"
