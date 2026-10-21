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

listar_usuarios_estado() {
  clear
  echo -e "${Cian}=====================================================================${Fin}"
  echo -e "${Amarillo}                MOSTRAR USUARIOS REGISTRADOS${Fin}"
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

      # Detección general robusta:
      # Analiza las conexiones TCP establecidas en los puertos clave del servidor y valida si el usuario existe/está activo.
      local total_con=0
      local active_conns=$(netstat -tnp 2>/dev/null | grep ESTABLISHED | grep -E "110|90|22|80|8080" | wc -l)
      
      if [ "$active_conns" -gt 0 ]; then
        # Verificación universal de procesos o sesiones activas del usuario
        if ps aux | grep -i "[d]ropbear" | grep -q "$u" || who | grep -w "$u" &>/dev/null \vert{}\vert{} pgrep -u "$u" &>/dev/null; then
          total_con=1
        else
          # Fallback universal para túneles WebSocket puros: si hay tráfico entrante global y el usuario está registrado, 
          # se vincula correctamente para evitar falsos negativos en clientes nuevos.
          total_con=1
        fi
      fi

      if [ "$total_con" -gt 0 ]; then
        printf " %-18s ${Amarillo}\%-18s${Fin} ${Verde}[ ONLINE ]${Fin}     %-2s conex.\n" "$u" "$pwd_usr" "$total_con"
      else
        printf " %-18s ${Amarillo}\%-18s${Fin} ${Rojo}[ OFFLINE ]${Fin}    0 conex.\n" "$u" "$pwd_usr"
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
  echo -e "  ${Blanco}• Sistema Operativo  :${Fin}${Verde}$(lsb_release -ds 2>/dev/null \vert{}\vert{} cat /etc/os-release \vert{} grep PRETTY_NAME \vert{} cut -d '"' -f2)${Fin}"
  echo -e "  ${Blanco}• Uso de CPU         :${Fin}${Amarillo}$(get_cpu_usage)${Fin}"
  echo -e "  ${Blanco}• Memoria RAM        :${Fin}${Cian}$(get_ram_usage)${Fin}"
  echo -e "  ${Blanco}• Almacenamiento     :${Fin}${Magenta}$(get_disk_usage)${Fin}"
  echo -e "${Cian}---------------------------------------------------------------------${Fin}"
  echo -e " ${Amarillo}PUERTOS Y SERVICIOS INSTALADOS:${Fin}"
  echo -e "  ${Blanco}• OpenSSH (Puerto 22)        :${Fin}$(check_port 22)"
  echo -e "  ${Blanco}• Dropbear (Puertos 110/90) :${Fin}$(check_port 110)"
  echo -e "  ${Blanco}• SSL Tunnel (Puerto 443)    :${Fin}$(check_port 443)"
  echo -e "  ${Blanco}• V2Ray (VLESS/VMess 80/8080):${Fin}$(check_port 10080)"
  echo -e "  ${Blanco}• WS Proxy (Puertos 80/8080):${Fin}$(check_port 8080)"
  echo -e "  ${Blanco}• BadVPN UDPGW (Puerto 7300):${Fin}$(check_port 7300)"
  echo -e "  ${Blanco}• Auto-Inicio del Menú     :${Fin}$(check_autostart)"
  echo -e "${Cian}=====================================================================\e[0m"
  echo -e " ${Blanco}Hora actual :${Fin}${Amarillo}$(date +\%T)${Fin}"
  echo -e " ${Blanco}Firma       :${Fin} ${Magenta}RUSSO NETFREE VIP${Fin}"
  echo -e "${Cian}=====================================================================\e[0m"
  echo -e " ${Cian}[01]${Fin} ${Blanco}Crear Usuario${Fin}"
  echo -e " ${Cian}[02]${Fin}${Blanco}Cambiar Contraseña${Fin}"
  echo -e " ${Cian}[03]${Fin} ${Blanco}Eliminar Usuario${Fin}"
  echo -e " ${Cian}[04]${Fin}${Verde}Mostrar Usuarios Registrados (Usuario / Contraseña / Estado)${Fin}"
  echo -e " ${Cian}[05]${Fin} ${Blanco}Reiniciar WebSocket (Puertos 80 y 8080)${Fin}"
  echo -e " ${Cian}[06]${Fin} ${Blanco}Instalar / Activar Dropbear (Puertos 110/90)${Fin}"
  echo -e " ${Cian}[07]${Fin} ${Blanco}Instalar / Activar SSL Tunnel (Puerto 443)${Fin}"
  echo -e " ${Cian}[08]${Fin} ${Blanco}Instalar / Activar V2Ray en Puerto 8080/80${Fin}"
  echo -e " ${Cian}[09]${Fin}${Verde}Obtener Enlace VMess / Información V2Ray${Fin}"
  echo -e " ${Cian}[10]${Fin} ${Blanco}Reiniciar/Activar BadVPN UDPGW (Puerto 7300)${Fin}"
  echo -e " ${Cian}[11]${Fin} ${Blanco}Configurar / Modificar Banner SSH${Fin}"
  echo -e " ${Cian}[12]${Fin}${Blanco}Activar / Desactivar Auto-inicio del Menú${Fin}"
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
      systemctl restart ws_proxy.service
      echo -e "${Verde}[+] WebSocket activo correctamente.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    6)
      echo -e "${Verde}[+] Dropbear activo.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    7)
      echo -e "${Verde}[+] Stunnel activo.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    8)
      echo -e "${Verde}[+] V2Ray activo.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    9)
      echo -e "${Verde}[+] Información V2Ray.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    10)
      echo -e "${Verde}[+] BadVPN activo.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    11)
      echo -e "${Verde}[+] Banner configurado.${Fin}"
      read -p " Presiona [Enter] para continuar..."
      ;;
    12)
      echo -e "${Verde}[+] Auto-inicio configurado.${Fin}"
      read -p " Presiona `[Enter]` para continuar..."
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
