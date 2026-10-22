"""Capture this demo's own native window for playback verification."""
import ctypes, sys, time
from ctypes import wintypes
from pathlib import Path
from PIL import Image, ImageGrab

user32=ctypes.windll.user32
user32.SetProcessDPIAware()
title=sys.argv[1]; dest=Path(sys.argv[2]); found=[]
callback=ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
def each(hwnd,_):
    buf=ctypes.create_unicode_buffer(1024)
    user32.GetWindowTextW(hwnd,buf,1024)
    if title.lower() in buf.value.lower() and user32.IsWindowVisible(hwnd): found.append((hwnd,buf.value))
    return True
user32.EnumWindows(callback(each),0)
if not found: raise RuntimeError(f'No visible window matching {title}')
hwnd,name=found[0]
user32.ShowWindow(hwnd,9)
user32.SetForegroundWindow(hwnd)
time.sleep(.35)
rect=wintypes.RECT(); user32.GetWindowRect(hwnd,ctypes.byref(rect))
gdi=ctypes.windll.gdi32
user32.GetWindowDC.argtypes=[wintypes.HWND];user32.GetWindowDC.restype=wintypes.HDC
gdi.CreateCompatibleDC.argtypes=[wintypes.HDC];gdi.CreateCompatibleDC.restype=wintypes.HDC
gdi.CreateCompatibleBitmap.argtypes=[wintypes.HDC,ctypes.c_int,ctypes.c_int];gdi.CreateCompatibleBitmap.restype=wintypes.HBITMAP
gdi.SelectObject.argtypes=[wintypes.HDC,wintypes.HANDLE];gdi.SelectObject.restype=wintypes.HANDLE
user32.PrintWindow.argtypes=[wintypes.HWND,wintypes.HDC,wintypes.UINT]
gdi.DeleteObject.argtypes=[wintypes.HANDLE];gdi.DeleteDC.argtypes=[wintypes.HDC]
user32.ReleaseDC.argtypes=[wintypes.HWND,wintypes.HDC]
class BitmapHeader(ctypes.Structure):
    _fields_=[('size',wintypes.DWORD),('width',wintypes.LONG),('height',wintypes.LONG),('planes',wintypes.WORD),('bits',wintypes.WORD),('compression',wintypes.DWORD),('imageSize',wintypes.DWORD),('x',wintypes.LONG),('y',wintypes.LONG),('used',wintypes.DWORD),('important',wintypes.DWORD)]
gdi.GetDIBits.argtypes=[wintypes.HDC,wintypes.HBITMAP,wintypes.UINT,wintypes.UINT,ctypes.c_void_p,ctypes.POINTER(BitmapHeader),wintypes.UINT]
width,height=rect.right-rect.left,rect.bottom-rect.top
dc=user32.GetWindowDC(hwnd);mem=gdi.CreateCompatibleDC(dc);bitmap=gdi.CreateCompatibleBitmap(dc,width,height)
previous=gdi.SelectObject(mem,bitmap)
if not user32.PrintWindow(hwnd,mem,2): raise RuntimeError('PrintWindow failed; refusing to capture another application')
header=BitmapHeader();header.size=ctypes.sizeof(header);header.width=width;header.height=-height;header.planes=1;header.bits=32
pixels=ctypes.create_string_buffer(width*height*4)
gdi.GetDIBits(mem,bitmap,0,height,pixels,ctypes.byref(header),0)
im=Image.frombuffer('RGB',(width,height),pixels,'raw','BGRX',0,1)
gdi.SelectObject(mem,previous);gdi.DeleteObject(bitmap);gdi.DeleteDC(mem);user32.ReleaseDC(hwnd,dc)
# Prefer the compositor's current frame when this exact window is foreground.
# Never take a desktop crop if Windows refused foreground activation.
if user32.GetForegroundWindow()==hwnd:
    im=ImageGrab.grab(bbox=(rect.left,rect.top,rect.right,rect.bottom),all_screens=True)
dest.parent.mkdir(parents=True,exist_ok=True)
im.save(dest)
print(name,tuple([rect.left,rect.top,rect.right,rect.bottom]),dest)
