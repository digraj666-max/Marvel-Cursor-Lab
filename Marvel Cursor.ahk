; =====================================================================
;  Cursor Lab - Marvel Desktop Buddies
;  Created by Digraj  |  https://github.com/digraj666-max
;  Licensed under the MIT License - this notice must be kept intact.
; =====================================================================
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
;  Web-Hero & Rocket-Hero Desktop Buddies         (AutoHotkey v1.1)
;
;  - Web-hero (spidy.png) hangs top-center of the screen.
;  - Rocket-hero (iron.png) stands bottom-right corner.
;  - Cap-hero (cap.png) stands bottom-left corner, next to the Start button.
;  - Drag any file/icon (hold left click + move) -> a real sagging silk
;    strand shoots from web-hero's free, downward-facing hand and follows
;    your cursor until you drop. Flick the dragged item fast and a wave
;    ripples down the strand toward the anchor, shrinking as it travels —
;    just like snapping a rope tied to a wall.
;  - Double-click anything -> rocket-hero launches one of two attacks:
;      1) a charged palm blast beam
;      2) twin shoulder missiles that weave around their flight line like
;         a DNA double helix — a long, curvy, out-of-phase pair — with
;         real flame trails
;    Either way it ends in a proper fireball + shockwave ring.
;  - Right-click -> Captain America throws his shield at the target; it
;    loops out one way and boomerangs back along a different curve, like a
;    real thrown disc rather than retracing its own path. Only one shield
;    is ever in flight at a time.
;  - Middle-click -> Hulk Smash: ground cracks + a green energy flash
;    and flying debris.
;  - Side button 1 -> a Doctor Strange portal opens, spins, and closes.
;  - Side button 2 -> a Thanos-snap dust/ash disintegration burst.
;
;  NOTE: iron.png, spidy.png and cap.png must exist at the paths set in
;  the CONFIG section below (edit IronPngPath / SpidyPngPath / CapPngPath
;  if you move the files or use different filenames). Also tweak
;  SpidyHandFX / SpidyHandFY there so the web anchors to your Spidy png's
;  actual hand position, and CapHeroX / CapHeroY if your Start button
;  isn't in the usual spot.
;
;  Everything is drawn as anti-aliased GDI+ graphics in one
;  click-through overlay window. Fully self-contained, no extra files.
;
;  Exit: right-click the tray icon -> Exit, or press Ctrl+Alt+X
;=====================================================================

;---------------------------- CONFIG --------------------------------
UpdateMS        := 15     ; refresh rate (~66 fps)

ExplosionCount  := 24     ; fire chunks per explosion

DragThreshold   := 6      ; px of movement before a hold counts as a drag
DoubleClickMS   := 450    ; max gap between clicks to count as double-click
DoubleClickDist := 14     ; px — both clicks must land this close together

; ---- hero artwork (PNG, drawn instead of the old hand-drawn shapes) ----
IronPngPath    := "C:\Users\Digraj_14\Downloads\Cursor lab\iron.png"
SpidyPngPath   := "C:\Users\Digraj_14\Downloads\Cursor lab\spidy.png"
CapPngPath     := "C:\Users\Digraj_14\Downloads\Cursor lab\cap.png"   ; << rename to match your actual file if different
RocketImgH     := 150     ; Iron Man display height in px (width auto-scales)
RocketAnchorFY := 0.40    ; how far down (0-1) the "chest" reference point sits in his image
SpidyImgH      := 90      ; Spider-Man display height in px (width auto-scales)
CapImgH        := 84      ; Captain America display height in px (width auto-scales)

; Where on the Spidy PNG his free/dangling hand (the one facing down) actually
; is, as a 0-1 fraction of the image's width/height. (0,0)=top-left corner,
; (1,1)=bottom-right corner. The web strand now starts exactly from this point,
; so nudge these two numbers until the silk lines up with the hand in YOUR png.
SpidyHandFX    := 0.50    ; 0 = left edge, 1 = right edge
SpidyHandFY    := 0.92    ; 0 = top edge,  1 = bottom edge
;----------------------------------------------------------------------

Particles  := []
Missiles   := []
Shockwaves := []
Smashes    := []
Portals    := []
Shields    := []

DownX := 0, DownY := 0, DownTime := 0
DragCandidate := false, IsDragging := false, WebActive := false
DragX := 0, DragY := 0
PrevDragX := 0, PrevDragY := 0
WebImpulseMag := 0, WebImpulseTime := 0
LastClickTime := 0, LastClickX := 0, LastClickY := 0

HandChargeLife := 0, HandBeamLife := 0, HandTX := 0, HandTY := 0

; ---------------- GDI+ startup ----------------
pToken := Gdip_Startup()
Menu, Tray, Tip, Cursor Lab - made by Digraj
Menu, Tray, Add, About / Made by Digraj, ShowAbout
TrayTip, Cursor Lab, Made by Digraj`ngithub.com/digraj666-max, 4

; ---------------- Load hero PNGs ----------------
pImgIron  := 0, RocketImgW := 0
pImgSpidy := 0, SpidyImgW  := 0
pImgCap   := 0, CapImgW    := 0

if (FileExist(IronPngPath))
{
    pImgIron := Gdip_LoadImageFromFile(IronPngPath)
    natW := Gdip_GetImageWidth(pImgIron), natH := Gdip_GetImageHeight(pImgIron)
    if (natH > 0)
        RocketImgW := RocketImgH * (natW/natH)
}
else
    TrayTip, Cursor Lab, Couldn't find iron.png at:`n%IronPngPath%, 4

if (FileExist(SpidyPngPath))
{
    pImgSpidy := Gdip_LoadImageFromFile(SpidyPngPath)
    natW2 := Gdip_GetImageWidth(pImgSpidy), natH2 := Gdip_GetImageHeight(pImgSpidy)
    if (natH2 > 0)
        SpidyImgW := SpidyImgH * (natW2/natH2)
}
else
    TrayTip, Cursor Lab, Couldn't find spidy.png at:`n%SpidyPngPath%, 4

if (FileExist(CapPngPath))
{
    pImgCap := Gdip_LoadImageFromFile(CapPngPath)
    natW3 := Gdip_GetImageWidth(pImgCap), natH3 := Gdip_GetImageHeight(pImgCap)
    if (natH3 > 0)
        CapImgW := CapImgH * (natW3/natH3)
}
else
    TrayTip, Cursor Lab, Couldn't find cap.png at:`n%CapPngPath%, 4

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
NumPut(40, bi, 0, "UInt")
NumPut(VScreenW, bi, 4, "Int")
NumPut(-VScreenH, bi, 8, "Int")
NumPut(1, bi, 12, "UShort")
NumPut(32, bi, 14, "UShort")
NumPut(0, bi, 16, "UInt")

hbmMem := DllCall("CreateDIBSection", "Ptr", hdcMem, "Ptr", &bi, "UInt", 0, "PtrP", pBits, "Ptr", 0, "UInt", 0, "Ptr")
hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmMem, "Ptr")
DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "PtrP", G)
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", G, "Int", 4)

; ---------------- Hero positions ----------------
WebHeroX    := VScreenX + (VScreenW // 2)
WebHeroY    := VScreenY + 4
RocketHeroX := VScreenX + VScreenW - 45
RocketHeroY := VScreenY + VScreenH - 60

; Bottom-left corner, tucked into the empty space just right of the Start
; button on the taskbar. Nudge CapHeroX right/left if your taskbar/Start
; button is a different size.
CapHeroX    := VScreenX + 78
CapHeroY    := VScreenY + VScreenH - 0

SetTimer, MainLoop, %UpdateMS%
return

;=====================================================================
; Main loop
;=====================================================================
MainLoop:
    MouseGetPos, mx, my
    Gdip_GraphicsClear(G)

    ; ---- drag detection: promote a held click into a "file drag" ----
    if (DragCandidate && !IsDragging)
    {
        if (GetKeyState("LButton", "P"))
        {
            MouseGetPos, dcx, dcy
            ddx0 := dcx - DownX, ddy0 := dcy - DownY
            if (Sqrt(ddx0*ddx0 + ddy0*ddy0) > DragThreshold)
            {
                IsDragging := true
                WebActive := true
                PrevDragX := dcx, PrevDragY := dcy
                WebImpulseMag := 0
                WebImpulseTime := A_TickCount
            }
        }
        else
            DragCandidate := false
    }
    if (IsDragging)
        MouseGetPos, DragX, DragY

    ; ---- web-hero's silk strand: sags under gravity, and rings with a
    ;      decaying wave when you flick the dragged item — the wave
    ;      shrinks as it travels up toward the anchor, like a plucked
    ;      rope tied to a wall ----
    ; Spidy's gentle left-right sway, computed once per frame so the web
    ; strand's anchor and his drawn sprite always agree on where his hand is.
    SpidySway := Sin(A_TickCount / 700) * 8

    if (WebActive)
    {
        ; Anchor exactly at Spidy's free/dangling hand (the one facing down),
        ; per the SpidyHandFX/FY fractions set in CONFIG.
        wx := WebHeroX - VScreenX + SpidySway + SpidyImgW*(SpidyHandFX-0.5)
        wy := WebHeroY - VScreenY + SpidyImgH*SpidyHandFY
        tx2 := DragX - VScreenX
        ty2 := DragY - VScreenY

        ddx := tx2-wx, ddy := ty2-wy
        dist := Sqrt(ddx*ddx+ddy*ddy)
        if (dist < 1)
            dist := 1

        sag := dist*0.18
        if (sag > 55)
            sag := 55
        if (sag < 8)
            sag := 8

        perpx := -ddy/dist, perpy := ddx/dist

        ; -- how fast is the free end moving? a quick flick pumps energy
        ;    into the strand; it then rings and decays like a plucked rope --
        flickVX := DragX - PrevDragX, flickVY := DragY - PrevDragY
        flickSpeed := Sqrt(flickVX*flickVX + flickVY*flickVY)
        PrevDragX := DragX, PrevDragY := DragY

        elapsed := A_TickCount - WebImpulseTime
        decayedMag := WebImpulseMag * Exp(-elapsed/170)
        candidateMag := flickSpeed*0.85
        if (candidateMag > 26)
            candidateMag := 26

        if (candidateMag > decayedMag)
        {
            WebImpulseMag := candidateMag
            WebImpulseTime := A_TickCount
            elapsed := 0
        }

        envelope := WebImpulseMag * Exp(-elapsed/170)

        c1x := wx + ddx*0.33
        c1y := wy + ddy*0.33 + sag
        c2x := wx + ddx*0.66
        c2y := wy + ddy*0.66 + sag*0.6

        ; -- sample the strand into a polyline, adding the traveling wave --
        SampleCount := 16
        StrandPts := []
        waveSpeed := elapsed/38.0
        Loop, % SampleCount+1
        {
            t := (A_Index-1) / SampleCount
            u := 1-t
            bx := u*u*u*wx + 3*u*u*t*c1x + 3*u*t*t*c2x + t*t*t*tx2
            by := u*u*u*wy + 3*u*u*t*c1y + 3*u*t*t*c2y + t*t*t*ty2

            if (envelope > 0.25)
            {
                nearFree := t*Sqrt(t)                    ; 0 at anchor, 1 at free end
                wave := envelope * Sin(9.4*t + waveSpeed) * nearFree
                bx += perpx*wave
                by += perpy*wave
            }

            StrandPts.Push({x:bx, y:by})
        }

        pWebGlow := Gdip_CreatePen(0x30FFFFFF, 3.4)
        pWebCore := Gdip_CreatePen(0xE8F5F5F5, 1.3)
        Loop, % SampleCount
        {
            a := StrandPts[A_Index], b := StrandPts[A_Index+1]
            Gdip_DrawLine(G, pWebGlow, a.x, a.y, b.x, b.y)
            Gdip_DrawLine(G, pWebCore, a.x, a.y, b.x, b.y)
        }
        Gdip_DeletePen(pWebGlow)
        Gdip_DeletePen(pWebCore)

        Loop, 2
        {
            idx := Round(A_Index * (SampleCount/3))
            if (idx < 1)
                idx := 1
            if (idx > SampleCount+1)
                idx := SampleCount+1
            bpt := StrandPts[idx]
            pTick := Gdip_CreatePen(0x70F5F5F5, 0.9)
            Gdip_DrawLine(G, pTick, bpt.x-perpx*7, bpt.y-perpy*7, bpt.x+perpx*7, bpt.y+perpy*7)
            Gdip_DeletePen(pTick)
        }

        pSpark := Gdip_BrushCreateSolid(0xC0FFFFFF)
        Gdip_FillEllipse(G, pSpark, wx-3, wy-3, 6, 6)
        Gdip_DeleteBrush(pSpark)

        pStar := Gdip_CreatePen(0xD0FFFFFF, 1.3)
        Gdip_DrawLine(G, pStar, tx2-6, ty2, tx2+6, ty2)
        Gdip_DrawLine(G, pStar, tx2, ty2-6, tx2, ty2+6)
        Gdip_DrawLine(G, pStar, tx2-4, ty2-4, tx2+4, ty2+4)
        Gdip_DrawLine(G, pStar, tx2-4, ty2+4, tx2+4, ty2-4)
        Gdip_DeletePen(pStar)
    }

    ; ---- heroes ----
    DrawWebHero(G, WebHeroX - VScreenX, WebHeroY - VScreenY)
    DrawRocketHero(G, RocketHeroX - VScreenX, RocketHeroY - VScreenY)
    DrawCapHero(G, CapHeroX - VScreenX, CapHeroY - VScreenY)

    ; ---- hand-blast charge + beam ----
    handAbsX := RocketHeroX + 18
    handAbsY := RocketHeroY + 11

    if (HandChargeLife > 0)
    {
        chargeProg := 1 - (HandChargeLife/10)
        radius := 3 + chargeProg*10
        alpha := Round(80 + chargeProg*175)
        hlx := handAbsX - VScreenX, hly := handAbsY - VScreenY

        pChO := Gdip_BrushCreateSolid((Round(alpha*0.5)<<24)|0x99EEFF)
        Gdip_FillEllipse(G, pChO, hlx-radius*1.6, hly-radius*1.6, radius*3.2, radius*3.2)
        Gdip_DeleteBrush(pChO)

        pChC := Gdip_BrushCreateSolid((alpha<<24)|0xDFFBFF)
        Gdip_FillEllipse(G, pChC, hlx-radius, hly-radius, radius*2, radius*2)
        Gdip_DeleteBrush(pChC)

        HandChargeLife -= 1
        if (HandChargeLife = 0)
            HandBeamLife := 7
    }

    if (HandBeamLife > 0)
    {
        DrawBeam(G, handAbsX, handAbsY, HandTX, HandTY, HandBeamLife/7, 195)
        HandBeamLife -= 1
        if (HandBeamLife = 3)
        {
            SpawnFireBurst(HandTX, HandTY)
            Shockwaves.Push({x: HandTX, y: HandTY, life: 0, maxLife: 18, hue: 195})
        }
    }

    UpdateMissiles()
    UpdateShockwaves()
    UpdateSmashes()
    UpdatePortals()
    UpdateShields()
    UpdateParticles()

    UpdateLayeredWin(hwnd1, hdcMem, VScreenX, VScreenY, VScreenW, VScreenH)
return

;=====================================================================
; Twin missiles: launched by FireMissile(), advanced + drawn every frame
;=====================================================================
UpdateMissiles() {
    global Missiles, G, VScreenX, VScreenY, Shockwaves

    NewMissiles := []
    for index, m in Missiles
    {
        m.t += 1
        if (m.t <= 0)
        {
            NewMissiles.Push(m)
            continue
        }

        frac := m.t / m.totalFrames
        if (frac >= 1)
        {
            SpawnFireBurst(m.tx, m.ty)
            Shockwaves.Push({x: m.tx, y: m.ty, life: 0, maxLife: 18, hue: 15})
            continue
        }

        prevX := m.x, prevY := m.y

        ; -- DNA-style helix path: travel the straight line from launch to
        ;    target, but weave side-to-side around it several times. The
        ;    weave fades to zero at both ends so it launches cleanly off the
        ;    shoulder and lands cleanly on target, with a long, curvy flight
        ;    in between instead of one simple bulge. --
        baseX := m.sx + (m.tx-m.sx)*frac
        baseY := m.sy + (m.ty-m.sy)*frac
        envelope := m.ampl * Sin(3.14159265*frac)
        weave := envelope * Sin(frac*m.windings*6.2831853 + m.phase)
        m.x := baseX + m.perpx*weave
        m.y := baseY + m.perpy*weave

        dirx := m.x-prevX, diry := m.y-prevY
        dlen := Sqrt(dirx*dirx+diry*diry)
        if (dlen < 0.01) {
            ndx := 0, ndy := 1
        } else {
            ndx := dirx/dlen, ndy := diry/dlen
        }

        Loop, 5
        {
            back := A_Index*6
            Random, jitx, -3, 3
            Random, jity, -3, 3
            fx := m.x - ndx*back - VScreenX + jitx
            fy := m.y - ndy*back - VScreenY + jity
            fsize := 9 - A_Index*1.3
            if (fsize < 2)
                fsize := 2
            falpha := Round(190 - A_Index*32)
            if (falpha < 0)
                falpha := 0
            frgb := HSVtoRGB(Mod(8 + A_Index*6, 42), 95, 100)
            pF := Gdip_BrushCreateSolid((falpha<<24)|frgb)
            Gdip_FillEllipse(G, pF, fx-fsize/2, fy-fsize/2, fsize, fsize)
            Gdip_DeleteBrush(pF)
        }

        pHead := Gdip_BrushCreateSolid(0xFFFFE9A8)
        Gdip_FillEllipse(G, pHead, m.x-VScreenX-4, m.y-VScreenY-4, 8, 8)
        Gdip_DeleteBrush(pHead)

        NewMissiles.Push(m)
    }
    Missiles := NewMissiles
}

;=====================================================================
; Picks one of rocket-hero's two attacks toward (tx, ty)
;=====================================================================
FireMissile(tx, ty) {
    global Missiles, RocketHeroX, RocketHeroY
    global HandChargeLife, HandTX, HandTY

    Random, pick, 1, 2

    if (pick = 1)
    {
        HandTX := tx, HandTY := ty
        HandChargeLife := 10
        return
    }

    shL_x := RocketHeroX - 11, shL_y := RocketHeroY - 2
    shR_x := RocketHeroX + 11, shR_y := RocketHeroY - 2

    Random, sprA, -14, 14
    Random, sprB, -14, 14
    tAx := tx+sprA, tAy := ty+sprA
    tBx := tx+sprB, tBy := ty+sprB

    ; -- both missiles share the same winding count and are launched exactly
    ;    out of phase (0 vs half a turn), so the pair weaves around each
    ;    other's line like the two strands of a DNA helix, over a longer
    ;    flight than before --
    Random, windCommon, 3, 4
    Random, tfA, 55, 75
    Random, tfB, 55, 75
    Random, ampA, 55, 95
    Random, ampB, 55, 95

    perpA := PerpAxis(shL_x, shL_y, tAx, tAy)
    perpB := PerpAxis(shR_x, shR_y, tBx, tBy)

    mA := { sx: shL_x, sy: shL_y, tx: tAx, ty: tAy
          , perpx: perpA.x, perpy: perpA.y, ampl: ampA, windings: windCommon, phase: 0
          , x: shL_x, y: shL_y, t: 0, totalFrames: tfA }
    mB := { sx: shR_x, sy: shR_y, tx: tBx, ty: tBy
          , perpx: perpB.x, perpy: perpB.y, ampl: ampB, windings: windCommon, phase: 3.14159265
          , x: shR_x, y: shR_y, t: -6, totalFrames: tfB }

    Missiles.Push(mA)
    Missiles.Push(mB)
}

; Unit vector perpendicular to the sx,sy -> tx,ty line, used as the axis the
; missile weaves side-to-side across on its way to the target.
PerpAxis(sx, sy, tx, ty) {
    dx := tx-sx, dy := ty-sy
    dlen := Sqrt(dx*dx+dy*dy)
    if (dlen < 1)
        dlen := 1
    return {x: -dy/dlen, y: dx/dlen}
}

;=====================================================================
; Expanding shockwave rings (spawned by every explosion)
;=====================================================================
UpdateShockwaves() {
    global Shockwaves, G, VScreenX, VScreenY

    NewSW := []
    for index, s in Shockwaves
    {
        s.life += 1
        if (s.life >= s.maxLife)
            continue

        prog := s.life / s.maxLife
        radius := 75 * prog
        alpha := Round(210 * (1 - prog))
        rgb := HSVtoRGB(s.hue, 85, 100)
        argb := (alpha << 24) | rgb

        pPen := Gdip_CreatePen(argb, 3)
        cx2 := s.x - VScreenX, cy2 := s.y - VScreenY
        Gdip_DrawEllipse(G, pPen, cx2-radius, cy2-radius, radius*2, radius*2)
        Gdip_DeletePen(pPen)

        NewSW.Push(s)
    }
    Shockwaves := NewSW
}

;=====================================================================
; Hulk Smash: jagged ground cracks radiating from the impact point,
; with a green energy flash and flying rock debris (right-click)
;=====================================================================
TriggerHulkSmash(cx, cy) {
    global Smashes, Shockwaves, Particles

    cracks := []
    Loop, 7
    {
        baseAng := (360/7)*A_Index
        Random, angJit, -18, 18
        Random, len1, 55, 95
        ang := baseAng + angJit
        rad := ang * 0.0174533
        Random, bend, -16, 16
        perpAng := rad + 1.5708
        midX := Cos(rad)*(len1*0.5) + Cos(perpAng)*bend
        midY := Sin(rad)*(len1*0.5) + Sin(perpAng)*bend
        endX := Cos(rad)*len1
        endY := Sin(rad)*len1
        cracks.Push({mx:midX, my:midY, ex:endX, ey:endY})
    }
    Smashes.Push({x:cx, y:cy, life:0, maxLife:34, cracks:cracks})

    Particles.Push({type:7, life:0, maxLife:8, x:cx, y:cy, size0:70})

    Loop, 10
    {
        Random, ox, -14, 14
        Random, oy, -6, 6
        Random, vx1, -22, 22
        Random, vy1, -55, -15
        Particles.Push({type:6, life:0, maxLife:55, x:cx+ox, y:cy+oy, vx:vx1/100, vy:vy1/100})
    }

    Loop, 14
    {
        Random, spd, 140, 320
        Random, ang2, 0, 359
        Random, sz0, 5, 11
        rad2 := ang2*0.0174533
        Particles.Push({type:8, life:0, maxLife:46, x:cx, y:cy
            , vx: Cos(rad2)*spd/100, vy: Sin(rad2)*spd/100 - 2.4, size0: sz0})
    }

    Shockwaves.Push({x:cx, y:cy, life:0, maxLife:24, hue:120})
}

UpdateSmashes() {
    global Smashes, G, VScreenX, VScreenY

    NewSmashes := []
    for index, sm in Smashes
    {
        sm.life += 1
        if (sm.life >= sm.maxLife)
            continue

        prog := sm.life / sm.maxLife
        growProg := sm.life / 8
        if (growProg > 1)
            growProg := 1
        fadeProg := 1
        if (prog > 0.55)
            fadeProg := 1 - (prog-0.55)/0.45
        if (fadeProg < 0)
            fadeProg := 0

        alpha := Round(220 * fadeProg)
        cx2 := sm.x - VScreenX, cy2 := sm.y - VScreenY

        for i2, ck in sm.cracks
        {
            mx := cx2 + ck.mx*growProg, my := cy2 + ck.my*growProg
            ex := cx2 + ck.ex*growProg, ey := cy2 + ck.ey*growProg

            pGlow := Gdip_CreatePen((Round(alpha*0.45)<<24)|0x33CC33, 5)
            Gdip_DrawLine(G, pGlow, cx2, cy2, mx, my)
            Gdip_DrawLine(G, pGlow, mx, my, ex, ey)
            Gdip_DeletePen(pGlow)

            pCore := Gdip_CreatePen((alpha<<24)|0x1A1A1A, 2)
            Gdip_DrawLine(G, pCore, cx2, cy2, mx, my)
            Gdip_DrawLine(G, pCore, mx, my, ex, ey)
            Gdip_DeletePen(pCore)
        }

        NewSmashes.Push(sm)
    }
    Smashes := NewSmashes
}

;=====================================================================
; Doctor Strange portal: opens, spins, closes (side button 1)
;=====================================================================
TriggerPortal(cx, cy) {
    global Portals
    Portals.Push({x:cx, y:cy, life:0, maxLife:46})
}

UpdatePortals() {
    global Portals, G, VScreenX, VScreenY

    NewPortals := []
    for index, p in Portals
    {
        p.life += 1
        if (p.life >= p.maxLife)
            continue

        prog := p.life / p.maxLife
        radius := 42 * Sin(prog * 3.14159265)
        if (radius < 1)
            radius := 1
        spin := A_TickCount / 9

        cx2 := p.x - VScreenX, cy2 := p.y - VScreenY

        pOuterGlow := Gdip_CreatePen(0x40FF7A00, 8)
        Gdip_DrawEllipse(G, pOuterGlow, cx2-radius, cy2-radius, radius*2, radius*2)
        Gdip_DeletePen(pOuterGlow)

        pRing := Gdip_CreatePen(0xE0FFA940, 2.4)
        Gdip_DrawEllipse(G, pRing, cx2-radius*0.86, cy2-radius*0.86, radius*1.72, radius*1.72)
        Gdip_DeletePen(pRing)

        pCore := Gdip_BrushCreateSolid(0x50FFD37A)
        Gdip_FillEllipse(G, pCore, cx2-radius*0.5, cy2-radius*0.5, radius, radius)
        Gdip_DeleteBrush(pCore)

        Loop, 8
        {
            tAng := spin + (360/8)*A_Index
            rad3 := tAng * 0.0174533
            sxp := cx2 + Cos(rad3)*radius
            syp := cy2 + Sin(rad3)*radius
            exp2 := cx2 + Cos(rad3)*(radius*1.28)
            eyp := cy2 + Sin(rad3)*(radius*1.28)
            pTick := Gdip_CreatePen(0xC0FFC066, 1.6)
            Gdip_DrawLine(G, pTick, sxp, syp, exp2, eyp)
            Gdip_DeletePen(pTick)
        }

        NewPortals.Push(p)
    }
    Portals := NewPortals
}

;=====================================================================
; Thanos snap: dust/ash disintegration burst (side button 2)
;=====================================================================
TriggerSnap(cx, cy) {
    global Particles

    Particles.Push({type:7, life:0, maxLife:6, x:cx, y:cy, size0:40})

    Loop, 40
    {
        Random, ox, -34, 34
        Random, oy, -34, 34
        Random, vx1, -18, 18
        Random, vy1, -55, -8
        Random, sz, 2, 5
        Particles.Push({type:9, life:0, maxLife:70, x:cx+ox, y:cy+oy
            , vx: vx1/100, vy: vy1/100, size: sz})
    }
}

;=====================================================================
; Captain America's shield: thrown from Cap's position toward the
; target, then loops back on a different curve (right-click)
;=====================================================================
FireShield(tx, ty) {
    global Shields, CapHeroX, CapHeroY, CapImgH

    ; Only one shield in flight at a time -- a second right-click while it's
    ; still out is simply ignored, like Cap has to catch it first.
    if (Shields.Length() > 0)
        return

    sx := CapHeroX, sy := CapHeroY - CapImgH*0.55

    dx := tx-sx, dy := ty-sy
    dlen := Sqrt(dx*dx+dy*dy)
    if (dlen < 1)
        dlen := 1
    perpx := -dy/dlen, perpy := dx/dlen

    ; Outbound bulges one way, the return bulges the OTHER way, so instead of
    ; retracing the same arc it traces a wide open loop, like a real thrown
    ; boomerang rather than a there-and-back line.
    Random, curveOut, 70, 120
    Random, curveBack, 70, 120
    curveBack := -curveBack

Shields.Push({sx:sx, sy:sy, tx:tx, ty:ty, t:0, totalOut:18, totalBack:18, phase:1
        , perpx:perpx, perpy:perpy, curveOut:curveOut, curveBack:curveBack})
}

UpdateShields() {
    global Shields, G, VScreenX, VScreenY, Particles

    NewShields := []
    for index, sh in Shields
    {
        sh.t += 1

        if (sh.phase = 1)
        {
            frac := sh.t / sh.totalOut
            if (frac >= 1)
            {
                sh.phase := 2
                sh.t := 0
                Particles.Push({type:7, life:0, maxLife:6, x:sh.tx, y:sh.ty, size0:26})
                NewShields.Push(sh)
                continue
            }
            u := 1-frac
            midX := (sh.sx+sh.tx)/2 + sh.perpx*sh.curveOut
            midY := (sh.sy+sh.ty)/2 + sh.perpy*sh.curveOut - 55
            px := u*u*sh.sx + 2*u*frac*midX + frac*frac*sh.tx
            py := u*u*sh.sy + 2*u*frac*midY + frac*frac*sh.ty
        }
        else
        {
            frac := sh.t / sh.totalBack
            if (frac >= 1)
                continue
            u := 1-frac
            midX := (sh.tx+sh.sx)/2 + sh.perpx*sh.curveBack
            midY := (sh.ty+sh.sy)/2 + sh.perpy*sh.curveBack - 55
            px := u*u*sh.tx + 2*u*frac*midX + frac*frac*sh.sx
            py := u*u*sh.ty + 2*u*frac*midY + frac*frac*sh.sy
        }

        DrawShieldDisc(G, px-VScreenX, py-VScreenY, A_TickCount/4)
        NewShields.Push(sh)
    }
    Shields := NewShields
}

DrawShieldDisc(pGraphics, x, y, spinDeg) {
    r := 15

    pOuter := Gdip_BrushCreateSolid(0xFFB1181F)
    Gdip_FillEllipse(pGraphics, pOuter, x-r, y-r, r*2, r*2)
    Gdip_DeleteBrush(pOuter)

    pWhite := Gdip_BrushCreateSolid(0xFFEDEDED)
    Gdip_FillEllipse(pGraphics, pWhite, x-r*0.76, y-r*0.76, r*1.52, r*1.52)
    Gdip_DeleteBrush(pWhite)

    pRed2 := Gdip_BrushCreateSolid(0xFFB1181F)
    Gdip_FillEllipse(pGraphics, pRed2, x-r*0.55, y-r*0.55, r*1.1, r*1.1)
    Gdip_DeleteBrush(pRed2)

    pBlue := Gdip_BrushCreateSolid(0xFF3A4E9C)
    Gdip_FillEllipse(pGraphics, pBlue, x-r*0.34, y-r*0.34, r*0.68, r*0.68)
    Gdip_DeleteBrush(pBlue)

    starPts := []
    Loop, 5
    {
        outAng := spinDeg - 90 + (72*(A_Index-1))
        inAng  := outAng + 36
        outRad := outAng*0.0174533, inRad := inAng*0.0174533
        starPts.Push({x: x+Cos(outRad)*r*0.3, y: y+Sin(outRad)*r*0.3})
        starPts.Push({x: x+Cos(inRad)*r*0.12, y: y+Sin(inRad)*r*0.12})
    }
    pStar := Gdip_BrushCreateSolid(0xFFF2F2F2)
    Gdip_FillPolygon(pGraphics, pStar, starPts)
    Gdip_DeleteBrush(pStar)
}

;=====================================================================
; Web-hero: drawn from spidy.png, gently swaying at top-center
;=====================================================================
DrawWebHero(pGraphics, x, y) {
    global pImgSpidy, SpidyImgW, SpidyImgH, SpidySway

    if (!pImgSpidy)
        return

    hx := x + SpidySway

    Gdip_DrawImageRect(pGraphics, pImgSpidy, hx - SpidyImgW/2, y, SpidyImgW, SpidyImgH)
}

;=====================================================================
; Cap-hero: drawn from cap.png, standing bottom-left near the Start button
;=====================================================================
DrawCapHero(pGraphics, x, y) {
    global pImgCap, CapImgW, CapImgH

    if (!pImgCap)
        return

    Gdip_DrawImageRect(pGraphics, pImgCap, x - CapImgW/2, y - CapImgH, CapImgW, CapImgH)
}

;=====================================================================
; Rocket-hero: drawn from iron.png, softly bobbing bottom-right
;=====================================================================
DrawRocketHero(pGraphics, x, y) {
    global pImgIron, RocketImgW, RocketImgH, RocketAnchorFY

    if (!pImgIron)
        return

    bob := Sin(A_TickCount / 500) * 4
    drawX := x - RocketImgW/2
    drawY := y - RocketImgH*RocketAnchorFY + bob

    Gdip_DrawImageRect(pGraphics, pImgIron, drawX, drawY, RocketImgW, RocketImgH)
}

;=====================================================================
; Advance + draw every active particle (fire, smoke, flash, debris, ash)
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

        if (p.type = 5) {
            ; FIRE — layered glow+core, shrinking, embers falling as they cool
            p.spd *= 0.95
            p.x += Cos(p.ang * 0.0174533) * p.spd
            p.y += Sin(p.ang * 0.0174533) * p.spd + (prog*2.2)
            sz := p.size0 * (1 - prog*0.55)
            if (sz < 1)
                sz := 1

            outerRgb := HSVtoRGB(Mod(6 + p.life*2, 40), 95, 100)
            outerAlpha := Round(150*(1-prog))
            pOuter := Gdip_BrushCreateSolid((outerAlpha<<24)|outerRgb)
            Gdip_FillEllipse(G, pOuter, p.x-VScreenX-sz, p.y-VScreenY-sz, sz*2, sz*2)
            Gdip_DeleteBrush(pOuter)

            innerRgb := HSVtoRGB(Mod(30 + p.life*2, 55), 55, 100)
            innerAlpha := Round(255*(1-prog))
            pInner := Gdip_BrushCreateSolid((innerAlpha<<24)|innerRgb)
            Gdip_FillEllipse(G, pInner, p.x-VScreenX-sz*0.5, p.y-VScreenY-sz*0.5, sz, sz)
            Gdip_DeleteBrush(pInner)

        } else if (p.type = 6) {
            ; SMOKE — slow rising, growing, soft fade-in-then-out
            p.x += p.vx
            p.y += p.vy
            p.vy += 0.01
            sz := 6 + prog*18
            alpha := Round(85 * Sin(prog * 3.14159265))
            if (alpha < 0)
                alpha := 0
            pSm := Gdip_BrushCreateSolid((alpha<<24) | 0x5B5450)
            Gdip_FillEllipse(G, pSm, p.x-VScreenX-sz/2, p.y-VScreenY-sz/2, sz, sz)
            Gdip_DeleteBrush(pSm)

        } else if (p.type = 7) {
            ; FLASH — brief bright pop at the moment of impact
            sz := p.size0 * (1 - prog)
            alpha := Round(255*(1-prog))
            pFl := Gdip_BrushCreateSolid((alpha<<24) | 0xFFF3C0)
            Gdip_FillEllipse(G, pFl, p.x-VScreenX-sz/2, p.y-VScreenY-sz/2, sz, sz)
            Gdip_DeleteBrush(pFl)

        } else if (p.type = 8) {
            ; HULK DEBRIS — flying rock chunks, pulled down by gravity
            p.vy += 0.16
            p.x += p.vx
            p.y += p.vy
            sz := p.size0 * (1 - prog*0.3)
            alpha := Round(230*(1-prog))
            rgb := HSVtoRGB(Mod(95 + p.life, 40), 35, 45)
            pD := Gdip_BrushCreateSolid((alpha<<24)|rgb)
            Gdip_FillEllipse(G, pD, p.x-VScreenX-sz/2, p.y-VScreenY-sz/2, sz, sz)
            Gdip_DeleteBrush(pD)

        } else if (p.type = 9) {
            ; THANOS SNAP — ash motes drifting up and dissolving
            p.x += p.vx
            p.y += p.vy
            p.vy -= 0.006
            alpha := Round(200 * Sin(prog * 3.14159265))
            if (alpha < 0)
                alpha := 0
            rgb := HSVtoRGB(Mod(28 + p.life, 30), 70, 100)
            pA := Gdip_BrushCreateSolid((alpha<<24)|rgb)
            Gdip_FillEllipse(G, pA, p.x-VScreenX-p.size/2, p.y-VScreenY-p.size/2, p.size, p.size)
            Gdip_DeleteBrush(pA)
        }

        NewParticles.Push(p)
    }
    Particles := NewParticles
}

;=====================================================================
; Spawn a full explosion (flash + fire chunks + rising smoke) at (cx, cy)
;=====================================================================
SpawnFireBurst(cx, cy) {
    global Particles, ExplosionCount

    Particles.Push({type:7, life:0, maxLife:5, x:cx, y:cy, size0:46})

    Loop, %ExplosionCount%
    {
        Random, spd, 220, 480
        Random, sz0, 9, 15
        Particles.Push({type:5, life:0, maxLife:34, x:cx, y:cy
            , ang:(360/ExplosionCount)*A_Index, spd:spd/40, size0:sz0})
    }

    Loop, 8
    {
        Random, ox, -10, 10
        Random, oy, -10, 10
        Random, vx1, -30, 30
        Random, vy1, -90, -40
        Particles.Push({type:6, life:0, maxLife:50, x:cx+ox, y:cy+oy
            , vx:vx1/100, vy:vy1/100})
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
; Straight glowing energy beam (used by the hand-blast attack)
;=====================================================================
DrawBeam(pGraphics, x1, y1, x2, y2, lifeFrac, hue) {
    global VScreenX, VScreenY

    sx := x1-VScreenX, sy := y1-VScreenY
    ex := x2-VScreenX, ey := y2-VScreenY

    alpha := Round(230*lifeFrac)

    glowArgb := (Round(alpha*0.35)<<24) | HSVtoRGB(hue,80,100)
    pGlow := Gdip_CreatePen(glowArgb, 9)
    Gdip_DrawLine(pGraphics, pGlow, sx,sy, ex,ey)
    Gdip_DeletePen(pGlow)

    coreArgb := (alpha<<24) | HSVtoRGB(hue, 30, 100)
    pCore := Gdip_CreatePen(coreArgb, 3)
    Gdip_DrawLine(pGraphics, pCore, sx,sy, ex,ey)
    Gdip_DeletePen(pCore)
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
    DllCall("gdiplus\GdipSetPenStartCap", "Ptr", pPen, "Int", 2)
    DllCall("gdiplus\GdipSetPenEndCap", "Ptr", pPen, "Int", 2)
    return pPen
}

Gdip_DeletePen(pPen) {
    DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
}

Gdip_DrawLine(pGraphics, pPen, x1, y1, x2, y2) {
    DllCall("gdiplus\GdipDrawLine", "Ptr", pGraphics, "Ptr", pPen, "Float", x1, "Float", y1, "Float", x2, "Float", y2)
}

Gdip_DrawBezier(pGraphics, pPen, x1, y1, x2, y2, x3, y3, x4, y4) {
    DllCall("gdiplus\GdipDrawBezier", "Ptr", pGraphics, "Ptr", pPen
        , "Float", x1, "Float", y1, "Float", x2, "Float", y2
        , "Float", x3, "Float", y3, "Float", x4, "Float", y4)
}

Gdip_DrawEllipse(pGraphics, pPen, x, y, w, h) {
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGraphics, "Ptr", pPen, "Float", x, "Float", y, "Float", w, "Float", h)
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

Gdip_LoadImageFromFile(filename) {
    DllCall("gdiplus\GdipLoadImageFromFile", "WStr", filename, "PtrP", pImg)
    return pImg
}

Gdip_GetImageWidth(pImg) {
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pImg, "UIntP", w)
    return w
}

Gdip_GetImageHeight(pImg) {
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pImg, "UIntP", h)
    return h
}

Gdip_DrawImageRect(pGraphics, pImg, x, y, w, h) {
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pGraphics, "Ptr", pImg
        , "Int", Round(x), "Int", Round(y), "Int", Round(w), "Int", Round(h))
}

Gdip_DisposeImage(pImg) {
    if (pImg)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pImg)
}

Gdip_FillPolygon(pGraphics, pBrush, points) {
    cnt := points.Length()
    VarSetCapacity(buf, cnt*8, 0)
    Loop, %cnt%
    {
        NumPut(points[A_Index].x, buf, (A_Index-1)*8, "Float")
        NumPut(points[A_Index].y, buf, (A_Index-1)*8+4, "Float")
    }
    DllCall("gdiplus\GdipFillPolygon", "Ptr", pGraphics, "Ptr", pBrush, "Ptr", &buf, "Int", cnt, "Int", 0)
}

; Blits the DIB in hdc onto the layered window hwnd with per-pixel alpha
UpdateLayeredWin(hwnd, hdc, x, y, w, h) {
    VarSetCapacity(pt, 8, 0)
    NumPut(x, pt, 0, "Int")
    NumPut(y, pt, 4, "Int")

    VarSetCapacity(sz, 8, 0)
    NumPut(w, sz, 0, "Int")
    NumPut(h, sz, 4, "Int")

    VarSetCapacity(ptSrc, 8, 0)

    VarSetCapacity(blend, 4, 0)
    NumPut(0, blend, 0, "Char")
    NumPut(0, blend, 1, "Char")
    NumPut(255, blend, 2, "Char")
    NumPut(1, blend, 3, "Char")

    DllCall("UpdateLayeredWindow"
        , "Ptr", hwnd
        , "Ptr", 0
        , "Ptr", &pt
        , "Ptr", &sz
        , "Ptr", hdc
        , "Ptr", &ptSrc
        , "UInt", 0
        , "Ptr", &blend
        , "UInt", 2)
}

;=====================================================================
; Hotkeys — the leading ~ lets the click still work normally
;=====================================================================
~LButton::
    MouseGetPos, cx, cy
    DownX := cx, DownY := cy
    DownTime := A_TickCount
    DragCandidate := true
    IsDragging := false
return

~LButton Up::
    MouseGetPos, ux, uy
    DragCandidate := false

    if (IsDragging)
    {
        IsDragging := false
        WebActive := false
    }
    else
    {
        now := A_TickCount
        ddx := ux - LastClickX, ddy := uy - LastClickY
        dist := Sqrt(ddx*ddx + ddy*ddy)
        if (LastClickTime && (now - LastClickTime) < DoubleClickMS && dist < DoubleClickDist)
        {
            FireMissile(ux, uy)
            LastClickTime := 0
        }
        else
        {
            LastClickTime := now
            LastClickX := ux
            LastClickY := uy
        }
    }
return

~RButton::
    MouseGetPos, cx, cy
    FireShield(cx, cy)
return

~MButton::
    MouseGetPos, cx, cy
    TriggerHulkSmash(cx, cy)
return

~XButton1::
    MouseGetPos, cx, cy
    TriggerPortal(cx, cy)
return

~XButton2::
    MouseGetPos, cx, cy
    TriggerSnap(cx, cy)
return

^!x::ExitApp  ; Ctrl+Alt+X to quit the script

;=====================================================================
; Cleanup on exit
;=====================================================================
ShowAbout:
    MsgBox, 64, About Cursor Lab, Cursor Lab - Marvel Desktop Buddies`nMade by Digraj`nhttps://github.com/digraj666-max
return
CleanUp:
    Gdip_DisposeImage(pImgIron)
    Gdip_DisposeImage(pImgSpidy)
    Gdip_DisposeImage(pImgCap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", G)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
    DllCall("DeleteObject", "Ptr", hbmMem)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", pToken)
    ExitApp
return
