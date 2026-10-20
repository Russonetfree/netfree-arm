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
    echo -e "\033[1;32m✅ ¡Licencia Válida! Iniciando instalación completa...\033[0m"
    sleep 2

    # Guardar registro de activación
    mkdir -p /etc/netfree
    echo "$USER_KEY" > /etc/netfree/license.key

    # =========================================================
    # INSTALACIÓN REAL DE PAQUETES Y DEPENDENCIAS DEL SISTEMA
    # =========================================================
    echo -e "\n\033[1;36m📦 Actualizando e instalando paquetes requeridos (SSH, BadVPN, Curl, Screen)...\033[0m"
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl wget screen net-tools openssh-server stunnel4 python3 python3-pip >/dev/null 2>&1

    # Asegurar directorio de binarios
    mkdir -p /usr/local/bin

    # Crear la orden directa 'menu' en el sistema
    cat << 'EOF' > /usr/local/bin/menu
#!/bin/bash
clear
while true; do
echo -e "\033[1;33m=====================================================\033[0m"
echo -e "\033[1;36m           PANEL DE CONTROL - RUSSO NETFREE           \033[0m"
echo -e "\033[1;33m=====================================================\033[0m"
echo -e "\033[1;32m 1)\033[0m Crear Usuario SSH"
echo -e "\033[1;32m 2)\033[0m Eliminar / Remover Usuario"
echo -e "\033[1;32m 3)\033[0m Ver Usuarios Conectados / Online"
echo -e "\033[1;32m 4)\033[0m Reiniciar Servicios del Sistema"
echo -e "\033[1;31m 0) Salir\033[0m"
echo -e "\033[1;33m=====================================================\033[0m"
read -p " Seleccione una opción: " opcion

case $opcion in
    1)
        read -p "Nombre de usuario: " usuario
        read -p "Contraseña: " pass
        read -p "Días de duración: " dias
        useradd -M -s /bin/false "$usuario" 2>/dev/null
        echo "$usuario:$pass" | chpasswd
        echo -e "\033[1;32m✅ Usuario $usuario creado exitosamente.\033[0m"
        sleep 2
        ;;
    2)
        read -p "Usuario a eliminar: " usuario
        userdel -f "$usuario" 2>/dev/null
        echo -e "\033[1;31m❌ Usuario $usuario eliminado.\033[0m"
        sleep 2
        ;;
    3)
        echo -e "\033[1;36m👥 Usuarios en línea:\033[0m"
        ps -ef | grep sshd | grep -v root | grep -v grep
        read -p "Presione Enter para continuar..."
        ;;
    4)
        systemctl restart ssh 2>/dev/null || service ssh restart
        echo -e "\033[1;32m🔄 Servicios reiniciados correctamente.\033[0m"
        sleep 2
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "\033[1;31mOpción inválida.\033[0m"
        sleep 1
        ;;
esac
done
EOF

    # Permisos de ejecución
    chmod +x /usr/local/bin/menu

    echo -e "\n\033[1;32m🚀 ¡Instalación real completada exitosamente!\033[0m"
    echo -e "\033[1;33mCargando el panel de control...\033[0m"
    sleep 2

    # Iniciar el panel directamente
    /usr/local/bin/menu

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
