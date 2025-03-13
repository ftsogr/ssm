## AWS sso ssm cli connect helper bash script

### Dependencies: 
- GNU bash
- Jq
- AWS CLI version 2
- AWS Session Manager plugin
- AWS account for each env

### Installation example:
- Add the code below inside `~/.aws/config`:
   ```
   [profile <profile name>]
   sso_account_id = <account id>
   sso_role_name = <sso role>
   sso_region = <sso awsapps region>
   sso_start_url = <awsapps url>
   [profile proj-prod]
   sso_account_id = 678547393568
   sso_role_name = proj-developers
   sso_region = us-east-2
   sso_start_url = https://d-7b890r006j.awsapps.com/start#/
   [profile proj-dev]
   sso_account_id = 786127395769
   sso_role_name = proj-developers
   sso_region = us-east-2
   sso_start_url = https://d-7b890r006j.awsapps.com/start#/
   ```

- Clode repo
  
- Make the script executable
  ```
  chmod +x  /<path_to_git_repo>/ssm.sh
  ```
  
- Add a line like below at the end of `~/.bash_aliases`
   ```
   alias ssm.sh='/<path_to_git_repo>/ssm.sh'
   ```

### Example commands:
- List the Instances and RDS servers: 
   ```
   ssm.sh -e dev -r ap-southeast-1 -l
   ```
- SSH connect to Instance:
   ```
   ssm.sh -e dev -r ap-southeast-1 -i i-086d5g0f21d4c569h -s
   ```
- MySQL RDS SSH Tunnel:
   ```
   ssm.sh -e dev -r ap-southeast-1 -i i-086d5g0f21d4c569h -t mysqldev1.cluster-ro-vu8cq4o6s3t9.ap-southeast-1.rds.amazonaws.com
   ```

