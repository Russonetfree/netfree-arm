#!/bin/bash

# Verificar que se ejecute como usuario root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[-] Este script debe ejecutarse como root (sudo -i).\e[0m"
  exit 1
fi

# Archivo de control para la primera instalación
INSTALL_CHECK="/etc/russo_installed"

if [ ! -f "$INSTALL_CHECK" ]; then
  clear
  echo -e "\e[1;96m====================================================\e[0m"
  echo -e "\e[1;93m    INSTALANDO AUTOMÁTICAMENTE - RUSSO NETFREE      \e[0m"
  echo -e "\e[1;96m====================================================\e[0m"
  echo -e "\e[1;97m[*] Actualizando sistema e instalando herramientas...\e[0m"
  
  # Modo 100% no interactivo para instalación limpia
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  
  apt-get update -y && apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
  apt-get install -y -o Dpkg::Options::="--force-confold" python3 python3-pip curl wget git net-tools iptables build-essential cmake nano lsof dropbear stunnel4 unzip

  echo -e "\e[1;97m[*] Configurando Dropbear en puertos 110 y 90...\e[0m"
  cat << 'EOF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=110
DROPBEAR_EXTRA_ARGS="-p 90"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
  systemctl enable dropbear >/dev/null 2>&1
  systemctl restart dropbear

  echo -e "\e[1;97m[*] Configurando Stunnel4 (SSL Puerto 443)...\e[0m"
  openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/CN=RussoNet/O=RussoNet/C=DO" 2>/dev/null

  cat << 'EOF' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[stunnel]
accept = 443
connect = 127.0.0.1:110
EOF

  sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
  systemctl enable stunnel4 >/dev/null 2>&1
  systemctl restart stunnel4

  echo -e "\e[1;97m[*] Configurando reglas de red y liberando firewall...\e[0m"
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

  echo -e "\e[1;97m[*] Configurando e iniciando WebSocket Proxy (Puertos 80 y 8080)...\e[0m"
  cat << 'EOF' > /usr/local/bin/ws_proxy.py
import socket, select, threading

PORTS = [80, 8080]
SSH_PORT = 110
V2RAY_INTERNAL_PORT = 10080

def handle_client(client_sock):
    try:
        request = client_sock.recv(4096)
        if not request:
            client_sock.close()
            return
        
        if b"GET /russo" in request or b"Path: /russo" in request:
            target_port = V2RAY_INTERNAL_PORT
            target_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_sock.connect(('127.0.0.1', target_port))
            target_sock.sendall(request)
        else:
            target_port = SSH_PORT
            target_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_sock.connect(('127.0.0.1', target_port))
            client_sock.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')

        sockets = [client_sock, target_sock]
        while True:
            r, w, e = select.select(sockets, [], [], 60)
            if not r: break
            if client_sock in r:
                data = client_sock.recv(4096)
                if not data: break
                target_sock.sendall(data)
            if target_sock in r:
                data = target_sock.recv(4096)
                if not data: break
                client_sock.sendall(data)
    except:
        pass
    finally:
        client_sock.close()
        try: target_sock.close()
        except: pass

def listen_port(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', port))
    s.listen(500)
    while True:
        client, _ = s.accept()
        threading.Thread(target=handle_client, args=(client,)).start()

if __name__ == '__main__':
    for p in PORTS:
        threading.Thread(target=listen_port, args=(p,)).start()
EOF

  cat << 'EOF' > /etc/systemd/system/ws_proxy.service
[Unit]
Description=WebSocket Proxy Service RUSSO
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws_proxy.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ws_proxy.service >/dev/null 2>&1
  systemctl restart ws_proxy.service

  echo -e "\e[1;97m[*] Compilando e instalando BadVPN (UDPGW)...\e[0m"
  cd /tmp
  rm -rf badvpn
  git clone https://github.com/ambrop72/badvpn.git
  mkdir -p /tmp/badvpn/build
  cd /tmp/badvpn/build
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
  make
  find /tmp/badvpn/build -name "badvpn-udpgw" -exec cp {} /usr/local/bin/ \;
  rm -rf /tmp/badvpn

  cat << 'EOF' > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDP Gateway Service
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 8
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable badvpn.service >/dev/null 2>&1
  systemctl restart badvpn.service

  # APLICAR BANNER HTML COLORIDO EXACTO
  echo -e "\e[1;97m[*] Aplicando Banner HTML a los servicios SSH...\e[0m"
  cat << 'EOF' > /etc/issue.net
<h3 style="text-align:center;">
  <font color="#FF0000">RUSSONET VPN</font> &#127916; <font color="#FF7F50">Youtube</font><br>
  &#128233; <font color="#FFAB00">Redes Sociales</font> | &#127760; <font color="#8FBC8F">Internet</font><br>
  &#128587;&#127997; <font color="#E040FB">VideoLlamadas</font> | Contacto russotvbox77@gmail.com
</h3>
EOF

  if grep -q "^Banner" /etc/ssh/sshd_config; then
    sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
  else
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
  fi

  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
  systemctl restart dropbear 2>/dev/null

  touch "$INSTALL_CHECK"
  clear
  echo -e "\e[1;92m[+] ¡Instalación completada con éxito! Abriendo panel...\e[0m"
  sleep 1
fi

# Colores brillantes ANSI
Rojo="\e[1;91m"
Verde="\e[1;92m"
Amarillo="\e[1;93m"
Azul="\e[1;94m"
Magenta="\e[1;95m"
Cian="\e[1;96m"
Blanco="\e[1;97m"
Fin="\e[0m"

# Funciones de estado y recursos
check_port() {
  local port=$1
  if netstat -tuln 2>/dev/null | grep -q ":$port " \vert{}\vert{} lsof -i :$port >/dev/null 2>&1; then
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
  
  cat << 'EOF' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=110
DROPBEAR_EXTRA_ARGS="-p 90"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

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

  cat << 'EOF' > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[stunnel]
accept = 443
connect = 127.0.0.1:110
EOF

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
  cat << 'EOF' > /usr/local/etc/v2ray/config.json
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
EOF

  systemctl enable v2ray >/dev/null 2>&1
  systemctl restart v2ray
  systemctl restart ws_proxy.service
  echo -e "${Verde}[+] V2Ray instalado correctamente.${Fin}"
}

configurar_banner() {
  echo -e ""
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}             CONFIGURAR BANNER SSH${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e " ${Cian}[1]${Fin} ${Blanco}Editar Banner en Nano${Fin}"
  echo -e " ${Cian}[2]${Fin} ${Rojo}Eliminar Banner actual${Fin}"
  echo -e " ${Cian}[0]${Fin} ${Blanco}Volver${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Elige una opción: " opc_banner
