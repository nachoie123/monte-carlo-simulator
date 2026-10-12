import subprocess, time, sys, Quartz
out = sys.argv[1]; prefix = sys.argv[2]; relaunch = len(sys.argv) < 4
APP = "Monte Carlo Stock Simulator"
if relaunch:
    subprocess.run(["pkill", "-x", APP]); time.sleep(0.8)
    subprocess.run(["open", "-a", "/Users/nachosanbenito/Projects/Quantum/05-monte-carlo-simulator/apple/build-mac/Build/Products/Debug/Monte Carlo Stock Simulator.app"])
    time.sleep(4)
subprocess.run(["osascript", "-e", f'tell application "System Events" to tell process "{APP}"\nset frontmost to true\nset position of window 1 to {{0, 40}}\nset size of window 1 to {{1400, 855}}\nend tell'])
time.sleep(7 if relaunch else 1.5)
wid = next(w["kCGWindowNumber"] for w in Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID) if "Monte" in str(w.get("kCGWindowOwnerName")) and w.get("kCGWindowLayer") == 0 and w["kCGWindowBounds"]["Width"] > 800)
def post(t, x, y):
    e = Quartz.CGEventCreateMouseEvent(None, t, (x, y), 0); Quartz.CGEventPost(Quartz.kCGHIDEventTap, e)
def scroll(px):
    for _ in range(abs(px) // 50):
        e = Quartz.CGEventCreateScrollWheelEvent(None, Quartz.kCGScrollEventUnitPixel, 1, -50 if px > 0 else 50)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, e); time.sleep(0.01)
def shot(name):
    time.sleep(1.0); subprocess.run(["screencapture", "-x", "-o", "-l", str(wid), f"{out}/{prefix}-{name}.png"])
post(Quartz.kCGEventMouseMoved, 1300, 300); time.sleep(0.1)
post(Quartz.kCGEventLeftMouseDown, 1300, 300); time.sleep(0.05); post(Quartz.kCGEventLeftMouseUp, 1300, 300); time.sleep(0.4)
scroll(-20000); shot("1")
for name in ["2", "3", "4", "5", "6", "7", "8", "9"]:
    scroll(int(sys.argv[3]) if len(sys.argv) > 3 else 700); shot(name)
print("ok", wid)
