# OCR of one image with the built-in Windows OCR engine (no install, runs locally).
# Prints one line per recognized text line: X|Y|text (X/Y = top-left of the first word, in
# pixels of the ORIGINAL image), sorted top-to-bottom, left-to-right. Use it to check titles and
# labels on Power BI screenshots (powerbi-desktop screenshot) without sending the image to the AI.
# Not reliable for dense table numbers - check numbers with a DAX query instead.
#
# Windows OCR needs Windows PowerShell 5.1 (WinRT types), not pwsh:
#   powershell -ExecutionPolicy Bypass -File OcrImage.ps1 -Path page.png
#   powershell -ExecutionPolicy Bypass -File OcrImage.ps1 -Path page.png -Upscale 2 -OutFile page.txt
#
# -Upscale: enlarges the image before OCR (small text reads better). Taking the screenshot at a
# higher scale (powerbi-desktop screenshot --scale 2 or 3) is better still - use both if needed.
# The image is kept under the engine's MaxImageDimension automatically.
# -Enhance: clean-up before OCR, as in the lesson-notes pipeline (prep.py): grayscale +
# auto-contrast (1st..99th luminance percentile stretched to black..white) + high-quality
# bicubic enlargement by -Upscale. Helps pale text (light-grey labels, low-contrast themes).
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [double]$Upscale = 1,
    [string]$Language = 'en-US',
    [string]$OutFile,
    [switch]$Enhance
)

$ErrorActionPreference = 'Stop'

# Writes an enhanced copy (grayscale, auto-contrast, enlarged by $factor) to a temp PNG.
function New-EnhancedImage([string]$src, [double]$factor) {
    Add-Type -AssemblyName System.Drawing
    $img = [Drawing.Bitmap]::FromFile($src)
    try {
        # Luminance percentiles from a small thumbnail (fast enough in PowerShell)
        $tw = [Math]::Min(400, $img.Width); $th = [int]([Math]::ClientA(1, $img.Height * $tw / $img.Width))
        $thumb = New-Object Drawing.Bitmap($img, $tw, $th)
        $rect  = New-Object Drawing.Rectangle(0, 0, $tw, $th)
        $data  = $thumb.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $bytes = New-Object byte[] ($data.Stride * $th)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $thumb.UnlockBits($data); $thumb.Dispose()
        $hist = New-Object int[] 256; $n = 0
        for ($y = 0; $y -lt $th; $y++) {
            $row = $y * $data.Stride
            for ($x = 0; $x -lt $tw; $x++) {
                $i = $row + 3 * $x
                $hist[[int](0.114 * $bytes[$i] + 0.587 * $bytes[$i + 1] + 0.299 * $bytes[$i + 2])]++; $n++
            }
        }
        $acc = 0; $lo = 0; $hi = 255
        for ($v = 0; $v -lt 256; $v++) { $acc += $hist[$v]; if ($acc -ge 0.01 * $n) { $lo = $v; break } }
        $acc = 0
        for ($v = 255; $v -ge 0; $v--) { $acc += $hist[$v]; if ($acc -ge 0.01 * $n) { $hi = $v; break } }
        if ($hi - $lo -lt 16) { $lo = 0; $hi = 255 }
        $gain = 255.0 / ($hi - $lo); $off = -$lo * $gain / 255.0

        # Grayscale + stretch in one color matrix
        $r = 0.299 * $gain; $g = 0.587 * $gain; $b = 0.114 * $gain
        $cm = New-Object Drawing.Imaging.ColorMatrix(,[single[][]]@(
            [single[]]@($r, $r, $r, 0, 0), [single[]]@($g, $g, $g, 0, 0), [single[]]@($b, $b, $b, 0, 0),
            [single[]]@(0, 0, 0, 1, 0),    [single[]]@($off, $off, $off, 0, 1)))
        $attr = New-Object Drawing.Imaging.ImageAttributes; $attr.SetColorMatrix($cm)
        $w = [int]($img.Width * $factor); $h = [int]($img.Height * $factor)
        $outBmp = New-Object Drawing.Bitmap($w, $h)
        $gfx = [Drawing.Graphics]::FromImage($outBmp)
        $gfx.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gfx.DrawImage($img, (New-Object Drawing.Rectangle(0, 0, $w, $h)), 0, 0, $img.Width, $img.Height, [Drawing.GraphicsUnit]::Pixel, $attr)
        $gfx.Dispose()
        $tmp = Join-Path $env:TEMP ("ocr_enh_{0}.png" -f [guid]::NewGuid().ToString('N'))
        $outBmp.Save($tmp, [Drawing.Imaging.ImageFormat]::Png); $outBmp.Dispose()
        $tmp
    } finally { $img.Dispose() }
}
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) {
    $t = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($op))
    $t.Wait(-1) | Out-Null
    $t.Result
}
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new($Language))
if (-not $engine) { throw "OCR language '$Language' is not installed (Settings > Time & language > Language)." }

$full = (Resolve-Path $Path).Path
$max  = [Windows.Media.Ocr.OcrEngine]::MaxImageDimension
$pre  = 1   # factor already applied by -Enhance (coordinates are divided by it at the end)
$tmp  = $null
if ($Enhance) {
    Add-Type -AssemblyName System.Drawing
    $probe = [Drawing.Image]::FromFile($full); $long0 = [Math]::ClientA($probe.Width, $probe.Height); $probe.Dispose()
    $pre = [Math]::Min($Upscale, $max / $long0)
    $tmp = New-EnhancedImage $full $pre
    $full = $tmp
}
$file    = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($full)) ([Windows.Storage.StorageFile])
$stream  = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])

# Scale, capped so the longer side stays within the engine limit (already enlarged if -Enhance)
$long  = [Math]::ClientA($decoder.PixelWidth, $decoder.PixelHeight)
$scale = if ($Enhance) { [Math]::Min(1, $max / $long) } else { [Math]::Min($Upscale, $max / $long) }
$transform = New-Object Windows.Graphics.Imaging.BitmapTransform
$transform.ScaledWidth  = [uint32][Math]::Floor($decoder.PixelWidth * $scale)
$transform.ScaledHeight = [uint32][Math]::Floor($decoder.PixelHeight * $scale)
$transform.InterpolationMode = [Windows.Graphics.Imaging.BitmapInterpolationMode]::Fant
$bitmap = Await ($decoder.GetSoftwareBitmapAsync(
    [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
    [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied,
    $transform,
    [Windows.Graphics.Imaging.ExifOrientationMode]::IgnoreExifOrientation,
    [Windows.Graphics.Imaging.ColorManagementMode]::DoNotColorManage)) ([Windows.Graphics.Imaging.SoftwareBitmap])

$res = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
$stream.Dispose()
if ($tmp) { [IO.File]::Delete($tmp) }

# Coordinates back in original-image pixels; sort by row (10 px bands), then by X
$div = $scale * $pre
$lines = foreach ($l in $res.Lines) {
    $w = ($l.Words | Select-Object -First 1).BoundingRect
    [pscustomobject]@{ X = [int]($w.X / $div); Y = [int]($w.Y / $div); Text = $l.Text }
}
$out = $lines | Sort-Object @{ e = { [int]($_.Y / 10) } }, X | ForEach-Object { '{0}|{1}|{2}' -f $_.X, $_.Y, $_.Text }

if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]@($out), (New-Object Text.UTF8Encoding($false))) }
else { $out }
