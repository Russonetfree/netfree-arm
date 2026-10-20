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
    echo -e "\033[1;32m✅ ¡Licencia Válida! Iniciando instalación...\033[0m"
    sleep 2
    
    # =========================================================
    # AQUÍ INICIA LA INSTALACIÓN REAL DEL SISTEMA / MENÚ
    # =========================================================
    # Si tienes un script instalador en tu repositorio, se descarga y ejecuta aquí:
    
    if [ -f "/etc/NETFREE/instalado" ]; then
        # Si el sistema ya estaba instalado previamente, abre directamente el menú
        /usr/local/bin/menu_principal 2>/dev/null || exec bash
    else
        # Si es la primera vez que se instala en la VPS cliente:
        echo -e "\n\033[1;36m🚀 Descargando componentes del sistema...\033[0m"
        
        # Guardamos la marca de instalación
        mkdir -p /etc/NETFREE
        touch /etc/NETFREE/instalado
        
        # DESCARGA E INSTALACIÓN DE ARCHIVOS
        # Reemplaza o agrega aquí los scripts que tu sistema necesita instalar:
        wget -q -O /usr/local/bin/menu_principal https://raw.githubusercontent.com/Russonetfree/netfree-arm/main/instalador.sh
        chmod +x /usr/local/bin/menu_principal
        
        # Ejecuta la instalación o abre el menú principal
        bash /usr/local/bin/menu_principal
    fi

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
