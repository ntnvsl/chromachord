keymap := ( ; kbdlayout.info/KBDUSX/scancodes
  "10 1E 2C 11 1F 2D 12 20  2E 13 21  2F "
  "14 22 30 15 23 31 16 24  32 17 25  33 "
  "18 26 34 19 27 35 1A 28 136 1B 2B 148 "
  "1C 4B 50 47 4C 51 48 4D  4F 49 52 11C "
)

      Pause::A.isOn := !A.isOn, tip()
        Esc::ExitApp()
#HotIf A.isOn
         F3::strum(False), A.midiChannel -= A.midiChannel > 0, tip()
         F4::strum(False), A.midiChannel += A.midiChannel < 15, tip()
        ^F3::A.midiPort -= A.midiPort > 0, Reload()
        ^F4::A.midiPort += A.midiPort < 63, Reload()
         F6::A.velocityA -= 10 * (A.velocityA > 0), tip()
         F7::A.velocityA += 10 * (A.velocityA < 100), tip()
        !F6::A.velocityB -= 10 * (A.velocityB > 0), tip()
        !F7::A.velocityB += 10 * (A.velocityB < 100), tip()
        F11::transpose(-1), tip()
        F12::transpose(+1), tip()
 ScrollLock::A.bendSplit := A.bendSplit = 2 ? 12 : 2, tip()
       SC29::pedal(False), tip()
       2 Up::bend(-2,, 4, True), strum(False), DllCall("Sleep",u,175), pitch(0)
          3::
          4::strum()
          5::
          6::
          7::
          8::midi(0xB0, 20 + A_ThisHotkey, 127)
          9::
          0::strum()
          -::modulation(-10 * (A.cc1 > 0)), tip()
          =::modulation(+10 * (A.cc1 < 100)), tip()
      BS Up::(Z.anyKey) || (modulation(), pedal())
          1::(A.isBend) ? bend(+2)       : False
       1 Up::(A.isBend) ? bend(-2, True) : False
        Tab::(A.isBend) ? bend(+1)       : (transpose(+12), tip())
     Tab Up::(A.isBend) ? bend(-1, True) : False
   CapsLock::(A.isBend) ? bend(-1)       : (transpose(-12), tip())
CapsLock Up::(A.isBend) ? bend(+1, True) : False
     LShift::(A.isBend) ? bend(-2)       : False
  LShift Up::(A.isBend) ? bend(+2, True) : False
   Space Up::(Z.isSpace) || strum(False)
       RAlt::A.isHold := !A.isHold, tip()
     <!RAlt::A.isLatch := !A.isLatch, tip()
    AppsKey::A.isBend := !A.isBend, tip()
  <!AppsKey::A.isChords := !A.isChords
       Left::transpose(-12), tip()
      Right::transpose(+12), tip()
       Down::tip()
#HotIf

#SingleInstance
A_HotkeyInterval := 0
KeyHistory(0)
ListLines(False)
OnExit(exit)

A := {
  isOn: True,
  isHold: False,
  isLatch: False,
  isBend: True,
  isChords: True,
  midiPort: 0,
  midiChannel: 0,
  bendSplit: 2,
  startNote: 39,
  velocityA: 90,
  velocityB: 70,
  cc1: 0,
  cc64: 0,
}

Z := {
  anyKey: 0,
  isSpace: False,
}

heldKeys := Map()
susKeys := Map()
susMidi := Map()

regKey := "HKCU\Software\" StrSplit(A_ScriptName, ".")[1]
for p in A.OwnProps()
  try A.%p% := RegRead(regKey, p)

winMM := DllCall("LoadLibrary", "Str", "winmm")
DllCall("winmm\midiOutOpen", (u:="UInt") "*", &midiOut:=False, u, A.midiPort,
        u,0,u,0,u,0)

modulation()
pedal()

HotIf((*) => A.isOn)

for scanCode in StrSplit(Trim(RegExReplace(keymap, "\s+", " ")), " ") {
  Hotkey("SC" scanCode, key.Bind(A_Index, True))
  Hotkey("SC" scanCode " Up", key.Bind(A_Index, False))
  heldKeys[A_Index] := False
}

tip()

key(k, isDown, *) {
  if isDown {
    if heldKeys[k]
      return
    heldKeys[k] := True
    if A.isHold && A.isLatch && !Z.anyKey
      strum(False)
    Z.anyKey++
    susKeys[k] := A.startNote
    note := susKeys[k--] + k
    if susMidi.Has(note)
      play(-note)
    play(note)
    susMidi[note] := note
  }
  else {
    heldKeys[k] := False
    if !Z.anyKey || !susKeys.Has(k)
      return
    Z.anyKey--
    if A.isHold {
      if !A.isLatch && !Z.anyKey
        strum(False)
      return
    }
    note := susKeys.Delete(k--) + k
    play(-note)
    if susMidi.Has(note)
      susMidi.Delete(note)
  }
  if A.isChords
    chords()
}

play(note) {
  Z.isSpace := GetKeyState("Space", "P")
  isBackspace := GetKeyState("BS", "P")
  velocity := isBackspace ? 100 : Z.isSpace ? A.velocityB : A.velocityA
  midi(0x90, Abs(note), (note > 0) * Round(velocity / 100 * 127))
}

strum(letRing:=True) {
  for note in susMidi {
    play(-note)
    if letRing
      play(note)
  }
  if !letRing {
    Z.anyKey := 0
    susKeys.Clear()
    susMidi.Clear()
  }
  if A.isChords
    chords()
}

bend(offset, isReturn:=False, stepDelay:=2, isSlideDown:=False) {
  Critical(-1)
  delta := 8192 / (isSlideDown ? 2 : A.bendSplit) * offset
  target := Round(8192 + delta * !isReturn, 1)
  step := delta / 20
  while offset > 0 ? pitch() < target : pitch() > target {
    pitch(step)
    DllCall("Sleep", u, stepDelay)
  }
  if A.bendSplit != 2 && isReturn && pitch()
    pitch(0)
}

pitch(value?) {
  static stored := 8192
  if IsSet(value) {
    stored := !value ? 8192 : stored + value
    stored := stored < 0 ? 0 : stored > 16384 ? 16384 : Round(stored, 1)
    new := Round(stored) - (stored = 16384)
    midi(0xE0, new & 0x7F, (new >> 7) & 0x7F)
  }
  return stored
}

midi(statusByte, dataByte1, dataByte2) {
  DllCall("winmm\midiOutShortMsg", u, midiOut, u,
          statusByte | A.midiChannel | dataByte1 << 8 | dataByte2 << 16)
}

modulation(value:=0) {
  A.cc1 += value
  midi(0xB0, 1, Round(A.cc1 / 100 * 127))
}

pedal(isInit:=True) {
  A.cc64 := isInit ? A.cc64 : 127 * !A.cc64
  midi(0xB0, 64, A.cc64)
}

transpose(offset) {
  semitones := Abs(offset)
  A.startNote += semitones * (
    offset > 0
      ? A.startNote + semitones + heldKeys.Count < 127
      : -(A.startNote >= semitones)
  )
}

tip() {
  static state := 2
  if state != A.isOn {
    state := A.isOn
    TraySetIcon("imageres.dll", 101 + state)
  }
  velocity := A.velocityA "/" A.velocityB
  port := A.midiPort ":" (A.midiChannel + 1)
  mode := A.isLatch ? "latch" : "hold"
  hold := A.isHold ? "✅" : "❌"
  bend := A.isBend ? "✅" : "❌"
  pedal := A.cc64 ? "✅" : "❌"
  TrayTip(
    A.isOn ? (
      abc(A.startNote) " ● v" velocity " ● port " port "`n"
      mode " " hold " bend " A.bendSplit " " bend "`n"
      "mod " A.cc1 " ● pedal " pedal
    ) : ""
  )
}

abc(note, isOctave:=True) {
  static names := StrSplit("C C♯ D E♭ E F F♯ G A♭ A B♭ B", " ")
  return names[Mod(note, 12) + 1] (isOctave ? note // 12 - 1 : "")
}

chords() {
  static pitches := StrSplit("n1 b2 n2 b3 n3 n4 b5 n5 b6 n6 b7 n7", " ")
  chord := []
  octaves := Map()
  for noteX in susMidi {
    for noteY in susMidi
      if noteY > noteX && !Mod(noteY - noteX, 12)
        octaves[noteY] := True
    if !octaves.Has(noteX)
      chord.Push(noteX)
  }
  text := ""
  loop chord.Length {
    n1:=b2:=n2:=b3:=n3:=n4:=b5:=n5:=b6:=n6:=b7:=n7 := False
    for note in chord
      %pitches[Mod(Abs(note - chord[1]), 12) + 1]% := True
    mi3 := b3 && !n3
    no3 := !b3 && !n3 && n5
    aug := !b3 && n3 && !n5 && b6
    dim := mi3 && b5 && !n5 && !n7
    dim7 := dim && n6
    hdim := dim && !n6 && b7
    sus2 := no3 && n2 && !n4
    sus4 := no3 && !n2 && n4
    is5 := no3 && chord.Length = 2
    is6 := !dim && n6
    is7 := !dim && (b7 || n7)
    is9 := !sus2 && n2
    is11 := !sus4 && n4
    text .= (
      abc(chord[1], False)
      (is5? 5 : aug? "+" : hdim? "ø" : dim7? "⁰7" : dim? "⁰" : mi3? "m" : "")
      (!is7 && is6 ? 6 : "")
      (n7 ? "maj" : "")
      (is7 ? is6 ? 13 : is11 ? 11 : is9 ? 9 : 7 : "")
      (sus2 ? "sus2" : sus4 ? "sus4" : "")
      (" " StrReplace(
        (b2 ? "(♭9)" : "")
        (!is7 && is9 ? "(9)" : "")
        (b3 && n3 ? "(♯9)" : "")
        (!is7 && is11 ? "(11)" : "")
        (!dim && b5 ? "(" (n5 ? "♯11" : "♭5") ")" : "")
        (!aug && b6 ? "(" (n5 ? "♭13" : "♯5") ")" : "")
        (b7 && (n7 || dim7) ? "(♭7)" : "")
        , ")(", ", "
      )) "`n"
    )
    while chord[1] < chord[chord.Length]
      chord[1] += 12
    chord.Push(chord.RemoveAt(1))
  }
  ToolTip(text)
}

exit(*) {
  for p in A.OwnProps()
    RegWrite(A.%p%, "REG_SZ", regKey, p)
  DllCall("winmm\midiOutReset", u, midiOut)
  DllCall("winmm\midiOutClose", u, midiOut)
  DllCall("FreeLibrary", u, winMM)
  ExitApp()
}