$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function New-IconBitmap {
    param(
        [int] $Size,
        [string] $Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $scale = $Size / 1024.0

    function S([float] $Value) {
        return [float]($Value * $scale)
    }

    function RoundedRect([float] $X, [float] $Y, [float] $W, [float] $H, [float] $R) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $R * 2
        $path.AddArc($X, $Y, $d, $d, 180, 90)
        $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
        $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
        $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        return $path
    }

    $bgPath = RoundedRect (S 0) (S 0) (S 1024) (S 1024) (S 232)
    $bgBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.PointF]::new((S 150), (S 100)),
        [System.Drawing.PointF]::new((S 880), (S 930)),
        [System.Drawing.ColorTranslator]::FromHtml('#0f766e'),
        [System.Drawing.ColorTranslator]::FromHtml('#111827')
    )
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend
    $blend.Positions = [float[]](0, 0.48, 1)
    $blend.Colors = [System.Drawing.Color[]](
        [System.Drawing.ColorTranslator]::FromHtml('#0f766e'),
        [System.Drawing.ColorTranslator]::FromHtml('#2563eb'),
        [System.Drawing.ColorTranslator]::FromHtml('#111827')
    )
    $bgBrush.InterpolationColors = $blend
    $graphics.FillPath($bgBrush, $bgPath)

    $cyanBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(46, 103, 232, 249))
    $greenBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(38, 52, 211, 153))
    $graphics.FillEllipse($cyanBrush, (S 690), (S 82), (S 232), (S 232))
    $graphics.FillEllipse($greenBrush, (S 38), (S 676), (S 300), (S 300))

    $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 2, 6, 23))
    $graphics.FillPath($shadowBrush, (RoundedRect (S 236) (S 264) (S 552) (S 552) (S 128)))

    $panelPath = RoundedRect (S 258) (S 216) (S 508) (S 592) (S 116)
    $panelBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.PointF]::new((S 260), (S 260)),
        [System.Drawing.PointF]::new((S 760), (S 780)),
        [System.Drawing.ColorTranslator]::FromHtml('#ffffff'),
        [System.Drawing.ColorTranslator]::FromHtml('#dbeafe')
    )
    $graphics.FillPath($panelBrush, $panelPath)

    $rackBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#0f172a'))
    $lineBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#e0f2fe'))
    $ledGreen = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#22c55e'))
    $ledCyan = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#38bdf8'))
    $ledAmber = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#f59e0b'))

    foreach ($y in 312, 460, 608) {
        $graphics.FillPath($rackBrush, (RoundedRect (S 336) (S $y) (S 352) (S 104) (S 30)))
    }

    $graphics.FillEllipse($ledGreen, (S 372), (S 350), (S 28), (S 28))
    $graphics.FillEllipse($ledCyan, (S 372), (S 498), (S 28), (S 28))
    $graphics.FillEllipse($ledAmber, (S 372), (S 646), (S 28), (S 28))

    foreach ($y in 350, 498, 646) {
        $graphics.FillPath($lineBrush, (RoundedRect (S 430) (S $y) (S 190) (S 28) (S 14)))
    }

    $shieldPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $shieldPath.AddPolygon([System.Drawing.PointF[]](
        [System.Drawing.PointF]::new((S 688), (S 602)),
        [System.Drawing.PointF]::new((S 786), (S 644)),
        [System.Drawing.PointF]::new((S 786), (S 706)),
        [System.Drawing.PointF]::new((S 758), (S 768)),
        [System.Drawing.PointF]::new((S 688), (S 824)),
        [System.Drawing.PointF]::new((S 618), (S 768)),
        [System.Drawing.PointF]::new((S 590), (S 706)),
        [System.Drawing.PointF]::new((S 590), (S 644))
    ))
    $shieldBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#2563eb'))
    $graphics.FillPath($shieldBrush, $shieldPath)

    $checkPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), (S 28)
    $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $checkPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawLines($checkPen, [System.Drawing.PointF[]](
        [System.Drawing.PointF]::new((S 644), (S 696)),
        [System.Drawing.PointF]::new((S 676), (S 728)),
        [System.Drawing.PointF]::new((S 734), (S 658))
    ))

    $dir = Split-Path -Parent $Path
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

$androidIcons = @{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
}

foreach ($entry in $androidIcons.GetEnumerator()) {
    New-IconBitmap -Size $entry.Value -Path $entry.Key
}

New-IconBitmap -Size 192 -Path 'api/assets/icon-192.png'
New-IconBitmap -Size 512 -Path 'api/assets/icon-512.png'
New-IconBitmap -Size 32 -Path 'api/assets/favicon.png'
