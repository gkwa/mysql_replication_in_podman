#!/bin/bash

dotnet --list-sdks
dotnet --version

cat <<'__eot__' >global.json
{
  "sdk": {
    "version": "3.1.412"
  }
}
__eot__

dotnet --list-sdks
dotnet --version

curl -sflL 'https://raw.githubusercontent.com/appveyor/secure-file/master/install.sh' | bash -e -

wget https://download.visualstudio.microsoft.com/download/pr/90e2064f-8786-4e12-95cd-8185fc71f1cb/1a3279320411c489f37142ec656ef0b8/dotnet-sdk-3.1.412-linux-x64.tar.gz
mkdir -p $HOME/dotnet && tar zxf dotnet-sdk-3.1.412-linux-x64.tar.gz -C $HOME/dotnet
export DOTNET_ROOT=$HOME/dotnet
export PATH=$PATH:$HOME/dotnet

dotnet --list-sdks
dotnet --version
