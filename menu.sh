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

      # Conteo exacto por procesos de Dropbear y SSH
      local total_con=$(ps -u "$u" 2>/dev/null | grep -E "dropbear|sshd" | wc -l)

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
