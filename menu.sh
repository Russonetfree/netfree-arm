#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[-] Este script debe ejecutarse como root (sudo -i).\e[0m"
  exit 1
fi

INSTALL_CHECK="/etc/russo_installed"
PASS_FILE="/etc/russo_passwords.txt"
API_URL="http://129.146.172.200:5000/check_key"

Rojo="\e[1;91m"
Verde="\e[1;92m"
Amarillo="\e[1;93m"
Azul="\e[1;94m"
Magenta="\e[1;95m"
Cian="\e[1;96m"
Blanco="\e[1;97m"
Fin="\e[0m"

check_port() {
  local port=$1
  if netstat -tuln 2>/dev/null | grep -q ":$port " || lsof -i :$port >/dev/null 2>&1; then
    echo -e "${Verde}[ ONLINE ]${Fin}"
  else
    echo -e "${Rojo}[ OFFLINE ]${Fin}"
  fi
}

check_autostart() {
  if grep -q "^menu$" /root/.bashrc 2>/dev/null; then
    echo -e "${Verde}[ ONLINE ]${Fin}"
  else
    echo -e "${Rojo}[ OFFLINE ]${Fin}"
  fi
}

get_cpu_usage() {
  read cpu a b c previdle rest < /proc/stat
  prevtotal=$((a+b+c+previdle))
  sleep 0.2
  read cpu a b c idle rest < /proc/stat
  total=$((a+b+c+idle))
  cpu=$((100*((total-prevtotal) - (idle-previdle)) / (total-prevtotal) ))
  echo "${cpu}%"
}

get_ram_usage() {
  free -m | awk 'NR==2{printf "%.1fMB / %.1fMB (%.0f%%)", $3, $2, $3*100/$2 }'
}

get_disk_usage() {
  df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}'
}

gestionar_dropbear() {
  echo -e ""
  echo -e "${Cian}[*] Verificando e instalando Dropbear...${Fin}"
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  apt-get update -y && apt-get install -y -o Dpkg::Options::="--force-confold" dropbear

  cat << 'EOF_DB' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=110
DROPBEAR_EXTRA_ARGS="-p 90"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF_DB

  systemctl enable dropbear >/dev/null 2>&1
  systemctl restart dropbear
  echo -e "${Verde}[+] Dropbear activo en puertos 110 y 90.${Fin}"
}

gestionar_stunnel() {
  echo -e ""
  echo -e "${Cian}[*] Instalando y configurando SSL Tunnel (Puerto 443)...${Fin}"
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  apt-get update -y && apt-get install -y -o Dpkg::Options::="--force-confold" stunnel4

  if [ ! -f /etc/stunnel/stunnel.pem ]; then
    openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/CN=RussoNet/O=RussoNet/C=DO" 2>/dev/null
  fi

  cat << 'EOF_ST' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[stunnel]
accept = 443
connect = 127.0.0.1:110
EOF_ST

  sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
  systemctl enable stunnel4 >/dev/null 2>&1
  systemctl restart stunnel4
  echo -e "${Verde}[+] Stunnel activo en puerto 443.${Fin}"
}

gestionar_v2ray() {
  echo -e ""
  echo -e "${Cian}[*] Instalando V2Ray Core...${Fin}"
  bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

  mkdir -p /usr/local/etc/v2ray
  cat << 'EOF_V2' > /usr/local/etc/v2ray/config.json
{
  "inbounds": [{
    "port": 10080,
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "b83a38e2-36a3-4631-9a6d-e2511222e3eb",
          "alterId": 0
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/russo"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF_V2

  systemctl enable v2ray >/dev/null 2>&1
  systemctl restart v2ray
  systemctl restart ws_proxy.service 2>/dev/null
  echo -e "${Verde}[+] V2Ray instalado correctamente.${Fin}"
}

obtener_informacion_v2ray() {
  clear
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}         INFORMACIÓN DE CUENTA V2RAY                ${Fin}"
  echo -e "${Cian}====================================================${Fin}"

  local ip_publica=$(curl -s http://checkip.amazonaws.com || wget -qO- http://ipecho.net/plain)
  read -p " Ingresa tu subdominio (o presiona [Enter] para usar IP $ip_publica): " host_v2ray
  if [ -z "$host_v2ray" ]; then
    host_v2ray="$ip_publica"
  fi

  local uuid="b83a38e2-36a3-4631-9a6d-e2511222e3eb"
  local puerto="8080"
  local path_ws="/russo"

  echo -e ""
  echo -e " ${Blanco}1.${Fin}"
  echo -e " ${Blanco}IP / Host  :${Fin} ${Cian}${host_v2ray}${Fin}"
  echo -e " ${Blanco}Port        :${Fin} ${Amarillo}${puerto}${Fin}"
  echo -e " ${Blanco}TLS         :${Fin} ${Rojo}close${Fin}"
  echo -e " ${Blanco}UUID        :${Fin} ${Blanco}${uuid}${Fin}"
  echo -e " ${Blanco}Alter ID    :${Fin} ${Blanco}0${Fin}"
  echo -e " ${Blanco}Network     :${Fin} ${Cian}WebSocket host: ${host_v2ray}, path: ${path_ws}${Fin}"
  echo -e "${Cian}----------------------------------------------------${Fin}"

  local raw_json="{\"v\":\"2\",\"ps\":\"RUSSO_NETFREE_VIP\",\"add\":\"${host_v2ray}\",\"port\":\"${puerto}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${host_v2ray}\",\"path\":\"${path_ws}\",\"tls\":\"\"}"
  local vmess_base64=$(echo -n "$raw_json" | base64 -w 0)

  echo -e " ${Verde}vmess://${vmess_base64}${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Presiona [Enter] para continuar..."
}

configurar_banner() {
  echo -e ""
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}             CONFIGURAR BANNER SSH                  ${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e " ${Cian}[1]${Fin} ${Blanco}Editar Banner en Nano${Fin}"
  echo -e " ${Cian}[2]${Fin} ${Rojo}Eliminar Banner actual${Fin}"
  echo -e " ${Cian}[0]${Fin} ${Blanco}Volver${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Elige una opción: " opc_banner

  case $opc_banner in
    1)
      nano /etc/issue.net
      systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
      systemctl restart dropbear 2>/dev/null
      systemctl restart stunnel4 2>/dev/null
      echo -e "${Verde}[+] ¡Banner actualizado!${Fin}"
      ;;
    2)
      > /etc/issue.net
      echo -e "${Verde}[+] Banner eliminado.${Fin}"
      ;;
    *)
      return
      ;;
  esac
}

gestionar_autostart() {
  echo -e ""
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}             AUTO-INICIO DEL MENÚ                   ${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e " ${Cian}[1]${Fin} ${Verde}Activar auto-inicio al entrar por SSH${Fin}"
  echo -e " ${Cian}[2]${Fin} ${Rojo}Desactivar auto-inicio${Fin}"
  echo -e " ${Cian}[0]${Fin} ${Blanco}Volver${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Elige una opción: " opc_auto

  case $opc_auto in
    1)
      sed -i '/^menu$/d' /root/.bashrc
      echo "menu" >> /root/.bashrc
      echo -e "${Verde}[+] ¡Auto-inicio activado!${Fin}"
      ;;
    2)
      sed -i '/^menu$/d' /root/.bashrc
      echo -e "${Verde}[+] Auto-inicio desactivado.${Fin}"
      ;;
    *)
      return
      ;;
  esac
}

instalar_badvpn() {
  echo -e ""
  if [ ! -f /usr/local/bin/badvpn-udpgw ]; then
    echo -e "${Cian}[*] Compilando BadVPN por única vez...${Fin}"
    cd /tmp
    rm -rf badvpn
    git clone https://github.com/ambrop72/badvpn.git
    mkdir -p /tmp/badvpn/build
    cd /tmp/badvpn/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make
    find /tmp/badvpn/build -name "badvpn-udpgw" -exec cp {} /usr/local/bin/ \;
    rm -rf /tmp/badvpn
  fi

  cat << 'EOF_BV' > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDP Gateway Service
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 8
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF_BV

  systemctl daemon-reload
  systemctl enable badvpn.service >/dev/null 2>&1
  systemctl restart badvpn.service
  echo -e "${Verde}[+] BadVPN activo en puerto 7300.${Fin}"
}

listar_usuarios_estado() {
  clear
  echo -e "${Cian}=====================================================================${Fin}"
  echo -e "${Amarillo}                MOSTRAR USUARIOS REGISTRADOS                         ${Fin}"
  echo -e "${Cian}=====================================================================${Fin}"
  echo -e " ${Blanco}USUARIO            CONTRASEÑA         ESTADO         CONEXIONES${Fin}"
  echo -e "${Cian}---------------------------------------------------------------------${Fin}"

  local usuarios=$(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "ubuntu" && $1 != "opc" && $1 !~ /^snap/ {print $1}' /etc/passwd)

  if [ -z "$usuarios" ]; then
    echo -e " ${Rojo}No hay usuarios SSH/VPN registrados.${Fin}"
  else
    for u in $usuarios; do
      local pwd_usr="[Protegida]"
      if [ -f "$PASS_FILE" ]; then
        local found_pwd=$(grep "^$u:" "$PASS_FILE" | cut -d: -f2)
        if [ ! -z "$found_pwd" ]; then
          pwd_usr="$found_pwd"
        fi
      fi

      local total_con=0
      if ps -u "$u" -o comm= 2>/dev/null | grep -E "dropbear|sshd|bash|sh" &>/dev/null; then
        total_con=$(ps -u "$u" --no-headers 2>/dev/null | wc -l)
      elif who | grep -w "$u" &>/dev/null; then
        total_con=$(who | grep -w "$u" | wc -l)
      fi

      if [ "$total_con" -gt 0 ]; then
        printf " %-18s ${Amarillo}%-18s${Fin} ${Verde}[ ONLINE ]${Fin}     %-2s conex.\n" "$u" "$pwd_usr" "$total_con"
      else
        printf " %-18s ${Amarillo}%-18s${Fin} ${Rojo}[ OFFLINE ]${Fin}    0 conex.\n" "$u" "$pwd_usr"
      fi
    done
  fi

  echo -e "${Cian}=====================================================================${Fin}"
  read -p " Presiona [Enter] para continuar..."
}

while true; do
  clear
  echo -e "\e[1;92m    ____  _   _ ____ ____   ___ \e[1;93m _   _ _____ _____ _____ ____  _____ \e[0m"
  echo -e "\e[1;92m   |  _ \| | | / ___/ ___| / _ \ \e[1;93m| \ | | ____|_   _| ____|  _ \| ____|\e[0m"
  echo -e "\e[1;93m   | |_) | | | \___ \___ \| | | |\e[1;91m|  \| |  _|   | | |  _| | |_) |  _|  \e[0m"
  echo -e "\e[1;93m   |  _ <| |_| |___) |__) | |_| |\e[1;91m| |\  | |___  | | | |___|  _ <| |___ \e[0m"
  echo -e "\e[1;91m   |_| \_\\___/|____/____/ \___/ \e[1;95m|_| \_|_____| |_| |_____|_| \_\_____|\e[0m"
  echo -e "\e[1;95m                             [ PANEL VIP ]                             \e[0m"
  echo -e "${Cian}=====================================================================\e[0m"

  echo -e " ${Amarillo}ESTADO Y CAPACIDAD DE LA VPS:${Fin}"
  echo -e "  ${Blanco}• Sistema Operativo  :${Fin} ${Verde}$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f2)${Fin}"
  echo -e "  ${Blanco}• Uso de CPU         :${Fin} ${Amarillo}$(get_cpu_usage)${Fin}"
  echo -e "  ${Blanco}• Memoria RAM        :${Fin} ${Cian}$(get_ram_usage)${Fin}"
  echo -e "  ${Blanco}• Almacenamiento     :${Fin} ${Magenta}$(get_disk_usage)${Fin}"
  echo -e "${Cian}---------------------------------------------------------------------${Fin}"
  echo -e " ${Amarillo}PUERTOS Y SERVICIOS INSTALADOS:${Fin}"
  echo -e "  ${Blanco}• OpenSSH (Puerto 22)        :${Fin} $(check_port 22)"
  echo -e "  ${Blanco}• Dropbear (Puertos 110/90) :${Fin} $(check_port 110)"
  echo -e "  ${Blanco}• SSL Tunnel (Puerto 443)    :${Fin} $(check_port 443)"
  echo -e "  ${Blanco}• V2Ray (VLESS/VMess 80/8080):${Fin} $(check_port 10080)"
  echo -e "  ${Blanco}• WS Proxy (Puertos 80/8080):${Fin} $(check_port 8080)"
  echo -e "  ${Blanco}• BadVPN UDPGW (Puerto 7300):${Fin} $(check_port 7300)"
  echo -e "  ${Blanco}• Auto-Inicio del Menú     :${Fin} $(check_autostart)"
  echo -e "${Cian}=====================================================================\e[0m"
  echo -e " ${Blanco}Hora actual :${Fin} ${Amarillo}$(date +%T)${Fin}"
  echo -e " ${Blanco}Firma       :${Fin} ${Magenta}RUSSO NETFREE VIP${Fin}"
  echo -e "${Cian}=====================================================================\e[0m"
  echo -e " ${Cian}[01]${Fin} ${Blanco}Crear Usuario${Fin}"
  echo -e " ${Cian}[02]${Fin} ${Blanco}Cambiar Contraseña${Fin}"
  echo -e " ${Cian}[03]${Fin} ${Blanco}Eliminar Usuario${Fin}"
  echo -e " ${Cian}[04]${Fin} ${Verde}Mostrar Usuarios Registrados (Usuario / Contraseña / Estado)${Fin}"
  echo -e " ${Cian}[05]${Fin} ${Blanco}Reiniciar WebSocket (Puertos 80 y 8080)${Fin}"
  echo -e " ${Cian}[06]${Fin} ${Blanco}Instalar / Activar Dropbear (Puertos 110/90)${Fin}"
  echo -e " ${Cian}[07]${Fin} ${Blanco}Instalar / Activar SSL Tunnel (Puerto 443)${Fin}"
  echo -e " ${Cian}[08]${Fin} ${Blanco}Instalar / Activar V2Ray en Puerto 8080/80${Fin}"
  echo -e " ${Cian}[09]${Fin} ${Verde}Obtener Enlace VMess / Información V2Ray${Fin}"
  echo -e " ${Cian}[10]${Fin} ${Blanco}Reiniciar/Activar BadVPN UDPGW (Puerto 7300)${Fin}"
  echo -e " ${Cian}[11]${Fin} ${Blanco}Configurar / Modificar Banner SSH${Fin}"
  echo -e " ${Cian}[12]${Fin} ${Blanco}Activar / Desactivar Auto-inicio del Menú${Fin}"
  echo -e " ${Cian}[00]${Fin} ${Rojo}Salir${Fin}"
  echo -e "${Cian}=====================================================================\e[0m"
  read -p " Elige una opción [0-12]: " opcion

  case $opcion in
    1)
      echo -e ""
      read -p " Nombre del nuevo usuario: " nuevo_user
      if id "$nuevo_user" &>/dev/null; then
        echo -e "${Rojo}[-] El usuario '$nuevo_user' ya existe.${Fin}"
      else
        read -s -p " Contraseña para $nuevo_user: " nuevo_pass
        echo -e ""
        useradd -m -s /bin/bash "$nuevo_user"
        echo "$nuevo_user:$nuevo_pass" | chpasswd
        
        touch "$PASS_FILE"
        sed -i "/^$nuevo_user:/d" "$PASS_FILE" 2>/dev/null
        echo "$nuevo_user:$nuevo_pass" >> "$PASS_FILE"

        echo -e "${Verde}[+] Usuario '$nuevo_user' creado con éxito.${Fin}"
      fi
      read -p " Presiona [Enter] para continuar..."
      ;;
    2)
      read -p " Usuario al que deseas cambiar la contraseña: " mod_user
      if id "$mod_user" &>/dev/null; then
        read -s -p " Nueva contraseña para $mod_user: " nueva_pass
        echo -e ""
        echo "$mod_user:$nueva_pass" | chpasswd
        
        touch "$PASS_FILE"
        sed -i "/^$mod_user:/d" "$PASS_FILE"
        echo "$mod_user:$nueva_pass" >> "$PASS_FILE"

        echo -e "${Verde}[+] Contraseña de '$mod_user' actualizada correctamente.${Fin}"
      else
        echo -e "${Rojo}[-] El usuario no existe.${Fin}"
      fi
      read -p " Presiona [Enter] para continuar..."
      ;;
    3)
      read -p " Usuario a eliminar: " del_user
      if id "$del_user" &>/dev/null; then
        userdel -r "$del_user"
        sed -i "/^$del_user:/d" "$PASS_FILE" 2>/dev/null
        echo -e "${Verde}[+] Usuario '$del_user' eliminado correctamente.${Fin}"
      else
        echo -e "${Rojo}[-] El usuario no existe.${Fin}"
      fi
      read -p " Presiona [Enter] para continuar..."
      ;;
    4)
      listar_usuarios_estado
      ;;
    5)
      echo -e ""
      echo -e "${Cian}[*] Reiniciando WebSocket Proxy en puertos 80 y 8080...${Fin}"
      systemctl restart ws_proxy.service 2>/dev/null
      echo -e "${Verde}[+] WebSocket activo correctamente.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    6)
      gestionar_dropbear
      read -p " Presiona [Enter] para continuar..."
      ;;
    7)
      gestionar_stunnel
      read -p " Presiona [Enter] para continuar..."
      ;;
    8)
      gestionar_v2ray
      read -p " Presiona [Enter] para continuar..."
      ;;
    9)
      obtener_informacion_v2ray
      ;;
    10)
      instalar_badvpn
      read -p " Presiona [Enter] para continuar..."
      ;;
    11)
      configurar_banner
      read -p " Presiona [Enter] para continuar..."
      ;;
    12)
      gestionar_autostart
      read -p " Presiona [Enter] para continuar..."
      ;;
    0)
      echo -e "${Amarillo}Saliendo del panel... ¡Disfruta RUSSO NETFREE VIP!${Fin}"
      exit 0
      ;;
    *)
      echo -e "${Rojo}Opción no válida.${Fin}"
      sleep 1
      ;;
  esac
done
