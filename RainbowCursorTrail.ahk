#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SendMode Input
CoordMode, Mouse, Screen
SetWinDelay, -1
SetControlDelay, -1
OnExit, CleanUp

;=====================================================================
;  Rainbow Cursor Trail + Click Effects        (AutoHotkey v1.1 only)
;
;  Real GDI+ version: the whole trail and every click effect is drawn
;  as anti-aliased vector graphics (round-capped lines / filled
;  circles) into ONE transparent overlay window each frame, instead
;  of moving lots of separate small windows around. This is what
;  makes it actually smooth. Fully self-contained — no extra files.
;
;  - Left click    -> fast expanding "ring" burst   (cool colors)
;  - Right click   -> rotating spiral burst          (warm colors)
;  - XButton1      -> falling confetti / fireworks   (green tones)
;  - XButton2      -> pulsing "breathing star" burst (pink/purple)
;    (XButton1/2 only fire if your mouse actually has those buttons)
;
;  All clicks still work normally underneath — the effects are purely
;  visual and click-through.
;
;  Exit: right-click the tray icon -> Exit, or press Ctrl+Alt+X
;=====================================================================

;---------------------------- CONFIG --------------------------------
TrailLength   := 20      ; number of points making up the trail line
Thickness     := 12      ; line thickness (px)
UpdateMS      := 15      ; refresh rate in ms (~66 fps)
HueSpeed      := 8       ; how fast the rainbow cycles along the trail

BurstCount    := 14      ; particles spawned per click
ParticleSize  := 8       ; burst particle diameter (px)
ParticleLife  := 30      ; how many frames each particle lives

SmoothFactor  := 0.35    ; drag/elastic feel: lower = looser & laggier tail,
                          ; higher = tighter & snappier (range ~0.1 - 0.8)
;----------------------------------------------------------------------

Hue := 0
TrailX := [], TrailY := []
Particles := []

; ---------------- GDI+ startup ----------------
pToken := Gdip_Startup()

; ---------------- Full virtual-screen overlay window ----------------
SysGet, VScreenX, 76   ; SM_XVIRTUALSCREEN
SysGet, VScreenY, 77   ; SM_YVIRTUALSCREEN
SysGet, VScreenW, 78   ; SM_CXVIRTUALSCREEN
SysGet, VScreenH, 79   ; SM_CYVIRTUALSCREEN

Gui, +E0x20 +E0x80000 +LastFound +AlwaysOnTop +ToolWindow -Caption
Gui, Show, x%VScreenX% y%VScreenY% w%VScreenW% h%VScreenH% NA
hwnd1 := WinExist()

; ---------------- Persistent off-screen drawing surface ----------------
hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
hdcMem    := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")

VarSetCapacity(bi, 40, 0)
NumPut(40, bi, 0, "UInt")          ; biSize
NumPut(VScreenW, bi, 4, "Int")     ; biWidth
NumPut(-VScreenH, bi, 8, "Int")    ; biHeight (negative = top-down)
NumPut(1, bi, 12, "UShort")        ; biPlanes
NumPut(32, bi, 14, "UShort")       ; biBitCount
NumPut(0, bi, 16, "UInt")          ; BI_RGB

hbmMem := DllCall("CreateDIBSection", "Ptr", hdcMem, "Ptr", &bi, "UInt", 0, "PtrP", pBits, "Ptr", 0, "UInt", 0, "Ptr")
hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmMem, "Ptr")
DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "PtrP", G)
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)  ; SmoothingModeAntiAlias

; ---------------- Prime the trail at the current mouse pos ----------------
MouseGetPos, mx0, my0
Loop, %TrailLength%
{
    TrailX[A_Index] := mx0
    TrailY[A_Index] := my0
}

SetTimer, MainLoop, %UpdateMS%
return

;=====================================================================
; Main loop: redraws the whole overlay every frame
;=====================================================================
MainLoop:
    MouseGetPos, mx, my

    ; head follows the cursor exactly; every other point elastically
    ; "chases" the point ahead of it — this is what gives the smooth,
    ; stretchy drag feel instead of a rigid history-based snake
    TrailX[1] := mx
    TrailY[1] := my
    Loop, % TrailLength - 1
    {
        i := A_Index + 1
        TrailX[i] += (TrailX[i-1] - TrailX[i]) * SmoothFactor
        TrailY[i] += (TrailY[i-1] - TrailY[i]) * SmoothFactor
    }

    Hue := Mod(Hue + HueSpeed, 360)

    Gdip_GraphicsClear(G)

    ; ---- smooth rainbow line: round-capped segments, anti-aliased ----
    Loop, % TrailLength - 1
    {
        i  := A_Index
        x1 := TrailX[i]   - VScreenX, y1 := TrailY[i]   - VScreenY
        x2 := TrailX[i+1] - VScreenX, y2 := TrailY[i+1] - VScreenY

        thisHue := Mod(Hue + (i * 12), 360)
        rgb     := HSVtoRGB(thisHue, 100, 100)
        alpha   := 255 - Round((i-1) * (220 / TrailLength))
        if (alpha < 20)
            alpha := 20
        argb := (alpha << 24) | rgb

        pPen := Gdip_CreatePen(argb, Thickness)
        Gdip_DrawLine(G, pPen, x1, y1, x2, y2)
        Gdip_DeletePen(pPen)
    }

    UpdateParticles()

    UpdateLayeredWin(hwnd1, hdcMem, VScreenX, VScreenY, VScreenW, VScreenH)
return

;=====================================================================
; Advance + draw every active burst particle
;=====================================================================
UpdateParticles() {
    global Particles, G, VScreenX, VScreenY

    NewParticles := []
    for index, p in Particles
    {
        p.life += 1
        prog := p.life / p.maxLife
        if (prog >= 1)
            continue

        if (p.type = 1) {
            ; LEFT CLICK — constant-speed expanding ring
            speed := 5
            p.x += Cos(p.ang * 0.0174533) * speed
            p.y += Sin(p.ang * 0.0174533) * speed
            rgb := HSVtoRGB(Mod(190 + p.life*3, 360), 90, 100)

        } else if (p.type = 2) {
            ; RIGHT CLICK — rotating spiral, growing radius
            p.ang += 10
            radius := 3 + (prog * 70)
            p.x := p.startX + Cos(p.ang * 0.0174533) * radius
            p.y := p.startY + Sin(p.ang * 0.0174533) * radius
            rgb := HSVtoRGB(Mod(20 + p.life*2, 360), 100, 100)

        } else if (p.type = 3) {
            ; XBUTTON1 — confetti / fireworks with gravity
            p.vy += 0.6
            p.x += p.vx
            p.y += p.vy
            rgb := HSVtoRGB(Mod(100 + p.life*4, 360), 90, 100)

        } else if (p.type = 4) {
            ; XBUTTON2 — pulsing "breathing star" (out then back)
            radius := 80 * Sin(prog * 3.14159265)
            p.x := p.startX + Cos(p.ang * 0.0174533) * radius
            p.y := p.startY + Sin(p.ang * 0.0174533) * radius
            rgb := HSVtoRGB(Mod(280 + p.life*3, 360), 80, 100)
        }

        alpha := Round(255 * (1 - prog))
        argb  := (alpha << 24) | rgb
        sz    := p.size

        pBrush := Gdip_BrushCreateSolid(argb)
        Gdip_FillEllipse(G, pBrush, p.x - VScreenX - sz/2, p.y - VScreenY - sz/2, sz, sz)
        Gdip_DeleteBrush(pBrush)

        NewParticles.Push(p)
    }
    Particles := NewParticles
}

;=====================================================================
; Spawn a burst of particles at (cx, cy)
;   type: 1 = Left click, 2 = Right click, 3 = XButton1, 4 = XButton2
;=====================================================================
SpawnBurst(cx, cy, type) {
    global Particles, BurstCount, ParticleLife, ParticleSize

    Loop, %BurstCount%
    {
        p := { life: 0, maxLife: ParticleLife, type: type
             , x: cx, y: cy, startX: cx, startY: cy
             , vx: 0, vy: 0, ang: (360/BurstCount)*A_Index
             , size: ParticleSize }

        if (type = 3) {
            Random, rvx, -300, 300
            Random, rvy, -450, -150
            p.vx := rvx / 100
            p.vy := rvy / 100
        }

        Particles.Push(p)
    }
}

;=====================================================================
; HSV (0-359, 0-100, 0-100) -> packed 0xRRGGBB integer
;=====================================================================
HSVtoRGB(H, S, V) {
    H := Mod(H, 360)
    C := (V/100) * (S/100)
    X := C * (1 - Abs(Mod(H/60, 2) - 1))
    m := (V/100) - C

    if (H < 60) {
        r1:=C, g1:=X, b1:=0
    } else if (H < 120) {
        r1:=X, g1:=C, b1:=0
    } else if (H < 180) {
        r1:=0, g1:=C, b1:=X
    } else if (H < 240) {
        r1:=0, g1:=X, b1:=C
    } else if (H < 300) {
        r1:=X, g1:=0, b1:=C
    } else {
        r1:=C, g1:=0, b1:=X
    }

    r := Round((r1+m)*255)
    g := Round((g1+m)*255)
    b := Round((b1+m)*255)
    return (r << 16) | (g << 8) | b
}

;=====================================================================
; Minimal GDI+ helpers (no external library needed)
;=====================================================================
Gdip_Startup() {
    if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
        DllCall("LoadLibrary", "Str", "gdiplus.dll")
    VarSetCapacity(si, 24, 0)
    NumPut(1, si, 0, "UInt")
    DllCall("gdiplus\GdiplusStartup", "PtrP", pToken, "Ptr", &si, "Ptr", 0)
    return pToken
}

Gdip_GraphicsClear(pGraphics) {
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00000000)
}

Gdip_CreatePen(ARGB, w) {
    DllCall("gdiplus\GdipCreatePen1", "UInt", ARGB, "Float", w, "Int", 2, "PtrP", pPen)
    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pPen, "Int", 2) ; round
    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pPen, "Int", 2)   ; round
    return pPen
}

Gdip_DeletePen(pPen) {
    DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
}

Gdip_DrawLine(pGraphics, pPen, x1, y1, x2, y2) {
    DllCall("gdiplus\GdipDrawLine", "Ptr", pGraphics, "Ptr", pPen, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
}

Gdip_BrushCreateSolid(ARGB) {
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB, "PtrP", pBrush)
    return pBrush
}

Gdip_DeleteBrush(pBrush) {
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
}

Gdip_FillEllipse(pGraphics, pBrush, x, y, w, h) {
    DllCall("gdiplus\GdipFillEllipse", "Ptr", pGraphics, "Ptr", pBrush, "Float", x, "Float", y, "Float", w, "Float", h)
}

; Blits the DIB in hdc onto the layered window hwnd with per-pixel alpha
UpdateLayeredWin(hwnd, hdc, x, y, w, h) {
    VarSetCapacity(pt, 8, 0)
    NumPut(x, pt, 0, "Int")
    NumPut(y, pt, 4, "Int")

    VarSetCapacity(sz, 8, 0)
    NumPut(w, sz, 0, "Int")
    NumPut(h, sz, 4, "Int")

    VarSetCapacity(ptSrc, 8, 0) ; source origin (0,0)

    VarSetCapacity(blend, 4, 0)
    NumPut(0, blend, 0, "Char")    ; AC_SRC_OVER
    NumPut(0, blend, 1, "Char")
    NumPut(255, blend, 2, "Char")  ; SourceConstantAlpha
    NumPut(1, blend, 3, "Char")    ; AC_SRC_ALPHA

    DllCall("UpdateLayeredWindow"
        , "Ptr", hwnd
        , "Ptr", 0
        , "Ptr", &pt
        , "Ptr", &sz
        , "Ptr", hdc
        , "Ptr", &ptSrc
        , "UInt", 0
        , "Ptr", &blend
        , "UInt", 2)  ; ULW_ALPHA
}

;=====================================================================
; Hotkeys — the leading ~ lets the click still work normally
;=====================================================================
~LButton::
    MouseGetPos, cx, cy
    SpawnBurst(cx, cy, 1)
return

~RButton::
    MouseGetPos, cx, cy
    SpawnBurst(cx, cy, 2)
return

~XButton1::
    MouseGetPos, cx, cy
    SpawnBurst(cx, cy, 3)
return

~XButton2::
    MouseGetPos, cx, cy
    SpawnBurst(cx, cy, 4)
return

^!x::ExitApp  ; Ctrl+Alt+X to quit the script

;=====================================================================
; Cleanup on exit
;=====================================================================
CleanUp:
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
    DllCall("DeleteObject", "Ptr", hbmMem)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
    ExitApp
return
