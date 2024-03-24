exec startxfce4 &
exec sleep 5 && xfwm4 --replace
    
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
