#!/usr/bin/env pwsh

# Force an external monitor's resolution when Windows can't read its EDID.
#
# Symptom: the monitor shows up as "Generic Monitor" (DISPLAY\MS_0001) stuck at
# 640x480, because the EDID never makes it through the cable/dock (seen with a
# Surface Dock 2 -> USB-C to DP cable -> Dell P2720D). The real fix is a better
# cable; this is the workaround.
#
#   .\display.ps1                       # show current mode for the display
#   .\display.ps1 -W 2560 -H 1440       # force 2560x1440@60 (no admin needed)
#   .\display.ps1 -Edid                 # (admin) write a Dell P2720D EDID override
#                                       #   onto the Generic Monitor, restart the GPU
#   .\display.ps1 -RemoveEdid           # (admin) delete the override
#
# The NVIDIA driver still only lists 640x480 even with the override, but it
# accepts a forced mode. Don't touch the resolution in Display Settings or it
# drops back to 640x480; rerun this instead.

param(
  [string]$Device = '\\.\DISPLAY2',
  [int]$W = 0,
  [int]$H = 0,
  [int]$Hz = 60,
  [switch]$Edid,
  [switch]$RemoveEdid
)

$ErrorActionPreference = 'Stop'

function Assert-Admin
{
  if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
  {
    Write-Error "Please run as administrator"
  }
}

function Get-GenericMonitorKey
{
  $inst = Get-PnpDevice -Class Monitor -PresentOnly | Where-Object InstanceId -like 'DISPLAY\MS_0001\*' | Select-Object -First 1
  if (-not $inst)
  { Write-Error "No 'Generic Monitor' (DISPLAY\MS_0001) present; the real EDID may be getting through now."
  }
  "HKLM:\SYSTEM\CurrentControlSet\Enum\$($inst.InstanceId)\Device Parameters\EDID_OVERRIDE"
}

function Restart-Gpu
{
  $gpu = Get-PnpDevice -Class Display -PresentOnly | Where-Object FriendlyName -match 'NVIDIA'
  if ($gpu)
  { pnputil /restart-device "$($gpu.InstanceId)" | Out-Null; Start-Sleep 10
  }
}

if ($Edid -or $RemoveEdid)
{
  Assert-Admin
  $key = Get-GenericMonitorKey
  if ($RemoveEdid)
  {
    if (Test-Path $key)
    { Remove-Item $key -Recurse
    }
    Write-Host "[display] EDID override removed" -ForegroundColor Green
  } else
  {
    # 128-byte EDID 1.4 block. ID kept as MS_0001 so the override stays on the
    # same device instance. Native mode: 2560x1440@60 CVT-RB (241.5 MHz).
    $hex = @(
      '00 FF FF FF FF FF FF 00 36 7F 01 00 01 00 00 00 00 1E 01 04 A5 3C 22 78 26'  # header, ID, DP digital, 60x34cm
      'EE 91 A3 54 4C 99 26 0F 50 54'                                              # sRGB chromaticity
      '21 08 00'                                                                   # 640x480, 800x600, 1024x768 @60
      'D1 C0 B3 00 81 C0 95 00 01 01 01 01 01 01 01 01'                            # 1920x1080, 1680x1050, 1280x720, 1440x900
      '56 5E 00 A0 A0 A0 29 50 30 20 35 00 55 50 21 00 00 1A'                      # DTD 2560x1440@60
      '00 00 00 FD 00 38 4C 1E 5A 19 00 0A 20 20 20 20 20 20'                      # range limits
      '00 00 00 FC 00 44 45 4C 4C 20 50 32 37 32 30 44 0A 20'                      # name "DELL P2720D"
      '00 00 00 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00'                      # dummy
      '00'                                                                         # no extensions
    ) -join ' '
    [byte[]]$bytes = $hex -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) }
    $sum = ($bytes | Measure-Object -Sum).Sum
    $bytes += [byte]((256 - ($sum % 256)) % 256)
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name '0' -PropertyType Binary -Value $bytes -Force | Out-Null
    Write-Host "[display] EDID override written to $key" -ForegroundColor Green
  }
  Restart-Gpu
}

Add-Type @'
using System; using System.Runtime.InteropServices;
public class DisplayMode {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE { [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName; public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput; public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName; public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency, dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int ChangeDisplaySettingsEx(string dev, ref DEVMODE dm, IntPtr h, int flags, IntPtr p);
  static DEVMODE New() { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return d; }
  public static string Current(string dev) { var d = New(); EnumDisplaySettings(dev, -1, ref d); return d.dmPelsWidth + "x" + d.dmPelsHeight + "@" + d.dmDisplayFrequency; }
  public static int Set(string dev, int w, int h, int hz) {
    var d = New(); EnumDisplaySettings(dev, -1, ref d);
    d.dmPelsWidth = w; d.dmPelsHeight = h; d.dmDisplayFrequency = hz; d.dmFields = 0x80000 | 0x100000 | 0x400000;
    return ChangeDisplaySettingsEx(dev, ref d, IntPtr.Zero, 0x1, IntPtr.Zero); // CDS_UPDATEREGISTRY
  }
}
'@

Write-Host "[display] $Device current: $([DisplayMode]::Current($Device))"
if ($W -gt 0 -and $H -gt 0)
{
  $r = [DisplayMode]::Set($Device, $W, $H, $Hz)
  if ($r -lt 0)
  { Write-Error "ChangeDisplaySettingsEx failed ($r)"
  }
  Write-Host "[display] $Device now: $([DisplayMode]::Current($Device))" -ForegroundColor Green
}
