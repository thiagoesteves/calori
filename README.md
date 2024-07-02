# Calori

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Have a look in the next sections

# Deployment management

Deployments for Calori web-server are handled by [Deployex](https://github.com/thiagoesteves/deployex) and you can check its [current deployment](https://deployex.calori.com.br).

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

When running Terraform for the first time, AWS secrets are not yet created. Consequently, attempts to execute deployex or certificates installation will fail. Once these AWS secrets, including certificates and other sensitive information, are updated, subsequent iterations of Terraform's EC2 destroy/create process will no longer require manual intervention.

For initial installations or updates to deployex, follow these steps:

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
root@ip-10-0-1-116:/home/ubuntu# ./deployex.sh --install -a calori -r 3 -h calori.com.br -c prod -d deployex.calori.com.br -u sa-east-1 -v 0.3.0-rc9 -s ubuntu-20.04
#           Removing Deployex              #
Removed /etc/systemd/system/multi-user.target.wants/deployex.service.
rm: cannot remove '/etc/systemd/system/deployex.service': No such file or directory
rm: cannot remove '/usr/lib/systemd/system/deployex.service': No such file or directory
rm: cannot remove '/usr/lib/systemd/system/deployex.service': No such file or directory
#     Deployex removed with success        #
#          Installing Deployex             #
useradd: user 'deployex' already exists
mkdir: cannot create directory ‘/var/log/calori/’: File exists
#    Deployex installed with success       #

#           Updating Deployex              #
# Download the deployex version: 0.3.0-rc8 #
--2024-06-27 18:04:18--  https://github.com/thiagoesteves/deployex/releases/download/0.3.0-rc8/deployex-ubuntu-20.04.tar.gz
Resolving github.com (github.com)... 20.201.28.151
Connecting to github.com (github.com)|20.201.28.151|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: ...
Connecting to objects.githubusercontent.com (objects.githubusercontent.com)|185.199.109.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 30752682 (29M) [application/octet-stream]
Saving to: ‘deployex-ubuntu-20.04.tar.gz’

deployex-ubuntu-20.04.tar.gz            100%[=============================================================================>]  29.33M   139MB/s    in 0.2s

2024-06-27 18:04:19 (139 MB/s) - ‘deployex-ubuntu-20.04.tar.gz’ saved [30752682/30752682]

# Stop current service                     #
Failed to stop deployex.service: Unit deployex.service not loaded.
# Clean and create a new directory         #
# Start systemd                            #
# Start new service                        #
Created symlink /etc/systemd/system/multi-user.target.wants/deployex.service → /etc/systemd/system/deployex.service.
root@ip-10-0-1-116:/home/ubuntu#
```

If the deployex needs to be updated, a new version can be passed as argument, e. g. :
```bash
root@ip-10-0-1-116:/home/ubuntu# ./deployex.sh --update -v 0.3.0-rc9 -s ubuntu-20.04
```

If deployex is running and still there is no version of the monitored app available, you should see this message in the logs:
```bash
root@ip-10-0-1-56:/home/ubuntu# tail -f /var/log/deployex/deployex-stdout.log
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

### 7. Setting Up HTTPS Certificates with Let's Encrypt

*__Before proceeding, ensure that the DNS is correctly pointing to the EC2 instance__*

For HTTPS, the project can set Free certificates from [Let's encrypt](https://letsencrypt.org/getting-started/). In this deployment, we are going to use the [cert bot for ubuntu](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal):

```bash
sudo su
apt update
apt install snapd
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
certbot --nginx
```

This will install Certbot and automatically configure Nginx to use the obtained certificates. After Nginx finishes setup, it will create paths for the certificates. They will typically look like this:

```bash
vi /etc/nginx/sites-available/default
...
          ssl_certificate /etc/letsencrypt/live/calori.com.br/fullchain.pem; # managed by Certbot
          ssl_certificate_key /etc/letsencrypt/live/calori.com.br/privkey.pem; # managed by Certbot
          include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
          ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
```

It's possible that Nginx has modified the configuration file `/etc/nginx/sites-available/default` in a way that it won't work as expected. You'll need to retrieve the original file [nginx file](devops/terraform/modules/standard-account/cloud-config.tpl) and update it with the Let's Encrypt certificate paths. Find the section where it mentions:

and where it mentions:

```bash
          # Add here the letsencrypt paths
```
Replace this comment with the certificate paths obtained in the previous step.

```bash
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";

              proxy_pass http://deployex;
          }
          ssl_certificate /etc/letsencrypt/live/calori.com.br/fullchain.pem; # managed by Certbot
          ssl_certificate_key /etc/letsencrypt/live/calori.com.br/privkey.pem; # managed by Certbot
          include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
          ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
      }
```

Also, for both servers, re-enable port 443, e. g:

```bash
      server {
          listen 443 ssl; # managed by Certbot
```

After modifying the configuration file, save the changes and restart Nginx:

```bash
sudo su
vi /etc/nginx/sites-available/default
# modify and save file
systemctl reload nginx
```

__PS: After the changes, It may require a reboot__

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

To connect to the iex shell, you may need to export the cookie if AWS is configured with a value different from the default 'cookie', which is highly recommended to change.

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_NODE_SUFFIX=
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_COOKIE=COOKIE12345678912345789
root@ip-10-0-1-56:/home/ubuntu$ /opt/deployex/bin/deployex remote
Erlang/OTP 26 [erts-14.1.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(deployex@ip-10-0-1-240)1> 
```

##### 2. IEX shell Access to Calori App

To connect to the iex shell, you may need to export the cookie if AWS is configured with a value different from the default 'cookie', which is highly recommended to change.

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_NODE_SUFFIX=-1
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_COOKIE=COOKIE12345678912345789
root@ip-10-0-1-56:/home/ubuntu$ /var/lib/deployex/service/calori/1/current/bin/calori remote
Erlang/OTP 26 [erts-14.1.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(calori-1@ip-10-0-1-240)1>
```

##### 3. Logs

The logs for deployex can be found at `/var/log/deployex/deployex-stdout.log`.

```bash
root@ip-10-0-1-56:/home/ubuntu$ tail -f /var/log/deployex/deployex-stdout.log
19:59:20.035 [info] module=Deployex.AwsSecretsManagerProvider function=load/2 pid=<0.9.0>    - Retrieve secrets
19:59:20.487 [info] module=Deployex.Deployment function=init/1 pid=<0.1739.0>  Initialising deployment server
19:59:20.493 [info] module=Bandit function=start_link/1 pid=<0.1755.0>  Running DeployexWeb.Endpoint with Bandit 1.5.3 at :::5001 (http)
19:59:20.505 [info] module=Phoenix.Endpoint.Supervisor function=log_access_url/2 pid=<0.1735.0>  Access DeployexWeb.Endpoint at https://deployex.calori.com.br
19:59:20.506 [info] module=Deployex.Monitor function=init/1 pid=<0.2065.0>  Initialising monitor server for instance: 1
19:59:20.508 [info] instance=1 module=Deployex.Monitor function=run_service/2 pid=<0.2065.0>  Ensure running requested for instance: 1 version: 0.1.0-627e062
19:59:20.509 [info] instance=1 module=Deployex.Monitor function=run_service/2 pid=<0.2065.0>   # Starting /var/lib/deployex/service/calori/1/current/bin/calori...
19:59:20.509 [info] instance=1 module=Deployex.Monitor function=run_service/2 pid=<0.2065.0>   # Running instance: 1, monitoring pid = #PID<0.2066.0>, OS process id = 828.
19:59:20.510 [info] module=Deployex.Monitor function=init/1 pid=<0.2067.0>  Initialising monitor server for instance: 2
```

The logs for calori can be found at `/var/log/calori/calori-{instance}-stdout.log` or `/var/log/calori/calori-{instance}-stderr.log`.

```bash
root@ip-10-0-1-56:/home/ubuntu$ tail -f /var/log/calori/calori-1-stdout.log
13:53:25.623 module=Calori.AwsSecretsManagerProvider function=load/2 pid=<0.9.0> [info]   - Retrieve secrets
13:53:25.929 module=Bandit function=start_link/1 pid=<0.1722.0> [info] Running CaloriWeb.Endpoint with Bandit 1.5.0 at :::4000 (http)
13:53:25.934 module=Phoenix.Endpoint.Supervisor function=log_access_url/2 pid=<0.1703.0> [info] Access CaloriWeb.Endpoint at https://calori.com.br
```

##### 4. Updating CALORI_PHX_HOST

In case you need to update the *__CALORI_PHX_HOST__*, you just need to reinstall deployex passing the new host.

```bash
ubuntu@ip-10-0-1-56:~$ sudo su
root@ip-10-0-1-56:/home/ubuntu# ./deployex.sh --install -a calori -r 3 -h new_host.com -c prod -d deployex.new_host.com -u sa-east-1 -v 0.3.0-rc9 -s ubuntu-20.04
```

You will have to re-create the certificates with certbot (if you are using Let's encrypt):
```bash
certbot --nginx
```

It is high likely this command will modify nginx config file to a invalid format. In this case, you can just follow the 7.

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
rm -rf /var/lib/deployex/version/
rm -rf /var/lib/deployex/service/calori/
systemctl start deployex.service
```

##### 7. Checking sys.config before and after a hotupgrade

In order to check the Calori sys.config data, you can access the remote iex from deployex:

*__ATTENTION: In order to have the OTP distribution available make sure the cookie and the certificates are correctly set for both apps__*

```bash
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_NODE_SUFFIX=-1
root@ip-10-0-1-56:/home/ubuntu$ export RELEASE_COOKIE=COOKIE12345678912345789
root@ip-10-0-1-56:/home/ubuntu$ /var/lib/deployex/service/calori/1/current/bin/calori remote
Erlang/OTP 26 [erts-14.1.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit:ns]

Interactive Elixir (1.16.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(calori-1@ip-10-0-1-240)1>
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
