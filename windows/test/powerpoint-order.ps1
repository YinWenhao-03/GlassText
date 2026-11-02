param([long]$Body,[long]$Toolbar)
$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ShowOrder {
 [DllImport("user32")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32")] public static extern bool SetForegroundWindow(IntPtr w);
 [DllImport("user32")] static extern IntPtr GetWindow(IntPtr w,uint cmd);
 [DllImport("user32")] static extern IntPtr GetTopWindow(IntPtr w);
 [DllImport("user32",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr w,System.Text.StringBuilder name,int size);
 [DllImport("user32")] static extern bool IsWindowVisible(IntPtr w);
 [DllImport("user32")] static extern uint GetWindowThreadProcessId(IntPtr w,out uint pid);
 public static IntPtr FindShow(IntPtr application) {
  uint owner,pid; GetWindowThreadProcessId(application,out owner);
  var name=new System.Text.StringBuilder(128);
  for(var w=GetTopWindow(IntPtr.Zero);w!=IntPtr.Zero;w=GetWindow(w,2)){
   GetWindowThreadProcessId(w,out pid);
   if(pid==owner && IsWindowVisible(w)){
    GetClassName(w,name,128);
    if(name.ToString().Equals("screenClass",StringComparison.OrdinalIgnoreCase))return w;
   }
  }
  return IntPtr.Zero;
 }
 [DllImport("user32")] public static extern bool SetWindowPos(IntPtr w,IntPtr after,int x,int y,int cx,int cy,uint flags);
 public static int Rank(long handle) {
  int n=0;
  for(var w=GetTopWindow(IntPtr.Zero);w!=IntPtr.Zero && n<4096;w=GetWindow(w,2),n++)
   if(w.ToInt64()==handle)return n;
  return int.MaxValue;
 }
}
'@
$alreadyRunning=Get-Process POWERPNT -ErrorAction SilentlyContinue
try {
 $ppt=New-Object -ComObject PowerPoint.Application
 if($ppt.SlideShowWindows.Count){throw 'Another presentation is currently being shown'}
 $deck=$ppt.Presentations.Add(-1)
 [void]$deck.Slides.Add(1,12)
 [void]$deck.Slides.Add(2,12)
 $deck.SlideShowSettings.ShowType=1
 $show=$deck.SlideShowSettings.Run()
 $show.Activate()
 $deadline=[datetime]::UtcNow.AddSeconds(5)
 do {
  $hwnd=[ShowOrder]::FindShow([IntPtr]([long]$ppt.HWND))
  if($hwnd -ne [IntPtr]::Zero){break}
  Start-Sleep -Milliseconds 100
 }while([datetime]::UtcNow -lt $deadline)
 if($hwnd -eq [IntPtr]::Zero){throw 'PowerPoint did not expose a visible slide show window'}
 foreach($slide in 1,2){
  $show.View.GotoSlide($slide)
  [void][ShowOrder]::SetForegroundWindow($hwnd)
  Start-Sleep -Milliseconds 250
  if([ShowOrder]::GetForegroundWindow() -ne $hwnd){throw 'Test could not bring its slide show to the foreground'}
  # Force the actual slide show to overtake previously topmost windows.
  if(![ShowOrder]::SetWindowPos($hwnd,[IntPtr](-1),0,0,0,0,0x53)){throw 'Could not raise the slide show'}
  $deadline=[datetime]::UtcNow.AddSeconds(5)
  do {
   $rank=[ShowOrder]::Rank($hwnd.ToInt64())
   $bodyRank=[ShowOrder]::Rank($Body)
   $toolRank=[ShowOrder]::Rank($Toolbar)
   if($toolRank -lt $bodyRank -and $bodyRank -lt $rank){break}
   Start-Sleep -Milliseconds 100
  }while([datetime]::UtcNow -lt $deadline)
  if($rank -eq [int]::MaxValue -or $toolRank -ge $bodyRank -or $bodyRank -ge $rank){throw "Slide $slide covered reader: toolbar=$toolRank body=$bodyRank show=$rank foreground=$([ShowOrder]::GetForegroundWindow()) showHandle=$hwnd"}
  if([ShowOrder]::GetForegroundWindow() -ne $hwnd){throw 'PowerPoint lost keyboard focus'}
  Write-Output "PASS PowerPoint slide $slide, toolbar above body above slideshow, slideshow retains focus"
 }
}finally{
 if($show){try{$show.View.Exit()}catch{}}
 if($deck){try{$deck.Saved=-1;$deck.Close()}catch{}}
 if(!$alreadyRunning -and $ppt){try{if($ppt.Presentations.Count -eq 0){$ppt.Quit()}}catch{}}
}
