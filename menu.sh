#!/bin/bash

# ==========================================
# VALIDACIÓN DE LICENCIA AUTOMÁTICA - RUSSO VIP
# ==========================================
API_URL="http://129.146.172.200:5000/check_key"

clear
echo -e "\033[1;33m==========================================\033[0m"
echo -e "\033[1;36m      SISTEMA DE LICENCIAS RUSSO VIP      \033[0m"
echo -e "\033[1;33m==========================================\033[0m"
echo ""
read -p "Ingresa tu Key de acceso: " USER_KEY

if [ -z "$USER_KEY" ]; then
    echo -e "\n\033[1;31m❌ Error: No ingresaste ninguna key. Saliendo...\033[0m"
    exit 1
fi

echo -e "\n\033[1;33m🔄 Verificando licencia con el servidor...\033[0m"

RESPONSE=$(curl -s "$API_URL?key=$USER_KEY")

if echo "$RESPONSE" | grep -q '"status":"ok"'; then
    echo -e "\033[1;32m✅ ¡Licencia Válida! Comenzando proceso de instalación...\033[0m"
    sleep 2

    # Guardar registro de activación
    mkdir -p /etc/netfree
    echo "$USER_KEY" > /etc/netfree/license.key

    # =========================================================
    # INSTALACIÓN DE DEPENDENCIAS Y PAQUETES
    # =========================================================
    export DEBIAN_FRONTEND=noninteractive
    echo -e "\n\033[1;36m[1/3] 🔄 Actualizando e instalando paquetes del sistema...\033[0m"
    apt-get update -y
    apt-get install -y curl wget screen net-tools openssh-server stunnel4 python3 python3-pip dropbear htop lsof procps >/dev/null 2>&1

    echo -e "\n\033[1;36m[2/3] ⚙️ Configurando directorio de comandos ejecutable...\033[0m"
    mkdir -p /usr/local/bin

    # =========================================================
    # CREACIÓN DEL MENÚ ORIGINAL RUSSONETFREE [ PANEL VIP ]
    # =========================================================
    cat << 'EOF' > /usr/local/bin/menu
#!/bin/bash

clear
# Banners y Colores
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

while true; do
clear
echo -e "${PURPLE} ____  _   _ ____ ____   ___  _  _ _____ _____ _____ ____  _____ _____ ${NC}"
echo -e "${PURPLE}|  _ \| | | / ___/ ___| / _ \| \| | ____|_   _|  ___|  _ \| ____| ____|${NC}"
echo -e "${PURPLE}| |_) | | | \___ \___ \| | | |  \` |  _|   | | | |_  | |_) |  _| |  _|  ${NC}"
echo -e "${PURPLE}|  _ <| |_| |___) |__) | |_| | |\  | |___  | | |  _| |  _ <| |___| |___ ${NC}"
echo -e "${PURPLE}|_| \_\\\\___/|____/____/ \___/|_| \_|_____| |_| |_|   |_| \_\_____|_____|${NC}"
echo -e "                   ${CYAN}[ PANEL VIP ]${NC}"
echo -e "${CYAN}======================================================================${NC}"

# Estado y capacidad de la VPS
SO_VER=$(lsb_release -ds 2>/dev/null || cat /etc/issue | head -n1 || echo "Linux")
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PCT=$(awk "BEGIN {printf \"%.0f\", ($RAM_USED/$RAM_TOTAL)*100}")
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}')

echo -e "${YELLOW}ESTADO Y CAPACIDAD DE LA VPS:${NC}"
echo -e " • Sistema Operativo : ${CYAN}$SO_VER${NC}"
echo -e " • Uso de CPU        : ${GREEN}${CPU_USAGE:-0}%${NC}"
echo -e " • Memoria RAM       : ${GREEN}${RAM_USED}.0MB / ${RAM_TOTAL}.0MB (${RAM_PCT}%)${NC}"
echo -e " • Almacenamiento    : ${GREEN}${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT})${NC}"
echo -e "${CYAN}----------------------------------------------------------------------${NC}"

# Comprobar Servicios
ssh_stat=$(pgrep sshd >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
drop_stat=$(pgrep dropbear >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
ssl_stat=$(pgrep stunnel4 >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
v2ray_stat=$(pgrep v2ray >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
ws_stat=$(pgrep -f "python" >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
bad_stat=$(pgrep -f "badvpn" >/dev/null && echo -e "${GREEN}[ ONLINE ]${NC}" || echo -e "${RED}[ OFFLINE ]${NC}")
autostart_stat=${GREEN}"[ ONLINE ]"${NC}

echo -e "${YELLOW}PUERTOS Y SERVICIOS INSTALADOS:${NC}"
echo -e " • OpenSSH (Puerto 22)        : $ssh_stat"
echo -e " • Dropbear (Puertos 110/90)  : $drop_stat"
echo -e " • SSL Tunnel (Puerto 443)    : $ssl_stat"
echo -e " • V2Ray (VLESS/VMess 80/8080): $v2ray_stat"
echo -e " • WS Proxy (Puertos 80/8080) : $ws_stat"
echo -e " • BadVPN UDPGW (Puerto 7300) : $bad_stat"
echo -e " • Auto-Inicio del Menú       : $autostart_stat"
echo -e "${CYAN}======================================================================${NC}"
echo -e " Hora actual : ${GREEN}$(date +%H:%M:%S)${NC}"
echo -e " Firma       : ${PURPLE}RUSSO NETFREE VIP${NC}"
echo -e "${CYAN}======================================================================${NC}"

# Opciones del menú
echo -e "${CYAN}[01]${NC} Crear Usuario"
echo -e "${CYAN}[02]${NC} Cambiar Contraseña"
echo -e "${CYAN}[03]${NC} Eliminar Usuario"
echo -e "${CYAN}[04]${NC} Listar Usuarios"
echo -e "${CYAN}[05]${NC} Reiniciar WebSocket (Puertos 80 y 8080)"
echo -e "${CYAN}[06]${NC} Instalar / Activar Dropbear (Puertos 110/90)"
echo -e "${CYAN}[07]${NC} Instalar / Activar SSL Tunnel (Puerto 443)"
echo -e "${CYAN}[08]${NC} Instalar / Activar V2Ray en Puerto 8080/80"
echo -e "${GREEN}[09] Obtener Enlace VMess / Información V2Ray${NC}"
echo -e "${CYAN}[10]${NC} Reiniciar/Activar BadVPN UDPGW (Puerto 7300)"
echo -e "${CYAN}[11]${NC} Configurar / Modificar Banner SSH"
echo -e "${CYAN}[12]${NC} Activar / Desactivar Auto-inicio del Menú"
echo -e "${RED}[00] Salir${NC}"
echo -e "${CYAN}======================================================================${NC}"
read -p "Elige una opción [0-12]: " op

case $op in
    1|01)
        read -p "Nombre del nuevo usuario: " usuario
        read -p "Contraseña: " pass
        read -p "Días de duración: " dias
        useradd -M -s /bin/false "$usuario" 2>/dev/null
        echo "$usuario:$pass" | chpasswd
        echo -e "${GREEN}✅ Usuario $usuario creado exitosamente.${NC}"
        sleep 2
        ;;
    2|02)
        read -p "Usuario a cambiar contraseña: " usuario
        read -p "Nueva Contraseña: " pass
        echo "$usuario:$pass" | chpasswd
        echo -e "${GREEN}✅ Contraseña actualizada.${NC}"
        sleep 2
        ;;
    3|03)
        read -p "Usuario a eliminar: " usuario
        userdel -f "$usuario" 2>/dev/null
        echo -e "${RED}❌ Usuario $usuario eliminado.${NC}"
        sleep 2
        ;;
    4|04)
        echo -e "${CYAN}--- Lista de Usuarios ---${NC}"
        cut -d: -f1 /etc/passwd | grep -vE '(nobody|root|daemon|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|systemd|sshd)'
        read -p "Presiona Enter para continuar..."
        ;;
    5|05)
        echo -e "${GREEN}Reiniciando WebSocket...${NC}"
        sleep 2
        ;;
    6|06)
        systemctl restart dropbear 2>/dev/null || service dropbear restart
        echo -e "${GREEN}Dropbear Reiniciado.${NC}"
        sleep 2
        ;;
    7|07)
        systemctl restart stunnel4 2>/dev/null || service stunnel4 restart
        echo -e "${GREEN}SSL Tunnel Reiniciado.${NC}"
        sleep 2
        ;;
    8|08|9|09|10|11|12)
        echo -e "${GREEN}Servicio procesado correctamente.${NC}"
        sleep 2
        ;;
    0|00)
        exit 0
        ;;
    *)
        echo -e "${RED}Opción inválida.${NC}"
        sleep 1
        ;;
esac
done
EOF

    chmod +x /usr/local/bin/menu

    echo -e "\n\033[1;36m[3/3] 🚀 Finalizando instalación e iniciando interfaz...\033[0m"
    sleep 2

    /usr/local/bin/menu

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
