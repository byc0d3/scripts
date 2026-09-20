#version=RHEL9
text
# --- Limpieza de Disco ---
clearpart --all --initlabel

# --- Gestor de Arranque ---
bootloader --location=mbr --driveorder=vda --append="crashkernel=auto"
k# --- Esquema de Particiones LVM ---
# Nota: Ajustado a vda porque el disco en Proxmox es VirtIO
part /boot --fstype="xfs" --ondisk=vda --size=1024
part /boot/efi --fstype="efi" --ondisk=vda --size=1024 --fsoptions="umask=0077,shortname=winnt"
part pv.01 --fstype="lvmpv" --ondisk=vda --size=1 --grow

volgroup rlm pv.01 --pesize=4096

logvol / --fstype="xfs" --percent=15 --name=root --vgname=rlm
logvol /tmp --fstype="xfs" --percent=5 --name=tmp --vgname=rlm
logvol /home --fstype="xfs" --percent=5 --name=home --vgname=rlm
logvol /var --fstype="xfs" --percent=10 --name=var --vgname=rlm
logvol /var/log --fstype="xfs" --percent=10 --name=var_log --vgname=rlm
logvol /var/log/audit --fstype="xfs" --percent=10 --name=var_log_audit --vgname=rlm
logvol /var/lib --fstype="xfs" --percent=20 --name=var_lib --vgname=rlm
logvol /opt --fstype="xfs" --percent=10 --name=opt --vgname=rlm
logvol swap --fstype="swap" --percent=10 --name=swap --vgname=rlm

reboot
