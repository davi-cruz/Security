#!/bin/bash
# Sample Code Disclaimer
# This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
# Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained within the Premier Customer Services Description.

# Variáveis do script
msftRepoChannel='prod'

# Detecta distribuição e versão
case $(lsb_release -si) in
    "Ubuntu")
        distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        distroVersion=$(lsb_release -sr)
        pkgMgr="apt"
        ;;
    *)
        echo " - Distribution ainda não suportada neste script"
        exit
        ;;
esac

# Configura repositorio
case $pkgMgr in
    "apt")
        # Ubuntu e Debian

        # Adiciona o repositorio na lista do apt
        if [ ! -f /etc/apt/sources.list.d/microsoft-$msftRepoChannel.list ]; then
            echo " - Configurando o repositório microsoft-$msftRepoChannel.list no caminho /etc/apt/sources.list.d/ "
            curl -o "/tmp/microsoft-$msftRepoChannel.list" "https://packages.microsoft.com/config/$distro/$distroVersion/$msftRepoChannel.list"
            sudo mv /tmp/microsoft-$msftRepoChannel.list /etc/apt/sources.list.d/
        else
            echo " - microsoft-$msftRepoChannel.list já presente no sistema"
        fi

        # Configura chave da Microsoft
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

        # Atualiza cache do repositorio
        echo " - Atualizando o cache APT"
        sudo apt-get update -y
        ;;
esac

# Instala OMI
case $distro in
    "ubuntu")
        # Instala OMI Client se não presente
        if [ $(dpkg-query -W --showformat='${Status}\n' mdatp 2>/dev/null | grep "install ok installed" | wc -l) -gt "0" ]; then
            # Pacote já instalado
            echo " - OMI já instalado"
        else
            # Instala pacote em questão
            echo " - Instalando OMI"
            sudo apt-get install omi -y
        fi
        ;;
esac