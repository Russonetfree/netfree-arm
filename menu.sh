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
  echo -e "\e[1;36m====================================================\e[0m"
  echo -e "\e[1;33m    INSTALANDO DEPENDENCIAS - RUSSO NETFREE         \e[0m"
  echo -e "\e[1;36m====================================================\e[0m"
  echo -e "\e[1;37m[*] Actualizando sistema e instalando herramientas...\e[0m"
  
  # Instalación 100% silenciosa
  export DEBIAN_FRONTEND=noninteractive
  apt update -y && apt-get upgrade -y -o Dpkg::Options::="--force-confold"
  apt install -y python3 python3-pip curl wget git net-tools iptables build-essential cmake

  echo -e "\e[1;37m[*] Configurando reglas de red y liberando firewall...\e[0m"
  # Liberar puertos en iptables automáticamente
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

  echo -e "\e[1;37m[*] Configurando e iniciando WebSocket en Puerto 80...\e[0m"
  # Crear script del proxy WebSocket
  cat << 'EOF' > /usr/local/bin/ws_proxy.py
import socket, select, threading

def handle_client(client_sock):
    try:
        request = client_sock.recv(4096)
        if not request:
            client_sock.close()
            return
        ssh_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_sock.connect(('127.0.0.1', 22))
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

def start_proxy():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', 80))
    s.listen(500)
    while True:
        client, _ = s.accept()
        threading.Thread(target=handle_client, args=(client,)).start()

if __name__ == '__main__':
    start_proxy()
EOF

  # Iniciar WebSocket al instalar
  pkill -f ws_proxy.py 2>/dev/null
  nohup python3 /usr/local/bin/ws_proxy.py > /dev/null 2>&1 &
  
  touch "$INSTALL_CHECK"
  echo -e "\e[1;32m[+] ¡Instalación y configuración completadas automáticamente!\e[0m"
  sleep 2
fi

# Colores elegantes
Rojo="\e[1;31m"
Verde="\e[1;32m"
Amarillo="\e[1;33m"
Cian="\e[1;36m"
Blanco="\e[1;37m"
Magenta="\e[1;35m"
Fin="\e[0m"

# Función para instalar y ejecutar BadVPN (udpgw)
instalar_badvpn() {
  echo -e ""
  echo -e "${Cian}[*] Verificando e instalando dependencias para BadVPN...${Fin}"
  apt update -y && apt install cmake build-essential git -y

  if [ ! -f /usr/local/bin/badvpn-udpgw ]; then
    echo -e "${Cian}[*] Descargando y compilando BadVPN...${Fin}"
    cd /tmp
    git clone https://github.com/ambrop72/badvpn.git
    mkdir /tmp/badvpn/build
    cd /tmp/badvpn/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make
    cp badvpn-udpgw /usr/local/bin/
    rm -rf /tmp/badvpn
  fi

  echo -e "${Verde}[*] Iniciando BadVPN UDPGW en el puerto 7300...${Fin}"
  pkill badvpn-udpgw 2>/dev/null
  nohup /usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 8 > /dev/null 2>&1 &
  
  echo -e "${Verde}[+] BadVPN (UDP Gateway) activo correctamente en el puerto 7300.${Fin}"
}

while true; do
  clear
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Amarillo}          ⚡ RUSSO NETFREE - PANEL VIP ⚡          ${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e "${Blanco} Sistema : ${Verde}$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f2)${Fin}"
  echo -e "${Blanco} Hora    : ${Verde}$(date +%T)${Fin}"
  echo -e "${Blanco} Firma   : ${Magenta}RUSSO NETFREE${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  echo -e " ${Cian}[01]${Fin} ${Blanco}Crear Usuario${Fin}"
  echo -e " ${Cian}[02]${Fin} ${Blanco}Cambiar Contraseña${Fin}"
  echo -e " ${Cian}[03]${Fin} ${Blanco}Eliminar Usuario${Fin}"
  echo -e " ${Cian}[04]${Fin} ${Blanco}Listar Usuarios${Fin}"
  echo -e " ${Cian}[05]${Fin} ${Blanco}Reiniciar Servicio WebSocket (Puerto 80)${Fin}"
  echo -e " ${Cian}[06]${Fin} ${Blanco}Activar BadVPN UDPGW (Puerto 7300)${Fin}"
  echo -e " ${Cian}[00]${Fin} ${Rojo}Salir${Fin}"
  echo -e "${Cian}====================================================${Fin}"
  read -p " Elige una opción [0-6]: " opcion

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
      echo -e ""
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
      echo -e ""
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
      echo -e "${Cian}[*] Reiniciando servicio WebSocket Proxy en puerto 80...${Fin}"
      pkill -f ws_proxy.py 2>/dev/null
      nohup python3 /usr/local/bin/ws_proxy.py > /dev/null 2>&1 &
      echo -e "${Verde}[+] Servicio WebSocket activo correctamente en el puerto 80.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    6)
      instalar_badvpn
      read -p " Presiona [Enter] para continuar..."
      ;;
    0)
      echo -e "${Amarillo}Saliendo del panel... ¡Disfruta RUSSO NETFREE!${Fin}"
      exit 0
      ;;
    *)
      echo -e "${Rojo}Opción no válida.${Fin}"
      sleep 1
      ;;
  esac
done
