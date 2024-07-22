#!/bin/bash

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

prompt() {
    local message="$1"
    read -p "$message" input
    echo "$input"
}

execute_and_prompt() {
    local message="$1"
    local command="$2"
    echo -e "${YELLOW}${message}${NC}"
    eval "$command"
    echo -e "${GREEN}Done.${NC}"
}

echo -e "${YELLOW}Installing Rust...${NC}"
echo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
echo -e "${GREEN}Rust installed: $(rustc --version)${NC}"
echo

echo -e "${YELLOW}Removing Node.js...${NC}"
echo
sudo apt-get remove -y nodejs
echo

echo -e "${YELLOW}Installing NVM and Node.js LTS...${NC}"
echo
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && export NVM_DIR="/usr/local/share/nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"; source ~/.bashrc; nvm install --lts; nvm use --lts
echo -e "${GREEN}Node.js installed: $(node -v)${NC}"
echo

echo -e "${YELLOW}Cloning repository and installing npm dependencies...${NC}"
echo
folder_name="testnet-deposit"
count=1
while [ -d "$folder_name-$count" ]; do
  count=$((count+1))
done
folder_name="$folder_name-$count"

git clone https://github.com/Eclipse-Laboratories-Inc/testnet-deposit "$folder_name"
cd "$folder_name"
npm install
echo

echo -e "${YELLOW}Installing Solana CLI...${NC}"
echo
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
echo -e "${GREEN}Solana CLI installed: $(solana --version)${NC}"
echo

echo -e "${YELLOW}Generating new Solana keypair...${NC}"
echo
wallet_file="my-wallet.json"

if [ -f ~/$wallet_file ]; then
  echo "Wallet file already exists."
  count=1
  while [ -f ~/${wallet_file%.*}$count.${wallet_file##*.} ]; do
    count=$((count+1))
  done
  solana-keygen new -o ~/${wallet_file%.*}$count.${wallet_file##*.}
  wallet_file="${wallet_file%.*}$count.${wallet_file##*.}"
  echo "Wallet file created: ~/${wallet_file}"
else
  solana-keygen new -o ~/$wallet_file
  echo "Wallet file created: ~/$wallet_file"
fi
echo
echo -e "${YELLOW}Save these mnemonic phrases in safe Place.If there will any Airdrop in future, you will be eligible from this wallet so save it${NC}"
echo

read -p "Enter your mneomic phrase: " mnemonic
echo

cat << EOF > secrets.json
{
  "seedPhrase": "$mnemonic"
}
EOF

cat << 'EOF' > derive-wallet.js
const { seedPhrase } = require('./secrets.json');
const { HDNodeWallet } = require('ethers');

const mnemonicWallet = HDNodeWallet.fromPhrase(seedPhrase);
console.log();
console.log('ETHEREUM PRIVATE KEY:', mnemonicWallet.privateKey);
console.log();
console.log('​​SEND SEPOLIA ETH TO THIS ADDRESS:', mnemonicWallet.address);
EOF

if ! npm list ethers &>/dev/null; then
  echo "ethers.js not found. Installing..."
  echo
  npm install ethers
  echo
fi

node derive-wallet.js
echo

echo -e "${YELLOW}Configuring Solana CLI...${NC}"
echo "wallet_file: $HOME/$wallet_file"

solana config set --keypair "$HOME/${wallet_file}"
solana config set --url https://testnet.dev2.eclipsenetwork.xyz/
echo
echo -e "${GREEN}Solana Address: $(solana address)${NC}"
echo

if [ -d "testnet-deposit" ]; then
    execute_and_prompt "Removing testnet-deposit Folder..." "rm -rf ${folder_name}"
fi

read -p "Enter your Solana address: " solana_address
read -p "Enter the amount in Gwei (at least 1500000): " amount
read -p "Enter your Ethereum Private Key: " ethereum_private_key
echo -e "${RED}Please make sure you have sent  sepolia eth the ethereum address before proceeding ${RESET}"
echo
read -p "Enter the number of times to repeat Transaction (4-5 tx Recommended): " repeat_count
echo

for ((i=1; i<=repeat_count; i++)); do
    echo -e "${YELLOW}Running Bridge Script (Tx $i)...${NC}"
    echo
    node deposit.js "$solana_address" 0x11b8db6bb77ad8cb9af09d0867bb6b92477dd68e "$amount" "$ethereum_private_key" https://1rpc.io/sepolia
    echo
    sleep 3
done

echo -e "${RED}It will take 4 mins, Don't do anything, Just Wait${RESET}"
echo

sleep 240

execute_and_prompt "Creating token..." "spl-token create-token --enable-metadata -p TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
echo

token_address=$(prompt "Enter your Token Address: ")
echo
execute_and_prompt "Creating token account..." "spl-token create-account $token_address"
echo

execute_and_prompt "Minting token..." "spl-token mint $token_address 10000"
echo
execute_and_prompt "Checking token accounts..." "spl-token accounts"
echo

execute_and_prompt "Checking Program Address..." "solana address"
echo
echo -e "${YELLOW}Submit Feedback at${NC}: https://docs.google.com/forms/d/e/1FAIpQLSfJQCFBKHpiy2HVw9lTjCj7k0BqNKnP6G1cd0YdKhaPLWD-AA/viewform?pli=1"
echo
