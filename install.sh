#!/bin/bash

if ! command -v php &>/dev/null; then
  echo "PHP não está instalado. Baixando e instalando..."
  pkg install -y php
  if [ $? -ne 0 ]; then
    echo "Erro ao instalar o PHP. Certifique-se de que o Termux está configurado corretamente."
    exit 1
  fi
fi

PHP_INI="/data/data/com.termux/files/usr/etc/php.ini"
if [ ! -f "$PHP_INI" ]; then
  echo "Arquivo php.ini não encontrado. Criando..."
  mkdir -p "$(dirname "$PHP_INI")"
  cat <<EOF >"$PHP_INI"
phar.readonly = Off
EOF
  echo "Arquivo php.ini criado com sucesso em $PHP_INI."
fi

if [ $# -lt 1 ]; then
  echo "Uso: $0 <arquivo.zip ou diretório>"
  exit 1
fi

INPUT_PATH="$1"

compile_zip_to_phar() {
  local ZIP_FILE="$1"

  if [ ! -f "$ZIP_FILE" ]; then
    echo "Arquivo $ZIP_FILE não encontrado."
    return 1
  fi

  local PHAR_FILE="${ZIP_FILE%.zip}.phar"

  local TEMP_DIR
  TEMP_DIR=$(mktemp -d)
  unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

  if [ $? -ne 0 ]; then
    echo "Erro ao extrair o arquivo ZIP."
    rm -rf "$TEMP_DIR"
    return 1
  fi

  local SUBFOLDER
  SUBFOLDER=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
  if [ "$SUBFOLDER" -eq 1 ]; then
    mv "$TEMP_DIR"/*/* "$TEMP_DIR/"
  fi

  echo "Criando $PHAR_FILE..."
  php -c "$PHP_INI" -r "
  \$phar = new Phar('$PHAR_FILE');
  \$phar->startBuffering();
  \$phar->buildFromDirectory('$TEMP_DIR');
  \$phar->setStub('<?php __HALT_COMPILER();');
  \$phar->stopBuffering();
  "

  if [ $? -eq 0 ]; then
    echo "Arquivo $PHAR_FILE criado com sucesso!"
  else
    echo "Erro ao criar o arquivo .phar."
  fi

  rm -rf "$TEMP_DIR"
}

if [[ -f "$INPUT_PATH" && "$INPUT_PATH" == *.zip ]]; then
  compile_zip_to_phar "$INPUT_PATH"

elif [ -d "$INPUT_PATH" ]; then
  echo "Procurando arquivos ZIP em $INPUT_PATH..."
  find "$INPUT_PATH" -type f -name '*.zip' | while read -r ZIP_FILE; do
    compile_zip_to_phar "$ZIP_FILE"
  done
else
  echo "Caminho inválido. Forneça um arquivo .zip ou um diretório."
  exit 1
fi
