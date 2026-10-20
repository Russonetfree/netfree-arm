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
    # INSTALACIÓN AUTOMÁTICA Y CREACIÓN DEL MENÚ INTERACTIVO
    # =========================================================
    BIN_DIR="/usr/local/bin"
    REPO_URL="https://raw.githubusercontent.com/Russonetfree/netfree-arm/main"

    # Guardar registro de activación
    mkdir -p /etc/netfree
    echo "$USER_KEY" > /etc/netfree/license.key

    # Descargar módulos si existen en el repositorio
    wget -qO $BIN_DIR/crearusuario $REPO_URL/crearusuario.sh 2>/dev/null
    wget -qO $BIN_DIR/removerusuario $REPO_URL/removerusuario.sh 2>/dev/null
    wget -qO $BIN_DIR/online $REPO_URL/online.sh 2>/dev/null

    # Crear el menú principal interactivo del cliente
    cat << 'EOF' > $BIN_DIR/panel_menu.sh
#!/bin/bash
clear
echo -e "\033[1;33m==========================================\033[0m"
echo -e "\033[1;36m       PANEL DE CONTROL RUSSO VIP         \033[0m"
echo -e "\033[1;33m==========================================\033[0m"
echo -e "1) Crear Usuario SSH"
echo -e "2) Eliminar Usuario SSH"
echo -e "3) Ver Usuarios Online"
echo -e "0) Salir"
echo -e "\033[1;33m==========================================\033[0m"
read -p "Seleccione una opción: " OPCION

case $OPCION in
    1) crearusuario 2>/dev/null || echo "Opción en desarrollo" ;;
    2) removerusuario 2>/dev/null || echo "Opción en desarrollo" ;;
    3) online 2>/dev/null || echo "Opción en desarrollo" ;;
    0) exit 0 ;;
    *) echo "Opción inválida" ;;
esac
EOF

    chmod +x $BIN_DIR/* 2>/dev/null

    echo -e "\n\033[1;32m🚀 ¡Instalación completada exitosamente!\033[0m"
    echo -e "\033[1;33mAbriendo panel de control...\033[0m"
    sleep 2

    # Iniciar el panel interactivo directamente
    bash $BIN_DIR/panel_menu.sh

else
    echo -e "\n\033[1;31m❌ Licencia inválida, expirada o ya utilizada.\033[0m"
    exit 1
fi
