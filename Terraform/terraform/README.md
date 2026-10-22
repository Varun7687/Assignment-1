# Assignment 1 — Terraform with permanent administrator SSH

This folder creates Amazon Linux 2023 EC2, a permanent AWS SSH key pair for `ec2-user`, a security group, and a separate encrypted gp3 EBS volume with its attachment. The full HTML page is embedded in `user_data.sh.tftpl`; it is written to `/data/www/status/index.html` and served at `/status/`. No separate HTML upload is required.

## Access model

- **Administrator:** `ec2-user`, authenticated with a separate permanent administrator key. Amazon Linux configures this launch key independently of the custom bootstrap. `ec2-user` can use `sudo`; this remains an administration path if the custom bootstrap fails.
- **Team accounts:** `asha` and `ravi`, each with their own public key installed by bootstrap. They belong to `webteam` but are not granted sudo.
- **Root:** direct root SSH and password authentication stay disabled. Use `sudo -i` after logging in as `ec2-user`.
- No `aws ec2-instance-connect send-ssh-public-key` command or 60-second upload window is needed for this permanent-key login. SSH sessions can still disconnect for ordinary network/server reasons.
- SSH is allowed only from `ssh_admin_cidr`; HTTP is public for this demo. Different team networks need their own explicitly permitted SSH sources, not an internet-wide SSH rule.

## Fresh-start workflow after terraform destroy

The previous instance has been destroyed: none of its IP addresses, SSH sessions, root-disk Git installation, or GitHub credentials can be used as the new server. This bundle rebuilds the server from scratch. Do not delete Terraform state unless you have verified destroy completed and no resources remain tracked; retain backend settings and the provider lock file where applicable.

**Where each action runs:**

1. **Local MobaXterm terminal:** create or select your EC2 login key pairs, configure Terraform inputs, deploy Terraform, and initiate SSH. These actions must happen before the new instance is accessible. You do not need Windows CMD or a Windows Git installation.
2. **New EC2 instance:** Git is installed automatically by bootstrap. Run all Git configuration, GitHub SSH key generation, commits, and pushes here, as a team account rather than root.
3. **GitHub website:** authorize the instance-generated public key and create an empty new repository. No token or private key goes into Terraform. The old GUI-based GitHub repository is left untouched.

Git installation can be automated; GitHub authorization cannot be completed until you authorize the account. Destroying Terraform resources does not delete old GitHub repositories or revoke their SSH keys; revoke old server keys in GitHub if they are no longer used.

## 1. Prepare EC2 SSH keys — LOCAL MobaXterm terminal

These are login keys for connecting TO EC2, not GitHub credentials. Use three separate key pairs. If files already exist, do not overwrite them: reuse the intended keys or choose new filenames and retain the matching private files.

```bash
mkdir -p /drives/c/Users/VarunKumar/.ssh
ssh-keygen -t ed25519 -f /drives/c/Users/VarunKumar/.ssh/admin-assignment-1 -C admin-assignment-1
ssh-keygen -t ed25519 -f /drives/c/Users/VarunKumar/.ssh/asha-assignment-1 -C asha-assignment-1
ssh-keygen -t ed25519 -f /drives/c/Users/VarunKumar/.ssh/ravi-assignment-1 -C ravi-assignment-1
cat /drives/c/Users/VarunKumar/.ssh/admin-assignment-1.pub
cat /drives/c/Users/VarunKumar/.ssh/asha-assignment-1.pub
cat /drives/c/Users/VarunKumar/.ssh/ravi-assignment-1.pub
```

Replace the Windows username if using another computer. Choose passphrases to protect your private keys. Put only the three full `.pub` lines in Terraform inputs; never upload the private files. EC2 administrator key pairs support ED25519 or RSA.

## 2. Configure persistent inputs

Run Terraform from the folder containing `main.tf`, not your home folder. On a NEW deployment, copy `terraform.tfvars.example` to `terraform.tfvars`. If you already have `terraform.tfvars`, retain its values and ADD `admin_public_key`; do not overwrite existing settings with example placeholders.

```hcl
aws_region       = "us-east-1"
ssh_admin_cidr   = "YOUR_CURRENT_PUBLIC_IPV4/32"
admin_public_key = "PASTE_COMPLETE_ADMIN_PUBLIC_KEY_LINE"
asha_public_key  = "PASTE_COMPLETE_ASHA_PUBLIC_KEY_LINE"
ravi_public_key  = "PASTE_COMPLETE_RAVI_PUBLIC_KEY_LINE"
```

Replace every placeholder. Save as exactly `terraform.tfvars`, not `.txt`. Terraform reads this filename automatically; it does NOT automatically read `terraform.tfvars.example`. The region requires a default VPC with a public subnet, a route to an internet gateway, and usable internet access. This configuration selects the first subnet in sorted subnet-ID order; a modified default VPC may need network repair first.

Use your existing authorized AWS CLI/SSO credentials. No AWS access keys belong in these files. Your AWS identity needs permission to manage these resources, including `ec2:ImportKeyPair` for the administrator public key.

## 3. Plan and deploy — LOCAL MobaXterm terminal

Run inside the extracted `terraform` folder using your existing local Terraform installation.

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Review the plan BEFORE running:

```bash
terraform apply tfplan
```

Applying a saved plan executes it without a further confirmation prompt and creates billable AWS resources. A clean deployment has five managed resources. With an existing deployment, counts differ because the instance and attachment may be replaced.

### Updating the existing assignment

- Copy only the updated code files into the SAME working directory. Keep your `terraform.tfvars`, Terraform state files, backend settings, and provider lock file. Do not copy another deployment's state or delete your state.
- Add `admin_public_key` to your existing input file.
- Generate a FRESH plan after changing the code; do not apply an old saved plan.
- Adding/changing `key_name` and changing this bootstrap cause EC2 replacement. Its root disk is deleted, root-disk changes are lost, and its public IP/host key may change. Back up important files first and review the replacement plan.
- The separately managed website EBS volume should remain and be reattached. Confirm that the plan does not destroy/replace it unexpectedly. The bootstrap preserves an existing nonempty website `index.html`.
- Do not use `terraform destroy` just to add administrator access.

## 4. Direct administrator login

Use the NEW public IP from `terraform output -raw public_ipv4`. Output `admin_ssh_command` also prints the username and address, with a private-key-path placeholder.

**MobaXterm** (replace `YOUR_WINDOWS_USERNAME` and `EC2_PUBLIC_IP`):

```bash
ssh -i "/drives/c/Users/YOUR_WINDOWS_USERNAME/.ssh/admin-assignment-1" ec2-user@EC2_PUBLIC_IP
```

Verify the server host fingerprint before accepting it. If the instance was replaced, verify any changed host key against the new instance's EC2 system log; do not disable SSH host-key checking.

Once logged in as `ec2-user`:

```bash
sudo -i
whoami
exit
```

`whoami` prints `root` inside the root shell. `exit` returns to `ec2-user`. Prefer scoped commands such as `sudo systemctl status httpd` when a full root shell is unnecessary.

## 5. Verify bootstrap and website

As `ec2-user`:

```bash
sudo cloud-init status --long
sudo tail -n 80 /var/log/user-data.log
findmnt /data/www
lsblk -f
systemctl is-active httpd
curl -f http://localhost/status/
id asha
id ravi
getent group webteam
```

Open the exact `status_page_url` output, using **HTTP** and **`/status/`**. The bare IP may show Apache's default page. Passed EC2 health checks do not guarantee cloud-init succeeded.

The bootstrap uses the existing `curl-minimal` command rather than installing conflicting full `curl`. Its security-group descriptions contain no unsupported apostrophe.

## 6. Connect GitHub — INSIDE the NEW EC2 instance

Git is already installed by user data. These commands are not for Windows CMD. First verify bootstrap completed successfully as `ec2-user` using section 5. Then log in directly as **Asha** from your local MobaXterm terminal:

```bash
ssh -i /drives/c/Users/VarunKumar/.ssh/asha-assignment-1 asha@EC2_PUBLIC_IP
```

Run the remaining commands **inside that Asha SSH session**, without sudo. Replace the identity placeholders with the name and email you intend to use for Git commits; GitHub's verified or noreply email can be used.

```bash
whoami
git --version
git config --global user.name "YOUR_COMMIT_NAME"
git config --global user.email "YOUR_GITHUB_COMMIT_EMAIL"
git config --global --add safe.directory /data/www/status
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -f "$HOME/.ssh/github-assignment-1" -C "assignment-1-github"
cat "$HOME/.ssh/github-assignment-1.pub"
```

This is a NEW, separate GitHub key generated on EC2, not the administrator/Asha/Ravi login key. Do not overwrite an existing key if rerunning. Keep its private file on EC2 and protect it with a passphrase. Add only the displayed public line to **GitHub → Settings → SSH and GPG keys → New SSH key**, selecting an authentication key. This authorizes the account you are signed into; never share a GitHub private key between the team users.

Add the following block ONCE to `~/.ssh/config` using `nano` or `vi`; preserve existing entries:

```sshconfig
Host github-assignment-1
    HostName github.com
    User git
    IdentityFile ~/.ssh/github-assignment-1
    IdentitiesOnly yes
```

Then:

```bash
chmod 600 "$HOME/.ssh/config"
ssh -T git@github-assignment-1
```

Verify the presented GitHub host fingerprint against GitHub's published fingerprints before accepting. A successful test names your GitHub username and says that GitHub does not provide shell access; exit code 1 on that successful greeting is normal. This test authorizes Git operations; it does not create a repository.

Create a NEW EMPTY repository in your GitHub account, for example `Assignment-1-Terraform-Rebuild`, without initializing README, .gitignore, or a license. The old `Assignment-1` repository is not changed. A private repository is a safer default; choose public only if you intend to publish the files.

The bootstrap has already initialized the WEBSITE repository, committed `index.html` and the generated deployment-report `README.md`, and created branch `assignment-1`. The following commands publish that website repository, NOT your local Terraform directory. Replace BOTH URL placeholders with your actual GitHub username and new repository name:

```bash
cd /data/www/status
git status
git remote -v
git remote add origin git@github-assignment-1:YOUR_GITHUB_USERNAME/YOUR_NEW_REPOSITORY.git
```

Use `remote add` only when there is no existing `origin`; otherwise review the existing destination before changing it. Review what will be published, then explicitly push:

```bash
git log --oneline --all
git ls-files
git push -u origin assignment-1
```

Never push passwords, private keys, tokens, Terraform state, or personal input files. The generated site README may include deployment paths and file names; review it before publishing. Future edits are made as Asha or Ravi, followed by `git add`, `git commit`, and `git push`. This shared directory has shared Git metadata: coordinate access so two people do not switch branches, stage, or commit at the same time. Separate clones are preferable for independent parallel work.

Ravi can configure his own Git identity and GitHub key by repeating the per-user setup in his own SSH session. His GitHub account also needs write permission on the chosen repository. The GitHub alias must exist in EACH user's SSH config because `origin` is shared. When a server is destroyed, its on-server private GitHub keys disappear; authorize a new key on the replacement and revoke obsolete keys.

### Terraform source vs website repository

The seven Terraform source files are supplied in this ZIP, on the deployment computer. They are not automatically pushed to GitHub or copied into the website directory. If you want those source files in a repository using only server-side Git, transfer them to a separate directory under the team user's home on the new instance, then initialize/review/push that repository there. Do not mix Terraform state, credentials, or `.terraform` into the public website directory. Bootstrap does not create GitHub repositories or push anything without your authorization.

## HTML, Git, and storage notes

The full HTML is embedded verbatim in a quoted shell heredoc; Terraform compresses user data before sending it to EC2. Public team keys are base64-encoded in the script to avoid shell quoting issues. The administrator public key is registered with AWS and selected by the instance's `key_name`; it is not a private key generated or stored by Terraform.

The data disk is identified by EBS serial, partitioned/formatted only when safe, and mounted persistently at `/data/www`. A non-ext4 filesystem is rejected rather than reformatted. The site has a group-writable local Git repository on branch `assignment-1`. Apache denies HTTP access to its `.git` directory. The footer states “Only the users Asha and Ravi can change the file.” This refers to ordinary users; root and sudo-capable administrators can still modify it. No GitHub remote is invented; use your actual repository URL and do not store GitHub tokens in Terraform or user data.

The generated site README records the assignment's `find` examples. You can also run:

```bash
find /data/www -type f -mtime -1 -print
find /data/www -type f -group webteam -print
```

If your public IP changes, update `ssh_admin_cidr` and review/apply a new plan. `terraform destroy` deletes the managed website data volume as well as the server; back up before destroying anything.
