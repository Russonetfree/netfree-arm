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
    echo -e "\033[1;32m✅ ¡Licencia Válida! Instalando componentes...\033[0m"
    sleep 2

    # =========================================================
    # INSTALACIÓN Y CONFIGURACIÓN AUTOMÁTICA DEL PANEL
    # =========================================================
    echo -e "\n\033[1;36m📥 Descargando e instalando herramientas en el sistema...\033[0m"

    # Directorio base de ejecutables
    BIN_DIR="/usr/local/bin"
    REPO_URL="https://raw.githubusercontent.com/Russonetfree/netfree-arm/main"

    # Lista de archivos que forman tu panel (descarga los módulos directamente)
    wget -qO $BIN_DIR/menu $REPO_URL/menu.sh
    wget -qO $BIN_DIR/crearusuario $REPO_URL/crearusuario.sh 2>/dev/null
    wget -qO $BIN_DIR/removerusuario $REPO_URL/removerusuario.sh 2>/dev/null
    wget -qO $BIN_DIR/online $REPO_URL/online.sh 2>/dev/null

    # Otorgar permisos de ejecución a todos los archivos descargados
    chmod +x $BIN_DIR/* 2>/dev/null

    # Guardar registro de activación
    mkdir -p /etc/netfree
    echo "$USER_KEY" > /etc/netfree/license.key

    echo -e "\n\033[1;32m🚀 ¡Instalación completada exitosamente!\033[0m"
    echo -e "\033[1;33mPuedes abrir este menú en cualquier momento escribiendo: \033[1;36mmenu\033[0m"
    sleep 3

    # Iniciar la interfaz principal (si existe un script secundario de panel, o reiniciar bash)
    if [ -f "$BIN_DIR/menu_panel" ]; then
        bash $BIN_DIR/menu_panel
    else
        echo -e "\n\033[1;32mAcceso concedido. Sistema listo para operar.\033[0m"
    fi

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
