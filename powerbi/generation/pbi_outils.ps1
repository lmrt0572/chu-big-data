# Helpers to drive Power BI Desktop for local checks: open a file, capture its windows, run DAX queries.
param(
    [Parameter(Mandatory = $true)][ValidateSet("ouvrir", "capturer", "dax", "fermer", "etat", "lire", "cliquer", "nommer")][string]$Action,
    [string]$Nom,
    [int]$Max = 60,
    [string]$Fichier,
    [string]$Sortie,
    [string]$Requete,
    [string]$Role
)

Add-Type -ReferencedAssemblies System.Drawing @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Drawing; using System.Text;
public static class Fen {
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static List<IntPtr> Of(uint pid) {
        var l = new List<IntPtr>();
        EnumWindows((h, p) => { uint q; GetWindowThreadProcessId(h, out q); if (q == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static string Title(IntPtr h) { var s = new StringBuilder(512); GetWindowText(h, s, 512); return s.ToString(); }
    public static Bitmap Shot(IntPtr h) {
        RECT r; GetWindowRect(h, out r);
        int w = Math.Max(1, r.R - r.L), ht = Math.Max(1, r.B - r.T);
        var b = new Bitmap(w, ht);
        using (var g = Graphics.FromImage(b)) { var dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
        return b;
    }
}
"@

function Get-Pbi { Get-Process PBIDesktop -ErrorAction SilentlyContinue }

switch ($Action) {
    "ouvrir" {
        $p = Start-Process -FilePath "C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe" -ArgumentList ('"' + $Fichier + '"') -WindowStyle Maximized -PassThru
        Set-Content -Path "$PSScriptRoot\pid.txt" -Value $p.Id
        "ouvert, pid $($p.Id)"
    }
    "etat" {
        foreach ($p in (Get-Pbi | Where-Object { $_.Id -eq [int](Get-Content "$PSScriptRoot\pid.txt") })) {
            foreach ($h in [Fen]::Of([uint32]$p.Id)) { "{0} {1}" -f $p.Id, [Fen]::Title($h) }
        }
    }
    "capturer" {
        $i = 0
        foreach ($p in (Get-Pbi | Where-Object { $_.Id -eq [int](Get-Content "$PSScriptRoot\pid.txt") })) {
            foreach ($h in [Fen]::Of([uint32]$p.Id)) {
                $r = New-Object Fen+RECT; [void][Fen]::GetWindowRect($h, [ref]$r)
                if (($r.R - $r.L) -lt 120 -or ($r.B - $r.T) -lt 80) { continue }
                $b = [Fen]::Shot($h); $f = "{0}_{1}.png" -f $Sortie, $i; $b.Save($f); $b.Dispose()
                "{0} [{1}] {2}x{3}" -f $f, [Fen]::Title($h), ($r.R - $r.L), ($r.B - $r.T); $i++
            }
        }
    }
    "dax" {
        [void][Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.AdomdClient")
        $id = [int](Get-Content "$PSScriptRoot\pid.txt")
        $ms = Get-CimInstance Win32_Process -Filter "ParentProcessId = $id AND Name = 'msmdsrv.exe'" | Select-Object -First 1
        $dir = [regex]::Match($ms.CommandLine, '-s "([^"]+)"').Groups[1].Value
        $port = (Get-Content "$dir\msmdsrv.port.txt" -Encoding Unicode).Trim()
        $base = "Data Source=localhost:$port"
        $cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection $base
        $cn.Open()
        $cat = $null
        foreach ($row in $cn.GetSchemaDataSet("DBSCHEMA_CATALOGS", $null).Tables[0].Rows) { $cat = $row["CATALOG_NAME"] }
        $cn.Close()
        $cs = "$base;Initial Catalog=$cat"
        if ($Role) { $cs += ";Roles=$Role" }
        $cn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection $cs
        $cn.Open()
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $Requete
        $rd = $cmd.ExecuteReader()
        $noms = 0..($rd.FieldCount - 1) | ForEach-Object { $rd.GetName($_) }
        $noms -join " | "
        while ($rd.Read()) { (0..($rd.FieldCount - 1) | ForEach-Object { $rd.GetValue($_) }) -join " | " }
        $rd.Close(); $cn.Close()
    }
    { $_ -in "lire", "cliquer" } {
        Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
        $A = [System.Windows.Automation.AutomationElement]
        $id = [int](Get-Content "$PSScriptRoot\pid.txt")
        $cond = New-Object System.Windows.Automation.PropertyCondition($A::ProcessIdProperty, $id)
        $wins = $A::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
        foreach ($w in $wins) {
            $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            if ($Action -eq "lire") {
                "== " + $w.Current.Name
                $n = 0
                foreach ($e in $all) {
                    $t = $e.Current.Name
                    if ($t -and $n -lt $Max -and ($e.Current.ControlType.ProgrammaticName -match "Text|Window|Button|TabItem")) {
                        "  [" + $e.Current.ControlType.ProgrammaticName.Replace("ControlType.", "") + "] " + $t; $n++
                    }
                }
            } else {
                foreach ($e in $all) {
                    if ($e.Current.Name -eq $Nom) {
                        $pat = $null
                        if ($e.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pat)) { $pat.Invoke(); "clic : $Nom"; return }
                        if ($e.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pat)) { $pat.Select(); "sélection : $Nom"; return }
                        if ($e.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$pat)) { $pat.Toggle(); "bascule : $Nom"; return }
                    }
                }
                "introuvable : $Nom"
            }
        }
    }
    "nommer" {
        # Fills the file name of the open "Enregistrer sous" dialog, then clicks Enregistrer (Win32 messages).
        Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
        Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W32 {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
"@
        $A = [System.Windows.Automation.AutomationElement]
        $id = [int](Get-Content "$PSScriptRoot\pid.txt")
        $w = $A::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition($A::ProcessIdProperty, $id)))
        $d = $w.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition($A::NameProperty, "Enregistrer sous")))
        if (-not $d) { "dialogue introuvable"; return }
        $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
        $script:edit = $null; $script:btn = $null
        function Walk($e, $depth) {
            $c = $walker.GetFirstChild($e)
            while ($c) {
                $k = $c.Current
                if ($k.AutomationId -eq "1001" -and -not $k.Name.StartsWith("Adresse") -and -not $script:edit) { $script:edit = $c }
                if ($k.AutomationId -eq "1" -and $k.Name -eq "Enregistrer") { $script:btn = $c }
                if ($depth -lt 12) { Walk $c ($depth + 1) }
                $c = $walker.GetNextSibling($c)
            }
        }
        Walk $d 0
        [void][W32]::SendMessage([IntPtr]$script:edit.Current.NativeWindowHandle, 0x000C, [IntPtr]::Zero, $Fichier)
        Start-Sleep -Milliseconds 500
        [void][W32]::SendMessage([IntPtr]$script:btn.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
        "enregistrement demandé : $Fichier"
    }
    "fermer" {
        $id = [int](Get-Content "$PSScriptRoot\pid.txt")
        Get-CimInstance Win32_Process -Filter "ParentProcessId = $id" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        "fermé $id"
    }
}
