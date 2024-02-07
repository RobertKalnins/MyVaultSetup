
# My Server Vault deployment

## 1. Install and configure vault

##### As admin:
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

##### Confirm installed 
vault --version

### Create and switch to vault user
sudo useradd -m -d /opt/vault -s /bin/bash vault \
sudo su - vault

### Create config, config file, and data folders
mkdir -p ~/data \
mkdir -p ~/config

```
tee ~/config/vault.hcl<<EOF
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true
```

## 2. Set vault address environment variable and run vault.
##### Note if you get a HTTPS error at any point, make sure $VAULT_ADDR is http: not https
export VAULT_ADDR='http://127.0.0.1:8200' \
vault server -config=/opt/vault/config/vault.hcl \

##### Save the keys and initial token somewhere safe

## 3. Open new terminal/session and switch to vault user then initialize the vault
sudo su - vault \

export VAULT_ADDR='http://127.0.0.1:8200' \
vault operator init

#### Unseal vault
vault operator unseal \
<enter key>

##### Do this 3 times, 3 different keys.

##### Switch back to the other session (running vault) and terminate it with Ctrl-C

## 4. Create the scripts and services for autostartup and auto unseal.

### Note: I'm using a .env and have this vault configured to only reply to local requests.

### Don't do this in production, you can find the correct methods using HA or cloud below:
### https://developer.hashicorp.com/vault/tutorials/auto-unseal

### Scripts - and services - see additional files for content
sudo vi /etc/vault.d/vault-unseal.env \
sudo vi /usr/local/bin/unseal-vault.sh \

sudo chown vault:vault /etc/vault.d/vault-unseal.env \
sudo chown vault:vault /usr/local/bin/unseal-vault.sh \
sudo chmod 700 /usr/local/bin/unseal-vault.sh \
sudo chmod 400 /etc/vault.d/vault-unseal.env \

#### Services
sudo vi /etc/systemd/system/vault.service \
sudo vi /etc/systemd/system/vault-unseal.service \

sudo systemctl daemon-reload \
sudo systemctl enable vault.service \
sudo systemctl enable vault-unseal.service \
sudo systemctl start vault.service \

### Check vault status
sudo systemctl status vault.service \

```
bonzadm@onlybeans:~$ sudo systemctl status vault.service
● vault.service - Vault
     Loaded: loaded (/etc/systemd/system/vault.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2024-02-07 14:30:28 UTC; 6min ago
   Main PID: 2234 (vault)
      Tasks: 11 (limit: 57759)
     Memory: 117.0M
        CPU: 3.055s
     CGroup: /system.slice/vault.service
             └─2234 /usr/bin/vault server -config=/opt/vault/config/vault.hcl

Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.045Z [INFO]  rollback: Starting the rollback manager with 256 workers
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.045Z [INFO]  rollback: starting rollback manager
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.045Z [INFO]  core: restoring leases
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.045Z [INFO]  expiration: lease restore complete
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.048Z [INFO]  identity: entities restored
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.048Z [INFO]  identity: groups restored
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.048Z [INFO]  core: starting raft active node
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.049Z [INFO]  storage.raft: starting autopilot: config="&{false 0 10s 24h0m0s 1000 0 10s false redundancy_zone upgrade_version}" reconcile_interval=0s
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.052Z [INFO]  core: usage gauge collection is disabled
Feb 07 14:30:34 onlybeans vault[2234]: 2024-02-07T14:30:34.060Z [INFO]  core: post-unseal setup complete
```
### Check vault-unseal service
sudo systemctl status vault-unseal.service

```
bonzadm@onlybeans:~$ sudo systemctl status vault-unseal.service
● vault-unseal.service - Unseal Vault
     Loaded: loaded (/etc/systemd/system/vault-unseal.service; enabled; vendor preset: enabled)
     Active: active (exited) since Wed 2024-02-07 14:30:34 UTC; 7min ago
    Process: 2235 ExecStart=/usr/local/bin/unseal-vault.sh (code=exited, status=0/SUCCESS)
   Main PID: 2235 (code=exited, status=0/SUCCESS)
        CPU: 328ms

Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Storage Type            raft
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Cluster Name            vault-cluster-c7099e72
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Cluster ID              65d52c15-c47d-490d-745b-d3c201537fb5
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: HA Enabled              true
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: HA Cluster              n/a
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: HA Mode                 standby
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Active Node Address     <none>
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Raft Committed Index    222
Feb 07 14:30:33 onlybeans unseal-vault.sh[2336]: Raft Applied Index      222
Feb 07 14:30:34 onlybeans systemd[1]: Finished Unseal Vault.
```

## Switch back to your vault user session, or sudo su - vault
##### Remember to export VAULT_ADDR="http://127.0.0.1:8200" if $VAULT_ADDR is empty. Could also add this export to your .bashrc

export VAULT_ADDR="http://127.0.0.1:8200" \
vault status

```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.15.5
Build Date              2024-01-26T14:53:40Z
Storage Type            raft
Cluster Name            vault-cluster-c7099e72
Cluster ID              65d52c15-c47d-490d-745b-d3c201537fb5
HA Enabled              true
HA Cluster              https://127.0.0.1:8201
HA Mode                 active
Active Since            2024-02-07T14:30:34.012053665Z
Raft Committed Index    268
Raft Applied Index      268
```

### Restart the vault service, test the vault is unlocked.

### If doing this on a server where it's safe to do so, reboot and confirm vault starts up and unseals.