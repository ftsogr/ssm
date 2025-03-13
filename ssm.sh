#!/bin/bash

# Dependencies: bash, awscli v2, jq

environment=""
instance=""
rds=""
region=""
list_flag=false
force_flag=false
ssh_flag=false
tunnel_flag=false
version="1.1.0"
config_dir=~/.ssm

# ANSI escape codes for formatting
bold=$(tput bold)
normal=$(tput sgr0)
underline=$(tput smul)
italic=$(tput sitm)
reset_italic=$(tput ritm)

main() {
    echo "${bold}Usage:${normal} $(basename "$0") [OPTIONS]"
    echo "${bold}Mandatory arguments for operations:${normal}"
    echo " ${bold}-e, --env${normal} <environment> | Values: $(aws configure list-profiles | tr '\n' ' ')"
    echo " ${bold}-r, --reg${normal} <region> | Target region"
    echo " ${bold}-i, --inst${normal} <instance>   | Required for SSH (-s) and Tunnel (-t) operations"
    echo "${bold}Options:${normal}"
    echo " ${bold}-h, --help${normal}           Display this help message"
    echo " ${bold}-v, --version${normal}        Display version information"
    echo " ${bold}-l, --list${normal}           List instances (does not require -i)"
    echo " ${bold}-s, --ssh${normal}            Open shell on server"
    echo " ${bold}-t, --tunnel${normal} <rds>   Create a tunnel to the specified RDS endpoint"
    echo ""
    echo "${bold}Example commands...${normal}"
    echo "${italic}List the instances and RDS:${normal} $(basename "$0") -e dev -l"
    echo "${italic}SSH connect to instance:${normal} $(basename "$0") -e dev -i i-086d5g0f21d4c569h -s"
    echo "${italic}MySQL RDS SSH tunnel:${normal} $(basename "$0") -e dev -i i-086d5g0f21d4c569h -t mysqldev1.cluster-ro-vu8cq4o6s3t9.ap-southeast-1.rds.amazonaws.com"
}

error_exit() {
    echo -e "$1" >&2
    main
    exit 1
}

list() {
    list_file="$config_dir/list.$environment.txt"
    rds_file="$config_dir/rds.$environment.txt"

    if [[ -z "$environment" ]]; then
        error_exit "${bold}Error:${normal} Environment must be specified with ${italic}-e${normal} for listing instances."
    fi

    if [[ -z "$region" ]]; then
        error_exit "${bold}Error:${normal} AWS region must be specified with ${italic}-r${normal}.\n"
    fi

    if [ "$force_flag" = true ]; then
        rm -f "$list_file" "$rds_file"
    fi

    if [ -e "$list_file" ] && [ -e "$rds_file" ]; then
        echo "${italic}Found cached instances, skipping login... (run with --force or -f to force refresh)${normal}"
        echo ""
        echo "${underline}Instances list:${normal}"
        cat "$list_file"
        echo ""
        echo "${underline}RDS list:${normal}"
        cat "$rds_file"
    else
        echo "${italic}Login...${normal}"
        aws sts get-caller-identity --query "Account" --profile "$environment" --no-cli-pager || aws sso login --profile "$environment" && rm -f ~/.aws/cli/cache/*.json
        
        echo ""
        echo "${underline}Instances list:${normal}"
        aws ec2 describe-instances --region "$region" \
            --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value,InstanceId]' \
            --output json --profile "$environment" | jq -r '.[] | "\(.[0][0] // "NoName") \(.[1])"' > "$list_file"
        cat "$list_file"

        echo ""
        echo "${underline}RDS list:${normal}"
        aws rds describe-db-clusters --region "$region" \
            --query 'DBClusters[*].[DBClusterIdentifier,Endpoint,ReaderEndpoint]' \
            --output json --profile "$environment" | jq -r '.[] | "\(.[0])\nWrite: \(.[1])\nRead: \(.[2])\n"' > "$rds_file"
        cat "$rds_file"
    fi
}

ssh() {
    echo "${italic}SSH function executed${normal}"
    echo "${italic}Login...${normal}"
    aws sts get-caller-identity --query "Account" --profile "$environment" --no-cli-pager || aws sso login --profile "$environment" && rm -f ~/.aws/cli/cache/*.json
    echo ""
    aws ssm start-session --region $region --target $instance --profile "$environment"
}

tunnel() {
    if [[ -z "$rds" ]]; then
        error_exit "${bold}Error:${normal} RDS endpoint must be specified for tunnel operation.\n"
    fi

    echo "${italic}Tunnel function executed${normal}"
    echo "${italic}Login...${normal}"
    aws sts get-caller-identity --query "Account" --profile "$environment" --no-cli-pager || aws sso login --profile "$environment" && rm -f ~/.aws/cli/cache/*.json
    echo ""
    echo "${italic}You can connect to the target MySQL using localhost as host and port 13306${normal}"
    aws ssm start-session --region $region --target $instance --profile "$environment" --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters "{\"portNumber\":[\"3306\"],\"localPortNumber\":[\"13306\"],\"host\":[\"$rds\"]}"
}

mkdir -p $config_dir
# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -e|--env)
            environment="$2"
            shift
            shift
            ;;
        -r|--reg)
            region="$2"
            shift
            shift
            ;;
        -i|--inst)
            instance="$2"
            shift
            shift
            ;;
        -h|--help)
            main
            exit 0
            ;;
        -v|--version)
            echo "${bold}Version${normal} $version"
            exit 0
            ;;
        -l|--list)
            list_flag=true
            shift
            ;;
        -f|--force)
            force_flag=true
            shift
            ;;
        -s|--ssh)
            ssh_flag=true
            shift
            ;;
        -t|--tunnel)
            rds="$2"
            tunnel_flag=true
            shift
            shift
            ;;
        *)
            echo "Unknown option: $1"
            main
            exit 1
            ;;
    esac
done

# Check if -l (list) is used
if [[ "$list_flag" = true ]]; then
    if [[ -z "$environment" ]]; then
        error_exit "${bold}Error:${normal} The list option requires ${italic}-e <environment>${normal}.\n"
    fi
    list
    exit
fi

# Check if -r (region) is used
if [[ -z "$region" ]]; then
    error_exit "${bold}Error:${normal} AWS region must be specified with ${italic}-r${normal}.\n"
fi

# Check if -t and -s are both set
if [[ "$ssh_flag" = true && "$tunnel_flag" = true ]]; then
    error_exit "${bold}Error:${normal} The options ${italic}-s${normal} (ssh) and ${italic}-t${normal} (tunnel) cannot be used together.\n"
fi

# Check if mandatory arguments are set for SSH and Tunnel operations
if [[ ("$ssh_flag" = true || "$tunnel_flag" = true) && (-z "$environment" || -z "$instance") ]]; then
    error_exit "${bold}Error:${normal} Arguments ${italic}-e${normal} and ${italic}-i${normal} are mandatory for SSH and Tunnel operations.\n"
fi

# Execute actions based on flags
if [[ "$ssh_flag" = true ]]; then
    ssh
elif [[ "$tunnel_flag" = true ]]; then
    tunnel
else
    echo -e "${bold}No operation specified.${normal} Use ${italic}-h${normal} for help! Quick tip: ${italic}-s${normal} for SSH, ${italic}-t${normal} for Tunnel, or ${italic}-l${normal} for List.\n"
fi
