#!/usr/bin/env sh

set -e

# Trap errors do redirect on Github issue pages
trap 'echo && echo "😢 Oh no ! An error was encountered. You can file an issue at https://github.com/PierreBeucher/Cloudy-Sunshine/issues." && exit 1' ERR

YELLOW=$'\e[33m'
NORMAL=$'\e[0m'

# Wrapper to run tasks
function run_task {
  task $1 -s # -n # Uncomment -n to dry-run
}

echo "👋 Hello there ! How shall we name your shiny Sunshine instance?"
read -p "   Instance name? (default: sunshine) " SUNSHINE_ENVIRONMENT_INPUT
export SUNSHINE_ENVIRONMENT=${SUNSHINE_ENVIRONMENT_INPUT:-sunshine}

if [ ! -f ./infra/Pulumi.${SUNSHINE_ENVIRONMENT}.yaml ]; then
  cp ./infra/Pulumi.template.yaml "./infra/Pulumi.${SUNSHINE_ENVIRONMENT}.yaml"
else
    echo "🤔 Instance config ${SUNSHINE_ENVIRONMENT} already exists. Do you want to continue? It will override existing config. "
    
    # While response is empty or not y or Y, keep asking
    while [[ ! $REPLY =~ ^[Yy]$ ]]; do
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "   Exiting."
        exit 1
      fi

      read -p "   Continue? (y/N): " -n 1 -r
    done

fi

echo
echo "🔎 Checking local AWS config..."
echo
aws sts get-caller-identity
echo

if [ $? -eq 0 ]; then
  echo "✅ AWS config is valid."
else
  echo "❌ ERROR: AWS config is invalid. Exiting."
  exit 1
fi

echo 
echo "🔐 SSH public key file used to allow access on your instance?"
echo "   Available public keys in your ~/.ssh folder:"
echo

find ~/.ssh -maxdepth 1 -type f -name "*.pub" -exec echo '   - {}' \;

echo
echo "   Alternatively you can generate one with 'ssh-keygen -t ed25519 -a 100'"
echo

read -p "   SSH public key file: " SUNSHINE_SSH_PUBLIC_KEY_PATH

while [ -z "$SUNSHINE_SSH_PUBLIC_KEY_PATH" ]; do
  echo "   SSH public key file cannot be empty."
  read -p "   SSH public key file: " SUNSHINE_SSH_PUBLIC_KEY_PATH
done

while [ ! -f $SUNSHINE_SSH_PUBLIC_KEY_PATH ]; do
  echo "   File $SUNSHINE_SSH_PUBLIC_KEY_PATH does not exist."
  read -p "   SSH public key file: " SUNSHINE_SSH_PUBLIC_KEY_PATH
done

export SUNSHINE_SSH_PUBLIC_KEY_PATH

echo
echo "🖥️  Which instance type do you want to use? (default: g4dn.xlarge)"
echo "   See https://aws.amazon.com/ec2/instance-types/ for more info"
read -p "   Instance type: " SUNSHINE_INSTANCE_TYPE_INPUT
export SUNSHINE_INSTANCE_TYPE=${SUNSHINE_INSTANCE_TYPE_INPUT:-g4dn.xlarge}

echo
echo "🗺️  Wwhich AWS region do you want to use? (default: $(aws configure get region))"
read -p "   AWS region: " SUNSHINE_AWS_REGION_INPUT
export SUNSHINE_AWS_REGION=${SUNSHINE_AWS_REGION_INPUT:-$(aws configure get region)}

echo
echo "💾  What disk size do you want to have? (default: 100 GB)"
read -p "    Disk size (GB): " SUNSHINE_DISK_SIZE_INPUT
export SUNSHINE_DISK_SIZE=${SUNSHINE_DISK_SIZE_INPUT:-100}

echo
echo "📝 Your config:"
echo "   > Sunshine instance name: ${SUNSHINE_ENVIRONMENT}"
echo "   > Public SSH key: ${SUNSHINE_SSH_PUBLIC_KEY_PATH}"
echo "   > Instance type: ${SUNSHINE_INSTANCE_TYPE}"
echo "   > AWS region: ${SUNSHINE_AWS_REGION}"
echo "   > Disk size: ${SUNSHINE_DISK_SIZE}"
echo

echo "💸 ${YELLOW}Do you understand you'll be billed by AWS after running this setup?${NORMAL}"
echo "   See README for tips and tricks to avoid unnecessary costs."
while [[ ! $COST_REPLY == "yes" ]]; do
  read -p "   Type 'yes' to continue, or CTRL+C to cancel: " COST_REPLY
  echo
done

echo "🚀 Creating Sunshine infrastructure..."
cat infra/Pulumi.template.yaml | envsubst > infra/Pulumi.${SUNSHINE_ENVIRONMENT}.yaml
pulumi -C infra stack select -c -s ${SUNSHINE_ENVIRONMENT}
run_task infra

echo
echo "⏳ Waiting for Sunshine server to be reachable via SSH..."
run_task wait-ssh

echo
echo "🌨️  Configuring NixOS... This may take a while as Nix must install quite a few things."
echo "   See logs file $PWD/nix-config.log for more info."
echo "   You can run this command in another terminal to see what's going on:"
echo "   $ tail -f $PWD/nix-config.log"
run_task nix-config -s > $PWD/nix-config.log 2>&1

echo
echo "🔁 NixOS config done ! Rebooting instance..."
run_task reboot

echo
echo "⏳ Waiting for Sunshine server to be reachable via SSH... (again after reboot, no worry)"
run_task wait-ssh

echo
echo "🤩 Your Sunshine instance is ready !"
read -p "   Open Sunshine in browser? (Y/n) " -n 1 BROWSER_REPLY

if [[ ! $BROWSER_REPLY =~ ^[Nn]$ ]]; then
  echo
  run_task sunshine-browser
fi

echo
echo "   You can now follow standard Sunshine setup procedure and run Moonlight."
echo
echo "💸 ${YELLOW}Remember to stop your instance once done to avoid unnecessary costs.${NORMAL}"    
echo "   See README for tips and tricks to avoid unnecessary costs."
echo
echo "   If you encounter problems or have questions, do not hesitate to file an issue at https://github.com/PierreBeucher/Cloudy-Sunshine/issues"
echo
echo "   Have fun!"
