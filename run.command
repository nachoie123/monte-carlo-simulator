#!/bin/bash
# Doble clic para arrancar el Monte Carlo Simulator y abrirlo en el navegador.
cd "$(dirname "$0")" || exit 1
python3 server.py &
SERVER_PID=$!
sleep 1
open "http://localhost:8000"
echo "Monte Carlo Simulator corriendo en http://localhost:8000"
echo "Cierra esta ventana (o Ctrl+C) para pararlo."
wait $SERVER_PID
