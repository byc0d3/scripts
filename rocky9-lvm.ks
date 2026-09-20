#version=RHEL9
text
# --- Limpieza de Disco ---
clearpart --all --initlabel

# --- Gestor de Arranque ---
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto"

# --- Esquema de Particiones LVM ---
# Nota: Ajusta --ondisk según tu VM en Proxmox (sda o vda)
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=1024 --fsoptions="umask=0077,shortname=winnt"
part pv.01 --fstype="lvmpv" --ondisk=sda --size=1 --grow

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
