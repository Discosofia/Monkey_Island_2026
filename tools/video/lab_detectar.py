import subprocess, sys
V = sys.argv[1]
cmd = ["ffmpeg","-v","error","-i",V,"-vf","fps=10,crop=20:10:1414:872","-f","rawvideo","-pix_fmt","rgb24","-"]
data = subprocess.run(cmd, capture_output=True).stdout
n = len(data)//600
on = []
for i in range(n):
    f = data[i*600:(i+1)*600]
    r = sum(f[0::3])/200; g = sum(f[1::3])/200; b = sum(f[2::3])/200
    on.append(r>200 and g>130 and b<120)
first = on.index(True) if True in on else None
last = n-1-on[::-1].index(True) if True in on else None
runs=[];s=None
for i,v in enumerate(on):
    if v and s is None: s=i
    if not v and s is not None: runs.append((s/10,(i)/10)); s=None
if s is not None: runs.append((s/10,n/10))
print("frames",n,"runs skip button:",runs)
