#!/bin/bash
# criar_usuario_massa_zabbix.sh
set -euo pipefail

# === CONFIG ===
ZABBIX_URL="http://192.168.3.15/api_jsonrpc.php"
API_TOKEN="cc59e3f0280a8fef5a9e10f97523a95d5b4c519164bd52541aff4a11d256b7e4"
ROLE_ID=5             # role "Aluno" (ajuste se necessário)
DEFAULT_PASS="Senha@123"
CSV_FILE="${1:-usuarios.csv}"   # passe o CSV como 1º argumento ou deixe o padrão

# === PRÉ-REQUISITOS ===
need() { 
  command -v "$1" >/dev/null || { 
    echo "Falta a dependência: $1"; exit 1; 
  }; 
}
need curl; need jq


# === FUNÇÕES === #

# Coleta os dados de cada linha do arquivo do .csv
mapfile -t linhas < "$CSV_FILE"

for ((i=1; i<${#linhas[@]}; i++))
do
  linha="${linhas[i]%$'\r'}"
  IFS=, read -r -a campos <<< "$linha"

  var="USER_DATA_$i"
  declare -g -a "$var"
  declare -n ref="$var"
  ref=("${campos[@]}")
  unset -n ref
done
echo "Linha 1 → ${USER_DATA_1[0]} | ${USER_DATA_1[1]} | ${USER_DATA_1[2]} | ${USER_DATA_1[3]}"
echo "Linha 2 → ${USER_DATA_2[0]} | ${USER_DATA_2[1]} | ${USER_DATA_2[2]} | ${USER_DATA_2[3]}"

# # Coleta nomes dos grupos dos usuários do arquivo .csv
# user_group() {
#   UGP_LIST=$(cat $CSV_FILE | grep -v "Login" | awk -F, '{ print $3}')
#   echo "$UGP_LIST"
# }
# user_group






# # API
# api(){
#   local payload=$1
#   curl --silent --request POST \
#        --url "${ZABBIX_URL}" \
#        --header 'Content-Type: application/json-rpc' \
#        --header "Authorization: Bearer ${API_TOKEN}" \
#        --data "${payload}" 
# }
# # === FIM DASFUNÇÕES === #


# # === GRUPOS DE USUÁRIOS === #

# # Verificar se o usuario existe
# api '{
#         "jsonrpc": "2.0",
#         "method": "usergroup.get",
#         "params": {
#         "output": "extend"
#       },
#         "id": 1
#       }'
