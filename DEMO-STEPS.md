# Demo setup (tonight)

1. Copy these files into your local pipeline-demo repo (overwrite azure-pipelines.yml).
2. Create the service connection `sc-azure-demo`.
   Where: open the PROJECT (DevOps-Training; your organization is mavroudakisk) → Project settings (bottom left) → Pipelines section → Service connections.
   a) Try automatic: Azure Resource Manager → App registration (automatic) + Workload identity federation → Subscription → All resource groups → name sc-azure-demo → tick "Grant access permission to all pipelines" → Save.
   b) If Save does nothing / no connection appears after refresh (common with personal @outlook.com accounts: the organization isn't connected to an Entra ID tenant, so Azure DevOps can't create the app registration for you), do it manually:
      az login
      SUB=$(az account show --query id -o tsv); echo $SUB
      az ad sp create-for-rbac --name sp-cfdemo-devops --role Contributor --scopes /subscriptions/$SUB
      (copy appId, password - shown once!, tenant)
      Then: Azure Resource Manager → Identity type "App registration or managed identity (manual)" → Credential "Secret" →
      name sc-azure-demo, tenant ID = tenant, subscription ID = $SUB, subscription name "Azure subscription 1",
      application (client) ID = appId, client secret = password → tick "Grant access permission to all pipelines" → Verify and save.
   The pipelines work with either connection type.
3. Create the Terraform state storage (once):
   az login
   az group create -n rg-tfstate -l westeurope
   az storage account create -n sttfstatekmav01 -g rg-tfstate -l westeurope --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false
   az storage container create -n tfstate --account-name sttfstatekmav01 --auth-mode key
   (If the name is taken, choose another and change tfStateAccount in azure-pipelines.yml.)
   The service connection needs to read the storage keys: it has Contributor on the subscription, which is enough.
4. Push:
   git add . && git commit -m "Demo: Flask app, Terraform App Service, multi-stage pipeline"
   git pull github main --no-rebase
   git push github main
5. In Azure DevOps the pipeline runs: Build → Deploy_dev → Deploy_prod. Click "Permit" if asked.
6. After the first run: Pipelines → Environments → prod → Approvals and checks → Approvals → add yourself. Run again.

# Optional stretch: rehost path (Azure VM with Terraform + Ansible)
Only after the main pipeline works. Files: infra-vm/, ansible/, azure-pipelines-vm.yml

1. Create the SSH key pair on your Mac and copy the PUBLIC key into the repo:
   ssh-keygen -t ed25519 -f ~/.ssh/cfdemo_id_ed25519 -N "" -C cfdemo
   cp ~/.ssh/cfdemo_id_ed25519.pub infra-vm/
2. Upload the PRIVATE key (~/.ssh/cfdemo_id_ed25519) to Azure DevOps:
   Pipelines → Library → Secure files → + Secure file. Name must stay cfdemo_id_ed25519.
   Never commit the private key (it is in .gitignore).
3. Commit and push (git add . / commit / push github main).
4. Azure DevOps → Pipelines → New pipeline → GitHub → kmav/pipeline-demo →
   Existing Azure Pipelines YAML file → /azure-pipelines-vm.yml → Run. Click "Permit" for the secure file.
5. Open http://<vm-ip>/ (IP is printed in the Terraform step) → shows "env": "vm".
6. Cleanup after the interview: az group delete -n rg-cfdemo-vm --yes --no-wait

# Cleanup after the interview
az group delete -n rg-cfdemo-dev --yes --no-wait
az group delete -n rg-cfdemo-prod --yes --no-wait
az group delete -n rg-tfstate --yes --no-wait
az ad sp delete --id <appId>     # only if you created the service principal manually
Keep the VisualStudioOnline-... resource group (Azure DevOps billing link).
