#cloud-config
#
#  Cloud init template for EC2 calori instances.
#
#  In case you need it, the log of the cloud-init can be found at: 
#    /var/log/cloud-init-output.log
#
packages:
 - unzip
 - nginx
 - jq

write_files:
  - path: /home/ubuntu/install-upgrade.sh
    owner: root:root
    permissions: "0755"
    content: |
      #!/bin/bash
      #
      #  Script to install or update deployex
      #
      # Check if the version was passed as an argument
      if [ -z "$1" ]; then
          # If not passed, use the default value
          VERSION="0.1.0"
      else
          # If passed, use the passed value
          VERSION="$1"
      fi
      # Stop service (if it is running)
      systemctl stop deployex.service
      #
      echo ""
      echo "#           Updating Deployex              #"
      cd /tmp
      echo "# Download the latest deployex version     #"
      rm -f deployex-ubuntu-20.04.tar.gz
      wget https://github.com/thiagoesteves/deployex/releases/download/$${VERSION}/deployex-ubuntu-20.04.tar.gz
      if [ $? != 0 ]; then
              echo "Error while trying to download the version: $${VERSION}"
              exit
      fi
      echo "# Clean and create a new directory         #"
      OPT_DIR=/opt/deployex
      rm -rf $OPT_DIR
      mkdir -p $OPT_DIR
      cd $OPT_DIR
      tar xf /tmp/deployex-ubuntu-20.04.tar.gz
      echo "# Start systemd                            #"
      systemctl daemon-reload
      systemctl enable --now deployex.service
  - path: /home/ubuntu/install-otp-certificates.sh
    owner: root:root
    permissions: "0755"
    content: |
      #!/bin/bash
      #
      #  Script to install certificates
      #
      echo ""
      echo "# Installing Certificates env: ${account_name} at /usr/local/share/ca-certificates #"
      echo "Retrieving and saving ......"
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-ca | jq -r .SecretString > /usr/local/share/ca-certificates/ca.crt
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-key | jq -r .SecretString > /usr/local/share/ca-certificates/deployex.key
      aws secretsmanager get-secret-value --secret-id holidex-${account_name}-otp-tls-key | jq -r .SecretString > /usr/local/share/ca-certificates/calori.key
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-crt | jq -r .SecretString > /usr/local/share/ca-certificates/deployex.crt
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-crt | jq -r .SecretString > /usr/local/share/ca-certificates/calori.crt
      echo "[OK]"
  - path: /home/ubuntu/config.json
    owner: root:root
    permissions: "0644"
    content: |
      {
        "agent": {
          "run_as_user": "root"
        },
        "logs": {
          "logs_collected": {
            "files": {
              "collect_list": [
                {
                    "file_path": "/var/log/deployex.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-deployex-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                },
                {
                    "file_path": "/var/log/calori-stdout.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-calori-stdout-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                },
                {
                    "file_path": "/var/log/calori-stderr.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-calori-stderr-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                }
              ]
            }
          }
        }
      }
  - path: /etc/nginx/sites-available/default
    owner: root:root
    permissions: "0644"
    content: |
        upstream phoenix {
            server 127.0.0.1:4000 max_fails=5 fail_timeout=60s;
        }
      
        server {
            server_name  ${hostname};
            listen 80;

            client_max_body_size 30M;
            location / {
                allow all;

                # Proxy Headers
                proxy_http_version 1.1;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $http_host;
                proxy_set_header X-Cluster-Client-Ip $remote_addr;

                # The Important Websocket Bits!
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";

                proxy_pass http://phoenix;
            }
        }
  - path: /etc/systemd/system/deployex.service
    owner: root:root
    permissions: "0644"
    content: |
      [Unit]
      Description=Deployex daemon
      After=network.target
      
      [Service]
      Environment=SHELL=/usr/bin/bash
      Environment=AWS_REGION=${aws_region}
      Environment=CALORI_PHX_HOST=${hostname}
      Environment=CALORI_PHX_SERVER=true
      Environment=CALORI_PHX_PORT=4000
      Environment=CALORI_CLOUD_ENVIRONMENT=${account_name}
      Environment=CALORI_OTP_TLS_CERT_PATH=/usr/local/share/ca-certificates
      Environment=DEPLOYEX_CLOUD_ENVIRONMENT=${account_name}
      Environment=DEPLOYEX_OTP_TLS_CERT_PATH=/usr/local/share/ca-certificates
      Environment=DEPLOYEX_STORAGE_ADAPTER=s3
      Environment=DEPLOYEX_MONITORED_APP_NAME=calori
      ExecStart=/opt/deployex/bin/deployex start
      StandardOutput=append:/var/log/deployex.log
      KillMode=process
      Restart=on-failure
      RestartSec=3
      LimitNPROC=infinity
      LimitCORE=infinity
      LimitNOFILE=infinity
      RuntimeDirectory=deployex
      User=deployex
      Group=deployex
      
      [Install]
      WantedBy=multi-user.target
runcmd:
  - cd /tmp
  - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "-o"  "awscliv2.zip"
  - unzip "awscliv2.zip"
  - ./aws/install
  - ./aws/install --update
  - mkdir /opt/deployex
  - useradd  -c "Deployer User" -d  /var/deployex -s  /usr/sbin/nologin --user-group --no-create-home deployex
  - mkdir /etc/deployex
  - mkdir /var/lib/deployex
  - chown deployex:deployex /var/lib/deployex
  - touch /var/log/deployex.log
  - touch /var/log/calori-stdout.log
  - touch /var/log/calori-stderr.log
  - chown deployex:deployex /var/log/calori-stdout.log
  - chown deployex:deployex /var/log/calori-stderr.log
  - wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  - dpkg -i -E ./amazon-cloudwatch-agent.deb
  - /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/config.json -s
  - systemctl enable --no-block nginx 
  - systemctl start --no-block nginx
  - reboot