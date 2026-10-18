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
  echo -e "\e[1;93m    INSTALANDO DEPENDENCIAS - RUSSO NETFREE         \e[0m"
  echo -e "\e[1;96m====================================================\e[0m"
  echo -e "\e[1;97m[*] Actualizando sistema e instalando herramientas...\e[0m"
  
  # Modo 100% no interactivo para evitar pantallas de configuración
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  
  apt-get update -y && apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
  apt-get install -y -o Dpkg::Options::="--force-confold" python3 python3-pip curl wget git net-tools iptables build-essential cmake nano lsof dropbear stunnel4

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
TARGET_PORT = 110  # Redirige a Dropbear

def handle_client(client_sock):
    try:
        request = client_sock.recv(4096)
        if not request:
            client_sock.close()
            return
        ssh_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_sock.connect(('127.0.0.1', TARGET_PORT))
        client_sock.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
        sockets = [client_sock, ssh_sock]
        while True:
            r, w, e = select.select(sockets, [], [], 60)
            if not r: break
            if client_sock in r:
                data = client_sock.recv(4096)
                if not data: break
                ssh_sock.sendall(data)
            if ssh_sock in r:
                data = ssh_sock.recv(4096)
                if not data: break
                client_sock.sendall(data)
    except:
        pass
    finally:
        client_sock.close()
        try: ssh_sock.close()
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

  echo -e "\e[1;97m[*] Aplicando Banner por defecto...\e[0m"
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

  touch "$INSTALL_CHECK"
  echo -e "\e[1;92m[+] ¡Instalación y configuración completadas automáticamente!\e[0m"
  sleep 2
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

# Función para verificar el estado de un puerto/servicio
check_port() {
  local port=$1
  if netstat -tuln 2>/dev/null | grep -q ":$port " || lsof -i :$port >/dev/null 2>&1; then
    echo -e "${Verde}[ ONLINE ]${Fin}"
  else
    echo -e "${Rojo}[ OFFLINE ]${Fin}"
  fi
}

# Función para verificar auto-inicio
check_autostart() {
  if grep -q "^menu$" /root/.bashrc 2>/dev/null; then
    echo -e "${Verde}[ ONLINE ]${Fin}"
  else
    echo -e "${Rojo}[ OFFLINE ]${Fin}"
  fi
}

# Funciones de recursos de la VPS
get_cpu_usage() {
  read cpu a b c previdle rest < /proc/stat
  prevtotal=$((a+b+c+previdle))
  sleep 0.3
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

# Función para instalar/activar Dropbear
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
  echo -e "${Verde}[+] Dropbear activo correctamente en los puertos 110 y 90.${Fin}"
}

# Función para instalar/activar Stunnel4 (SSL Puerto 443)
gestionar_stunnel() {
  echo -e ""
  echo -e "${Cian}[*] Instalando y configurando SSL Tunnel (Stunnel4 en puerto 443)...${Fin}"
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
  echo -e "${Verde}[+] SSL Tunnel (Stunnel4) activo y escuchando en el puerto 443.${Fin}"
}

# Función para configurar o modificar el banner SSH
configurar_banner() {
  echo -e ""
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}             CONFIGURAR BANNER SSH                 ${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e " ${Cian}[1]${Fin} ${Blanco}Editar Banner en Nano${Fin}"
  echo -e " ${Cian}[2]${Fin} ${Rojo}Eliminar Banner actual${Fin}"
  echo -e " ${Cian}[0]${Fin} ${Blanco}Volver${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Elige una opción: " opc_banner

  case $opc_banner in
    1)
      nano /etc/issue.net
      if grep -q "^Banner" /etc/ssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
      else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
      fi
      systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
      systemctl restart dropbear 2>/dev/null
      systemctl restart stunnel4 2>/dev/null
      echo -e "${Verde}[+] ¡Banner actualizado y aplicado!${Fin}"
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

# Función para gestionar el Auto-inicio del Menú al iniciar sesión
gestionar_autostart() {
  echo -e ""
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}             AUTO-INICIO DEL MENÚ                  ${Fin}"
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
      echo -e "${Verde}[+] ¡Auto-inicio activado con éxito!${Fin}"
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

# Función para reiniciar/gestionar BadVPN (udpgw) como servicio persistente
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

  echo -e "${Verde}[*] Configurando BadVPN UDPGW como servicio persistente...${Fin}"
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
  
  echo -e "${Verde}[+] BadVPN activo de forma permanente en el puerto 7300.${Fin}"
}

while true; do
  clear
  # Banner Gigante ASCII con Degradado Multicolor
  echo -e "\e[1;92m   ____  _   _ ____ ____   ___ \e[1;93m _   _ _____ _____ _____ ____  _____ \e[0m"
  echo -e "\e[1;92m  |  _ \| | | / ___/ ___| / _ \ \e[1;93m| \ | | ____|_   _| ____|  _ \| ____|\e[0m"
  echo -e "\e[1;93m  | |_) | | | \___ \___ \| | | |\e[1;91m|  \| |  _|   | | |  _| | |_) |  _|  \e[0m"
  echo -e "\e[1;93m  |  _ <| |_| |___) |__) | |_| |\e[1;91m| |\  | |___  | | | |___|  _ <| |___ \e[0m"
  echo -e "\e[1;91m  |_| \_\\___/|____/____/ \___/ \e[1;95m|_| \_|_____| |_| |_____|_| \_\_____|\e[0m"
  echo -e "\e[1;95m                             [ PANEL VIP ]                             \e[0m"
  echo -e "${Cian}=====================================================================${Fin}"
  
  # SECCIÓN DE ESTADO DE RECURSOS DE LA VPS (SISTEMA, CPU, RAM Y DISCO)
  echo -e " ${Amarillo}ESTADO Y CAPACIDAD DE LA VPS:${Fin}"
  echo -e "  ${Blanco}• Sistema Operativo  :${Fin} ${Verde}$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f2)${Fin}"
  echo -e "  ${Blanco}• Uso de CPU         :${Fin} ${Amarillo}$(get_cpu_usage)${Fin}"
  echo -e "  ${Blanco}• Memoria RAM        :${Fin} ${Cian}$(get_ram_usage)${Fin}"
  echo -e "  ${Blanco}• Almacenamiento     :${Fin} ${Magenta}$(get_disk_usage)${Fin}"
  echo -e "${Cian}---------------------------------------------------------------------${Fin}"
  echo -e " ${Amarillo}PUERTOS Y SERVICIOS INSTALADOS:${Fin}"
  echo -e "  ${Blanco}• OpenSSH (Puerto 22)       :${Fin} $(check_port 22)"
  echo -e "  ${Blanco}• Dropbear (Puertos 110/90) :${Fin} $(check_port 110)"
  echo -e "  ${Blanco}• SSL Tunnel (Puerto 443)    :${Fin} $(check_port 443)"
  echo -e "  ${Blanco}• WS Proxy (Puerto 80)      :${Fin} $(check_port 80)"
  echo -e "  ${Blanco}• WS Proxy (Puerto 8080)    :${Fin} $(check_port 8080)"
  echo -e "  ${Blanco}• BadVPN UDPGW (Puerto 7300):${Fin} $(check_port 7300)"
  echo -e "  ${Blanco}• Auto-Inicio del Menú     :${Fin} $(check_autostart)"
  echo -e "${Cian}=====================================================================${Fin}"
  echo -e " ${Blanco}Hora actual :${Fin} ${Amarillo}$(date +%T)${Fin}"
  echo -e " ${Blanco}Firma       :${Fin} ${Magenta}RUSSO NETFREE VIP${Fin}"
  echo -e "${Cian}=====================================================================${Fin}"
  echo -e " ${Cian}[01]${Fin} ${Blanco}Crear Usuario${Fin}"
  echo -e " ${Cian}[02]${Fin} ${Blanco}Cambiar Contraseña${Fin}"
  echo -e " ${Cian}[03]${Fin} ${Blanco}Eliminar Usuario${Fin}"
  echo -e " ${Cian}[04]${Fin} ${Blanco}Listar Usuarios${Fin}"
  echo -e " ${Cian}[05]${Fin} ${Blanco}Reiniciar WebSocket (Puertos 80 y 8080)${Fin}"
  echo -e " ${Cian}[06]${Fin} ${Blanco}Instalar / Activar Dropbear (Puertos 110/90)${Fin}"
  echo -e " ${Cian}[07]${Fin} ${Blanco}Instalar / Activar SSL Tunnel (Puerto 443)${Fin}"
  echo -e " ${Cian}[08]${Fin} ${Blanco}Reiniciar/Activar BadVPN UDPGW (Puerto 7300)${Fin}"
  echo -e " ${Cian}[09]${Fin} ${Blanco}Configurar / Modificar Banner SSH${Fin}"
  echo -e " ${Cian}[10]${Fin} ${Blanco}Activar / Desactivar Auto-inicio del Menú${Fin}"
  echo -e " ${Cian}[00]${Fin} ${Rojo}Salir${Fin}"
  echo -e "${Cian}=====================================================================${Fin}"
  read -p " Elige una opción [0-10]: " opcion

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
        echo -e "${Verde}[+] Usuario '$del_user' eliminado correctamente.${Fin}"
      else
        echo -e "${Rojo}[-] El usuario no existe.${Fin}"
      fi
      read -p " Presiona [Enter] para continuar..."
      ;;
    4)
      echo -e ""
      echo -e "${Amarillo}=== USUARIOS DEL SISTEMA ===${Fin}"
      awk -F: '$3 >= 1000 {print $1}' /etc/passwd
      echo -e "${Amarillo}============================${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    5)
      echo -e ""
      echo -e "${Cian}[*] Reiniciando WebSocket Proxy en puertos 80 y 8080...${Fin}"
      systemctl restart ws_proxy.service
      echo -e "${Verde}[+] Servicio WebSocket activo correctamente.${Fin}"
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
      instalar_badvpn
      read -p " Presiona [Enter] para continuar..."
      ;;
    9)
      configurar_banner
      read -p " Presiona [Enter] para continuar..."
      ;;
    10)
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
