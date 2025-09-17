#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Instala Zabbix Server + Nginx + MariaDB no Debian
# ------------------------------------------------------------------------------


# === Faz o script parar se qualquer comando falhe === #
set -euo pipefail


# === Variaveis === #
ZBX_DB_NAME="zabbix"         # Nome do banco de dados
ZBX_DB_USER="zabbix"         # Nome do usuario do banco de dados
ZBX_DB_PASS="zabbix123"      # Senha do banco de dados


# === Verifica qual e o IP do servidor === #
ZBX_SERVER_IP="${ZBX_SERVER_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"


# === Verifica se o script esta sendo executado com root === #
if [[ "$(id -u)" -ne 0 ]]
then
  echo -e "\n❌ Este script precisa rodar como root (use sudo)."
  exit 1
fi


# === Verifica os dados do Sistema Operacional === #
echo -e "\n▶️  Dados do Sistema Operacional"
DEB_CODENAME="$(source /etc/os-release && echo "${VERSION_CODENAME:-}")"
DEB_NUM="$(source /etc/os-release && echo "${VERSION_ID:-}")"
echo -e "ℹ️  Debian codename detectado: ${DEB_CODENAME:-desconhecido}"
echo "ℹ️  IP detectado: ${ZBX_SERVER_IP}"


### === Funcoes === #
# === Funcao que instala pacotes === #
instala_pacotes() {
  local pacotes=$1[@]
  local array=("${!pacotes}")
  for i in "${array[@]}"
  do 
    # Verifica se o app esta instalado
    if ! dpkg --status "$i" > /dev/null 2>&1    
    then      
      # Verifica se a instalacao foi realizada com sucesso       
      if apt install -y $i > /dev/null 2>&1
      then
        echo -e "ℹ️  O pacote "$i" foi instalado."
      else
        echo -e "\n❌ Erro ao instalar o app "$i".\n⚠️ Verifique se o ser sistema é compatível com este app!"
        exit 1
      fi
    else
      echo -e "ℹ️  O pacote "$i" já está instalado."
    fi
  done
}
### === Fim das Funcoes === #


# ==== Atualizar e instala pacotes base ==== #
echo -e "\n▶️  Atualizando índices APT e instalando utilitários..."
apps=("curl" "wget" "apt-transport-https" "nmap")

# Chama a funcao reponsavel por instalar apps
instala_pacotes apps
               

# === Adicionar o repositorio do Zabbix === #
echo -e "\n▶️  Configurando repositório oficial do Zabbix..."
if ((sudo dpkg --status zabbix-release | egrep "^Version.*7\.4" ) && (sudo dpkg --status zabbix-release | grep "Status: install ok installed"))  > /dev/null 2>&1  
then
  echo "ℹ️  O repositório do Zabbix 7.4 já está instalado!"
else
  # Download do pacote Zabbix Release
  BASE_URL="https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/"
  FILE="zabbix-release_7.4-1+debian${DEB_NUM}_all.deb"
  curl -fSsLO "${BASE_URL}/${FILE}"
  
  # Instalacao do pacote Zabbix Release
  if ! dpkg -i "${FILE}"  > /dev/null 2>&1
  then
    echo -e "\n❌ Erro ao instalar o repositorio do Zabbix."
    exit 1
  else
    echo "ℹ️  O repositório do Zabbix 7.4 instalado com sucesso!"
  fi
  rm -f "${FILE}"
  apt update -y > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo -e "\n❌ Erro ao atualizar o repositorio do Zabbix."
    exit 1
  fi
fi


# === Instalar os pacotes do Zabbix === #
echo -e "\n▶️  Instalando os pacotes do Zabbix..."
ZBX_APPS=("zabbix-server-mysql" "zabbix-frontend-php" "zabbix-nginx-conf" "zabbix-sql-scripts" "zabbix-agent2")

# Chamar a funcao reponsavel por instalar apps
instala_pacotes ZBX_APPS

# Configurar o Zabbix Server
echo -e "\n▶️  Configurando  o Zabbix Server ..."
ZBX_CONF="/etc/zabbix/zabbix_server.conf"

# Ajusta parâmetros de conexao ao banco de dados
sed -ri "s|^DBName=.*|DBName=${ZBX_DB_NAME}|g" "${ZBX_CONF}"
sed -ri "s|^DBUser=.*|DBUser=${ZBX_DB_USER}|g" "${ZBX_CONF}"
sed -ri "s|^# DBPassword=.*|DBPassword=${ZBX_DB_PASS}|g" "${ZBX_CONF}"

# Habilitar o servico do Zabbix Server
systemctl enable zabbix-server.service --now > /dev/null 2>&1 
systemctl restart zabbix-server.service > /dev/null 2>&1 

if systemctl is-active --quiet zabbix-server.service; then
  echo "✅ Servico do Zabbix Server OK"
else
  echo "❌ Servico do Zabbix Server Offline"
  exit 1
fi


# === Instalar os plugins do Zabbix Agent2 === #
echo -e "\n▶️  Instalando os plugins do Zabbix Agent2..."
ZBX_APPS=("zabbix-agent2-plugin-mongodb" "zabbix-agent2-plugin-mssql" "zabbix-agent2-plugin-postgresql")

# Chama a funcao reponsavel por instalar apps
instala_pacotes ZBX_APPS

# Habilitar o servico do Zabbix Agent2
systemctl enable zabbix-agent2.service --now > /dev/null 2>&1 
systemctl restart zabbix-agent2.service > /dev/null 2>&1 

if systemctl is-active --quiet zabbix-agent2.service; then
  echo "✅ Servico do Zabbix Agent2 OK"
else
  echo "❌ Servico do Zabbix Agent2 Offline"
  exit 1
fi

# === Instalar o MariaDB === #
echo -e "\n▶️  Instalando o MariaDB..."
MDB_APPS=("mariadb-server")

# Chama a funcao reponsavel por instalar apps
instala_pacotes MDB_APPS

# Habilitar o servico do MariaDB
systemctl enable mariadb.service --now > /dev/null 2>&1 
systemctl restart mariadb.service > /dev/null 2>&1 

if systemctl is-active --quiet mariadb.service; then
  echo "✅ Servico do MariaDB OK"
else
  echo "❌ Servico do MariaDB Offline"
  exit 1
fi


# === Configurar o MariaDB === #
echo -e "\n▶️  Configurando o MariaDB..."

# Criar o banco de dados
if mariadb -u root -e "SHOW DATABASES LIKE '${ZBX_DB_NAME}';" | grep -q "${ZBX_DB_NAME}";
then
  echo "ℹ️  O Banco ${ZBX_DB_NAME} já existe"
else
  mariadb -u root -e "create database ${ZBX_DB_NAME} character set utf8mb4 collate utf8mb4_bin;"
fi

# Criar o usuario do mysql
if mariadb -u root -e "SELECT user, host FROM mysql.user WHERE user='${ZBX_DB_USER}';" > /dev/null 2>&1
then
  echo "ℹ️  O usuario ${ZBX_DB_USER} já existe"
else
  mariadb -u root -e "create user ${ZBX_DB_USER}@localhost identified by '${ZBX_DB_PASS}';"
fi

# Configurar o privilegio do usuario
if mariadb -u root -e "SHOW GRANTS FOR 'zabbix'@'localhost';" > /dev/null 2>&1
then
  echo "ℹ️  Privilegio do usuario ${ZBX_DB_USER} já existe"
else
  mariadb -u root -e "grant all privileges on ${ZBX_DB_NAME}.* to ${ZBX_DB_USER}@localhost;"
fi

# Ativar a opcao log_bin_trust_function_creators do MariaDB
if mariadb -u root -e "SELECT @@log_bin_trust_function_creators;" | grep -q 1;
then
  echo "ℹ️  A opcao log_bin_trust_function_creators ja esta ativada"
else
  mariadb -u root -e "set global log_bin_trust_function_creators = 1;"
fi


# === Importar o esquema do banco de dados === #
echo -e "\n▶️  Importando o esquema do banco de dados..."
if mariadb -u root -D zabbix -e "SHOW TABLES LIKE 'role';" | grep -q "^role$"
then
  echo "ℹ️  O esquema do banco de dados ja esta importado."
else  
  zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | \
    mariadb --default-character-set=utf8mb4 -u ${ZBX_DB_USER} -p${ZBX_DB_PASS} zabbix
fi

# === Desabilitar a opcao log_bin_trust_functions_creator
mariadb -u root -p${ZBX_DB_PASS} -e "set global log_bin_trust_function_creators = 0;"


# === Configurar o Nginx e o PHP-FPM === #
echo -e "\n▶️  Instalando o Nginx e o PHP-FPM..."
WEB_APPS=("nginx" "php-fpm" "php-xml" "php-bcmath" "php-ldap" "php-mbstring" "php-gd" "php-mysql") 

# Chama a funcao reponsavel por instalar apps
instala_pacotes WEB_APPS

# Configura o Nginx
echo -e "\n▶️  Configurando Nginx..."
cat > /etc/nginx/conf.d/zabbix.conf <<EOF
server {
    listen 80;
    server_name _;

    root /usr/share/zabbix/ui/;
    index index.php;

    location /assets/ {
        alias /usr/share/zabbix/ui/assets/;
        expires 30d;
        access_log off;
    }

    location = /favicon.ico { log_not_found off; access_log off; }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 127.0.0.1:9000;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires 7d;
        access_log off;
    }

    client_max_body_size 16m;
    sendfile on;
}
EOF

# Remove o link da configuracao padrao do Nginx
rm -f /etc/nginx/sites-enabled/default 

# Habilitar o servico do Nginx
echo -e "\n▶️  Reiniciando o Nginx..."
systemctl enable --now "nginx.service" > /dev/null 2>&1 
systemctl restart "nginx.service" > /dev/null 2>&1 

if systemctl is-active --quiet nginx.service; then
  echo "✅ Servico do Nginx OK"
else
  echo "❌ Servico do Nginx Offline"
  exit 1
fi


# Detecta versão do PHP (ex.: 8.)
PHP_VERS="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
[[ -z "${PHP_VERS}" ]] && PHP_VERS="$(ls /etc/php/ | sort -V | tail -n1 || true)"
[[ -z "${PHP_VERS}" ]] && { echo "❌ Não consegui detectar a versão do PHP."; exit 1; }
echo "ℹ️  Versão do PHP detectada: ${PHP_VERS}"

# Ajusta PHP-FPM (timezone e listen TCP:9000)
echo -e "\n▶️  Ajustando PHP-FPM..."
PHP_INI="/etc/php/${PHP_VERS}/fpm/php.ini"
PHP_POOL="/etc/php/${PHP_VERS}/fpm/pool.d/www.conf"
sed -ri "s|^;?date.timezone =.*|date.timezone = America/Sao_Paulo|g" "${PHP_INI}"
sed -ri "s|^;?listen = .*$|listen = 127.0.0.1:9000|g" "${PHP_POOL}"

# Ajustes mínimos exigidos pelo Zabbix
sudo sed -ri 's|^;?\s*post_max_size\s*=.*|post_max_size = 16M|' "$PHP_INI"
sudo sed -ri 's|^;?\s*upload_max_filesize\s*=.*|upload_max_filesize = 16M|' "$PHP_INI"
sudo sed -ri 's|^;?\s*max_execution_time\s*=.*|max_execution_time = 300|' "$PHP_INI"
sudo sed -ri 's|^;?\s*max_input_time\s*=.*|max_input_time = 300|' "$PHP_INI"

# Habilitar o servico do PHP-FPM
systemctl enable "php${PHP_VERS}-fpm" > /dev/null 2>&1 
systemctl restart "php${PHP_VERS}-fpm" > /dev/null 2>&1 

if systemctl is-active --quiet php${PHP_VERS}-fpm.service; then
  echo "✅ Servico do PHP-FPM OK"
else
  echo "❌ Servico do PHP-FPM Offline"
  exit 1
fi
