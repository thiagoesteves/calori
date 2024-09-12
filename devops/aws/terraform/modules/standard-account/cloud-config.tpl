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
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-key | jq -r .SecretString > /usr/local/share/ca-certificates/calori.key
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-crt | jq -r .SecretString > /usr/local/share/ca-certificates/deployex.crt
      aws secretsmanager get-secret-value --secret-id calori-${account_name}-otp-tls-crt | jq -r .SecretString > /usr/local/share/ca-certificates/calori.crt
      echo "[OK]"
  - path: /home/ubuntu/deployex-config.json
    owner: root:root
    permissions: "0644"
    content: |
      {
        "app_name": "calori",
        "replicas": ${replicas},
        "account_name": "${account_name}",
        "deployex_hostname": "${deployex_hostname}",
        "release_adapter": "s3",
        "release_bucket": "calori-${account_name}-distribution",
        "secrets_adapter": "aws",
        "secrets_path": "deployex-calori-${account_name}-secrets",
        "aws_region": "${aws_region}",
        "version": "${deployex_version}",
        "os_target": "ubuntu-20.04",
        "deploy_timeout_rollback_ms": 600000,
        "deploy_schedule_interval_ms": 5000,
        "env": {
            "CALORI_PHX_HOST": "${hostname}",
            "CALORI_PHX_SERVER": true,
            "CALORI_CLOUD_ENVIRONMENT": "${account_name}",
            "CALORI_OTP_TLS_CERT_PATH": "/usr/local/share/ca-certificates",
            "CALORI_SECRETS_ADAPTER": "aws",
            "CALORI_SECRETS_PATH": "calori-${account_name}-secrets",
        }
      }
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
                    "file_path": "/var/log/deployex/deployex-stdout.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-deployex-stdout-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                },
                {
                    "file_path": "/var/log/deployex/deployex-stderr.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-deployex-stderr-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                },
                {
                    "file_path": "/var/log/calori/calori-*-stdout.log",
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "{instance_id}-calori-stdout-log",
                    "timezone": "UTC",
                    "timestamp_format": "%H: %M: %S%Y%b%-d"
                },
                {
                    "file_path": "/var/log/calori/calori-*-stderr.log",
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
          server 127.0.0.1:4001 max_fails=5 fail_timeout=60s;
          server 127.0.0.1:4002 max_fails=5 fail_timeout=60s;
      }

      upstream deployex {
          server 127.0.0.1:5001 max_fails=5 fail_timeout=60s;
      }

      server {
          listen 80;
          server_name calori.com.br deployex.calori.com.br;

          if ($host = calori.com.br) {
              return 301 https://$host$request_uri;
          } # managed by Certbot


          if ($host = deployex.calori.com.br) {
              return 301 https://$host$request_uri;
          } # managed by Certbot

          return 404; # managed by Certbot
      }

      server { 
          #listen 443 ssl; # managed by Certbot
          server_name  deployex.calori.com.br;
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

              proxy_pass http://deployex;
          }
          
          # Add here the letsencrypt paths
      }

      server {
          #listen 443 ssl; # managed by Certbot
          server_name  calori.com.br;
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
          # Add here the letsencrypt paths
      }
runcmd:
  - cd /tmp
  - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "-o"  "awscliv2.zip"
  - unzip "awscliv2.zip"
  - ./aws/install
  - ./aws/install --update
  - /home/ubuntu/install-otp-certificates.sh
  - wget https://github.com/thiagoesteves/deployex/releases/download/${deployex_version}/deployex.sh -P /home/ubuntu
  - chmod a+x /home/ubuntu/deployex.sh
  - /home/ubuntu/deployex.sh --install /home/ubuntu/deployex-config.json
  - wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  - dpkg -i -E ./amazon-cloudwatch-agent.deb
  - /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/home/ubuntu/config.json -s
  - systemctl enable --no-block nginx 
  - systemctl start --no-block nginx
  - reboot