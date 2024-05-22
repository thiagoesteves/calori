# Calori

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Have a look in the next section

# AWS Deployment (with terraform)

The environment provisioning involves Terraform templates located at `devops/terraform/environments/prod` and a few manual steps.

## Setup

To begin, ensure the following steps are in place:

### 1. SSH Key Pair

Create an SSH key pair named, e. g. `calori-web-ec2` by visiting the [AWS Key Pair page](https://sa-east-1.console.aws.amazon.com/ec2/home?region=sa-east-1#KeyPairs:). Save the private key in your local SSH folder (`~/.ssh`). The name `calori-web-ec2` will be used by this file `devops/terraform/modules/standard-account/variables.tf` within terraform templates.

### 2. Environment Secrets

Ensure you have access to the following secrets for storage in AWS Secrets Manager:

 - CALORI_SECRET_KEY_BASE
 - CALORI_ERLANG_COOKIE

### 3. CALORI_PHX_HOST Configuration

In the file `devops/terraform/environments/prod/main.tf`, verify and set the *__server_dns__* variable according to the specific environment, such as `calori.com.br`. This variable will be used in all terraform templates to set-up correctly the hostname.

### 4. Provisioning the Environment

Check you have the correct credentials to create/update resources in aws:
```bash
cat ~/.aws/credentials 
[default]
aws_access_key_id=access_key_id
aws_secret_access_key=secret_access_key
```

Once the key is configured, proceed with provisioning the environment. Navigate to the `devops/terraform/environments/prod` folder and execute the following commands:

```bash
terraform plan # Check if the templates are configured correctly
terraform apply # Apply the configurations to create the environment
```

Wait for the environment to be created. Afterward, update the variables in the *__calori-prod-secrets__* secret in the [AWS Secrets Manager](https://sa-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=sa-east-1) with the corresponding values.

```bash
# Update the secrets
CALORI_SECRET_KEY_BASE=xxxxxxxxxx
CALORI_ERLANG_COOKIE=xxxxxxxxxx
```

Additionally, create the TLS certificates for the OTP distribution using the [Deployex app](https://github.com/thiagoesteves/deployex?tab=readme-ov-file#enhancing-otp-distribution-security-with-mtls)

```bash
cd deployex
make tls-distribution-certs
```

*__PS__*: you will also need to add them as plain text as explained [here](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-ranger-tls-certificates.html)

Add the following certificates:
 - *__calori-stage-otp-tls-ca__*
 - *__calori-stage-otp-tls-key__*
 - *__calori-stage-otp-tls-crt__*

### 5. EC2 Provisioning (Manual Steps)

The deployex is not installed by default, the user needs to access the EC2 and install it via script. (This step can also be used to update the deployex)

*__PS__*: make sure you have the pair calori-web-ec2.pem saved in `~/.ssh/`

```bash
ssh -i "calori-web-ec2.pem" ubuntu@ec2-52-67-178-12.sa-east-1.compute.amazonaws.com
ubuntu@ip-10-0-1-56:~$
```

After getting access to EC2, you need to grant root permissions:

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu$
```

Run the script to install the certificates:
```bash
./install-otp-certificates.sh 

# Installing Certificates env: stage at /usr/local/share/ca-certificates #
Retrieving and saving ......
[OK]
```

you can check if the certificates were installed correctly:

```bash
ls /usr/local/share/ca-certificates
ca.crt  calori.crt calori.key deployex.crt  deployex.key
```

Run the script to install (or update) deployex:

```bash
root@ip-10-0-1-56:/home/ubuntu$ ./install-upgrade.sh 

#           Updating Deployex              #
# Download the latest deployex version     #
--2024-05-14 00:54:42--  https://github.com/thiagoesteves/deployex/releases/download/0.1.0/deployex-ubuntu-20.04.tar.gz
Resolving github.com (github.com)... 20.201.28.151
Connecting to github.com (github.com)|20.201.28.151|:443... connected.
HTTP request sent, awaiting response... 302 Found
...
Connecting to objects.githubusercontent.com (objects.githubusercontent.com)|185.199.109.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 27564543 (26M) [application/octet-stream]
Saving to: ‘deployex-ubuntu-20.04.tar.gz’

deployex-ubuntu-20.04.tar.gz            100%[=============================================================================>]  26.29M  14.1MB/s    in 1.9s

2024-05-14 00:54:44 (14.1 MB/s) - ‘deployex-ubuntu-20.04.tar.gz’ saved [27564543/27564543]

# Clean and create a new directory         #
# Start systemd                            #
Created symlink /etc/systemd/system/multi-user.target.wants/deployex.service → /etc/systemd/system/deployex.service.
```

If the deployex needs to be updated, a new version can be passed as argument, e. g. :
```bash
root@ip-10-0-1-56:/home/ubuntu$ ./install-upgrade.sh 1.0.0
```

If deployex is running and still there is no version of the monitored app available, you should see this message in the logs:
```bash
root@ip-10-0-1-56:/home/ubuntu# tail -f /var/log/deployex.log
00:54:47.786 [info] module=Deployex.Monitor function=start_service/2 pid=<0.1028.0>  No version set, not able to start_service
```

### 6. Calori (Monitored App) deployment

Once deployex is running, the monitored app __MUST__ then be deployed, creating the release package and the json file in the S3. For this project, check the github actions that are deploying the respective app.

In the [github actions](.github/workflows/release.yaml) files, you can check that the job is updating the `mix.exs` version prior compiling the package to append the short-sha in the version. The final `current.json` file should be similar to:
```bash
{
  "version": "0.1.0-9cad9cd",
  "hash": "9cad9cd3581c69fdd02ff60765e1c7dd4599d84a"
}
```

Tracking the `mix.exs` version is essential to allow hot-upgrades.

### 7. HTTPS certificates

*__ATTENTION: For this step to work, be sure that the DNS is pointing to the EC2 instance.__*

For HTTPS, the project can set Free certificates from [Let's encrypt](https://letsencrypt.org/getting-started/). In this deployment, we are going to use the [cert bot for ubuntu](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal):

```bash
sudo apt update
sudo apt install snapd
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx
```

Nginx will automatically generate certificates and modify your configuration files during installation. After installation, verify if the contents of the nginx configuration file match those specified in the original [nginx file ](devops/terraform/modules/standard-account/cloud-config.tpl). If any discrepancies are found, edit the file accordingly and restart Nginx to apply the changes.

```bash
sudo su
vi /etc/nginx/sites-available/default
# modify and save file
systemctl reload nginx
```

The comands above will modify nginx file for the correct routing. Once it is all set, you need to check if the [runtime.exs](apps/calori/config/runtime.exs) is pointing to the correct SCHEME/HOST/PORT, e. g.:

```elixir
    url: [host: "example.com", port: 443, scheme: "https"],
```

### 8. Hot Upgrade

TBD

#### Considerations when NOT use hotupgrades

Avoid the execute a hotupgrade in the following situations:
 - When running migrations
 - When a new initialization is required
 - When files/modules were deleted/added
 - When a new configuration flags in vm.args are required
 - When there is a change in the config providers files, since they are not supported during a hotupgrade yet

## Throubleshooting

#### 1. IEX shell Access to Deployex App

Connecting the iex shell:

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu$ /opt/deployex/bin/deployex remote
Erlang/OTP 26 [erts-14.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(deployex@ip-10-0-1-56)1>
```

##### 2. IEX shell Access to Calori App

Connecting the iex shell:

```bash
root@ip-10-0-1-56:/home/ubuntu$ sudo -su deployex
deployex@ip-10-0-1-56:$ /var/lib/deployex/service/calori/current/bin/calori remote
Erlang/OTP 26 [erts-14.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(calori@ip-10-0-1-56)1>
```

##### 3. Logs

The logs for deployex can be found at `/var/log/deployex.log`.

```bash
root@ip-10-0-1-56:/home/ubuntu$ tail -f /var/log/deployex.log 
13:44:25.292 [notice] pid=<0.900.0>  SIGTERM received - shutting down

13:46:20.553 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>  Ensure requested for version: 0.1.0
13:46:20.554 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>   - Starting /var/lib/deployex/service/calori/current/bin/calori...
13:46:20.555 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>   - Running, monitoring pid = #PID<0.1018.0>, OS process id = 1418.
13:46:57.675 [notice] pid=<0.900.0>  SIGTERM received - shutting down

13:48:11.686 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>  Ensure requested for version: 0.1.0
13:48:11.686 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>   - Starting /var/lib/deployex/service/calori/current/bin/calori...
13:48:11.687 [info] module=Deployex.Monitor function=ensure_running/2 pid=<0.1017.0>   - Running, monitoring pid = #PID<0.1018.0>, OS process id = 1569.
```

The logs for calori can be found at `/var/log/calori-stdout.log` or `/var/log/calori-stderr.log`.

```bash
root@ip-10-0-1-56:/home/ubuntu$ tail -f /var/log/calori-stdout.log 
14:09:36.156 [info] CONNECTED TO Phoenix.LiveView.Socket in 25µs
  Transport: :websocket
  Serializer: Phoenix.Socket.V2.JSONSerializer
  Parameters: %{"_csrf_token" => "V18FIDZHICgFM2BmEAk7MS0CLh0qPFQrflVBL-kp1R59hGURu2FuaqfJ", "_live_referer" => "undefined", "_mounts" => "0", "_track_static" => %{"0" => "http://ec2-18-223-210-216.us-east-2.compute.amazonaws.com/assets/app-f519839f3e224b77ecdaa1fd3818e91e.css?vsn=d", "1" => "http://ec2-18-223-210-216.us-east-2.compute.amazonaws.com/assets/app-54c572e977c8f20ea325db08d4d9f5f1.js?vsn=d"}, "timezone" => "America/Sao_Paulo", "vsn" => "2.0.0"}
14:09:36.495 [info] GET /app/user/calendar
14:09:36.511 [info] Sent 200 in 15ms
14:09:36.871 [info] CONNECTED TO Phoenix.LiveView.Socket in 25µs
  Transport: :websocket
  Serializer: Phoenix.Socket.V2.JSONSerializer
  Parameters: %{"_csrf_token" => "YgoZUCNZBCpAJxkAHiYFC21BHistBH03S9J2Y3OrtFL_fhkh5qvCfIOV", "_live_referer" => "undefined", "_mounts" => "0", "_track_static" => %{"0" => "http://ec2-18-223-210-216.us-east-2.compute.amazonaws.com/assets/app-f519839f3e224b77ecdaa1fd3818e91e.css?vsn=d", "1" => "http://ec2-18-223-210-216.us-east-2.compute.amazonaws.com/assets/app-54c572e977c8f20ea325db08d4d9f5f1.js?vsn=d"}, "timezone" => "America/Sao_Paulo", "vsn" => "2.0.0"}
```

##### 4. Updating CALORI_PHX_HOST

In case you need to update the *__CALORI_PHX_HOST__*, there are 2 files that need to be updated:  `/etc/systemd/system/deployex.service` and `/etc/nginx/sites-available/default` (you need to be `root`` user to update them).

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu$ vi /etc/systemd/system/deployex.service
...
Environment=CALORI_PHX_HOST={CHANGE-ME}
...

root@ip-10-0-1-56:/home/ubuntu$ vi /etc/nginx/sites-available/default
...
server {
    server_name  {CHANGE-ME};
...
server {
    if ($host = calori.com.br) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    server_name {CHANGE-ME};
```

you also need to reload the deployex service and restart it (nginx and deployex), execute the commands:

```bash
systemctl stop deployex.service
systemctl daemon-reload
systemctl enable --now deployex.service
```

You will have to re-create the certificates with certbot (if you are using Let's encrypt):
```bash
certbot --nginx
```

##### 5. Restart Calori app

For restarting the Calori app, you just need to stop/start the deployex

```bash
sudo su
systemctl stop deployex.service
systemctl start deployex.service
```

##### 6. Force deployex to reload the calori current version

In order to force Deployex to download and redeploy calori with the same version, you need to delete the current one:

```bash
sudo su
systemctl stop deployex.service
rm /var/lib/deployex/current.json
rm -rf /var/lib/deployex/service/calori/current/
systemctl start deployex.service
```

##### 7. Checking sys.config before and after a hotupgrade

In order to check the Calori sys.config data, you can access the remote iex from deployex:

*__ATTENTION: In order to have the OTP distribution available make sure the cookie and the certificates are correctly set for both apps__*

```bash
deployex@ip-10-0-1-56:/var/lib/deployex/service/calori$ /var/lib/deployex/service/calori/current/bin/calori remote
Erlang/OTP 26 [erts-14.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(calori@ip-10-0-1-56)1>
```
and then connect both to the distribution

```Elixir
{:ok, hostname} = :inet.gethostname()
node = :"calori@#{hostname}"
Node.connect(node)
```

After you can then run some rpc commands before and after the hot upgrade
```Elixir
iex(calori@ip-10-0-1-11)6> :rpc.call(node, Application, :get_all_env, [:calori], 3_000)
[
  ...
  {:dns_cluster_query, nil},
  ...
```
