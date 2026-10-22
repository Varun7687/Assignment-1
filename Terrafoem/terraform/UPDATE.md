# Assignment 1: GitHub and shared-permission update

This is an update pack for your supplied, working project, not a replacement deployment or a new website design. The HTML remains inside user_data.sh.tftpl. Do not use the separate script.sh or index.html supplied earlier for this update.

## What changed

* main.tf: pass the optional GitHub URL to the existing template as base64. All original infrastructure definitions, resource addresses, existing-key lookup, region inputs and disk configuration remain unchanged.
* variables.tf: append optional github_repository_url, defaulting to an empty string. Your existing variables and actual terraform.tfvars are not replaced.
* user_data.sh.tftpl: retain the original embedded HTML and disk/user/SSH/Apache setup. Replace only the shared Git setup and add the remote input. The template no longer resets the branch or stages/commits existing team work on a rerun.
* Shared Git setup: configure the exact safe.directory path for root, Asha and Ravi; keep group-write access, setgid directories and default ACLs; restrict .git to webteam; configure origin only if supplied and refuse a conflicting existing remote or push URL.
* configure-shared-github.sh: the same Git/permission setup as a standalone update for the already-working server. It does not format/mount disks, create accounts, replace SSH keys, rewrite index.html, or run Terraform. It ensures the existing Asha and Ravi accounts are members of webteam.
* .gitignore: retain original rules and add exclusions for additional personal input files, private key extensions, environment files and logs. This does not untrack files already committed.

No automatic clone, fetch, pull or push is added. The generated page and local working tree stay the source of the website. The remote setting does not create a GitHub repository or authorize accounts. A genuinely new local repository receives the original bootstrap-style initial commit; an existing repository's branch, index and commits are preserved.

## Recommended: update the running EC2 instance without replacement

Use this route for the server that already works. Do not run the entire bootstrap template manually against a live server.

1. Back up the website and its Git history. On the EC2 instance, as ec2-user:

```bash
sudo tar --acls --xattrs -czf /root/status-before-github-$(date +%Y%m%d-%H%M%S).tgz -C /data/www status
```

Protect this backup and your workstation's original Terraform project. A backup command succeeding is not a tested recovery plan.

2. Transfer only configure-shared-github.sh to ec2-user's home directory on the existing instance using MobaXterm's file-transfer pane. Do not put this helper, Terraform state, personal tfvars or private keys in the served website directory.
3. Replace OWNER and REPOSITORY with the real, intended GitHub destination. On EC2:

```bash
sudo env GITHUB_REPOSITORY_URL='git@github.com:OWNER/REPOSITORY.git' bash ./configure-shared-github.sh
```

This is a configuration command, not a push. If origin already points elsewhere, the helper stops rather than changing it. Review the existing remote before making any deliberate change. It does not clear another user's Git lock files. Coordinate so nobody is editing/staging/committing during setup.

4. Asha and Ravi should start fresh SSH sessions after setup so any updated group membership takes effect. In each user's own SSH session, without sudo:

```bash
id
git -C /data/www/status status
git -C /data/www/status remote -v
```

Verify webteam membership and that Git can read the working tree without dubious-ownership errors. Use getfacl /data/www/status and getfacl /data/www/status/.git to review ACLs. The helper deliberately does not rewrite an already-correct HTML file or restart Apache.

## GitHub authorization: separate from EC2 login permissions

Being in webteam grants local editing/Git-metadata access; it does not grant GitHub repository access. Configure each person's actual Git identity in their own login session:

```bash
git config --global user.name "YOUR_COMMIT_NAME"
git config --global user.email "YOUR_GITHUB_VERIFIED_OR_NOREPLY_EMAIL"
```

For an SSH GitHub remote, each user needs their own GitHub-authentication key and their GitHub account must have write access to the repository. Do not reuse or copy anyone else's EC2 login private key. Generate a new GitHub key only if that chosen filename does not exist:

```bash
ssh-keygen -t ed25519 -f "$HOME/.ssh/github-assignment-1" -C "assignment-1-github"
cat "$HOME/.ssh/github-assignment-1.pub"
```

Choose a passphrase and never overwrite an existing private key. Add only the public line to the appropriate GitHub account under Settings > SSH and GPG keys. Keep its private file on that user's EC2 account. Ensure each account has repository write access through GitHub's collaborator/team settings.

In each user's ~/.ssh/config, merge this stanza carefully; preserve existing settings and avoid conflicting GitHub entries:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github-assignment-1
    IdentitiesOnly yes
```

Set chmod 600 ~/.ssh/config. Test with ssh -T git@github.com and verify the presented host fingerprint against GitHub's published SSH fingerprints before accepting it. Never disable host-key checking. A successful GitHub authentication greeting normally exits with status 1 because shell access is not provided.

Review git status, git remote -v, git log --oneline and git ls-files before publishing. If publishing to a new empty GitHub repository from the original assignment-1 branch, an authorized user can explicitly run:

```bash
cd /data/www/status
git push -u origin assignment-1
```

The helper does not perform that push. For an existing/nonempty GitHub repository, inspect its branches/history and agree on integration before pushing. Do not force-push or reset histories to make them match. If your existing branch is not assignment-1, the update deliberately preserves it; select the intended publishing branch explicitly.

Coordinate access to this one shared working tree. Asha and Ravi share its Git index, branch and repository configuration; this is not equivalent to independent clones. Root can still edit through administrative access. Shared Git configuration/hooks are not a security boundary: use this only for mutually trusted users, not untrusted production access. Per-user GitHub authorization is not automatically configured for root.

## Keep the Terraform source updated too

Back up your current project directory first. Merge these four code files into the same existing working directory:

* main.tf
* variables.tf
* user_data.sh.tftpl
* .gitignore

Keep your existing outputs.tf, README.md, actual terraform.tfvars, state and state backup, backend files, .terraform directory and provider lock file. This ZIP intentionally does not include or replace them. Do not create a new deployment folder/state for this update.

Add only the following non-secret setting to your existing terraform.tfvars, using the real destination:

```hcl
github_repository_url = "git@github.com:OWNER/REPOSITORY.git"
```

Leave existing_key_pair_name, region, trusted SSH CIDR and both public keys as they are. No admin_public_key or team_public_keys variable is introduced. Never put private keys, passwords or GitHub tokens into Terraform inputs or User Data.

In your local Windows terminal, in the folder containing the existing main.tf:

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Stop and review the plan. Your original main.tf sets user_data_replace_on_change = true: changing this template is expected to propose EC2 replacement. Its root disk is deleted on replacement, and its public IP/host key can change. Latest-AMI selection or other input differences may cause additional changes. The website EBS volume is separately managed, but you must verify the plan does not delete/replace it unexpectedly. Preserve backups. An attachment replacement is not the same as volume destruction.

For only updating today's running server, the helper route above does not require terraform apply. Updating source files does not automatically apply them, and running the helper does not mark Terraform's stored User Data as updated. A later Terraform apply can still propose the replacement; do not ignore that plan. Do not run terraform destroy for this change.

## Validation performed

16 local automated checks passed. They cover original HTML content, original infrastructure/variable preservation, rendered Bash syntax, helper Bash syntax, actual local Git initialization/remote/idempotency, existing branch/staging/uncommitted-file preservation, remote conflict and unexpected push-URL refusal, URL rules and symlink-metadata refusal.

The Git tests use temporary local repositories and stub permission-related commands. They do not verify real multi-user permissions, Linux ACL enforcement or SELinux behavior. The rendered-template syntax check uses a small substitution fixture, not Terraform's templatefile engine. Terraform CLI and an HCL parser were not available; terraform validate/plan/apply were not run. No AWS deployment, SSH login, GitHub authentication/push, disk setup, Apache/SELinux or live-server execution was performed.

Run the included tests locally where Python 3, Bash and Git are available:

```bash
python3 -m unittest discover -s tests -v
```

The ZIP excludes state, real tfvars, private keys and provider lock changes. State and personal settings should remain private and outside website/public repository directories. The archive is an update pack, not a complete new-deployment bundle. changes.diff shows the targeted code changes.
