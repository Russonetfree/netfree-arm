#!/bin/bash

# ==========================================
# VALIDACIÓN DE LICENCIA Y CONFIGURACIÓN - RUSSO VIP
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
    echo -e "\033[1;32m✅ ¡Licencia Válida! Iniciando instalación y configuración...\033[0m"
    sleep 2
    
    # =========================================================
    # DESCARGA E INSTALACIÓN DE LOS SCRIPTS DEL REPOSITORIO
    # =========================================================
    echo -e "\n\033[1;36m📥 Descargando archivos del sistema desde GitHub...\033[0m"
    
    # Crear directorio de trabajo si no existe
    mkdir -p /etc/netfree
    cd /etc/netfree

    # Descargar el script de instalación principal o los módulos de configuración
    # (Asegúrate de tener un archivo como 'setup.sh' o 'install.sh' en tu repositorio netfree-arm)
    wget -qO setup.sh https://raw.githubusercontent.com/Russonetfree/netfree-arm/main/setup.sh
    
    if [ -f "setup.sh" ]; then
        chmod +x setup.sh
        ./setup.sh
    else
        echo -e "\n\033[1;31m❌ Error al descargar los archivos de configuración.\033[0m"
        exit 1
    fi

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
