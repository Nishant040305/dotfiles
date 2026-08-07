# KDE Connect firewall fix for hotspot (nm-shared zone) and default zone
# Adds kdeconnect service at runtime so phone can discover laptop over hotspot.
if ! firewall-cmd --zone=nm-shared --query-service=kdeconnect &>/dev/null; then
    sudo firewall-cmd --zone=nm-shared --add-service=kdeconnect &>/dev/null
fi

if ! firewall-cmd --zone=FedoraWorkstation --query-service=kdeconnect &>/dev/null; then
    sudo firewall-cmd --zone=FedoraWorkstation --add-service=kdeconnect &>/dev/null
fi
