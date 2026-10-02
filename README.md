# pipeline-demo

A legacy-style Python web app migrated to Azure with **Azure DevOps Pipelines + Terraform** (App Service = replatform), plus an optional **Terraform + Ansible VM** path (rehost).

## What every file does

| File | Type | Used by | What it does |
|---|---|---|---|
| `azure-pipelines.yml` | Azure Pipelines YAML | Azure DevOps (main pipeline, runs on every push to `main`) | Defines the CI/CD: **Build** stage (tests + artifacts), then **Deploy dev** and **Deploy prod** using the template. Holds the settings you change most: service connection name, Terraform state storage, `location` (region), `sku` per environment. |
| `templates/deploy-stage.yml` | Azure Pipelines YAML **template** | Included twice by `azure-pipelines.yml` (dev, prod) | One deploy stage: install Terraform → `terraform init/plan/apply` → upload `app.zip` to the Web App → smoke test `/health`. Parameters: `env`, `sku`, `dependsOn`. Write once, reuse per environment. |
| `azure-pipelines-vm.yml` | Azure Pipelines YAML | Second pipeline, **manual** (`trigger: none`) | Rehost path: Terraform creates a VM (`infra-vm/`), Ansible configures it (`ansible/site.yml`), smoke test. Optional. |
| `infra/main.tf` | Terraform | Deploy stages | The Azure resources for the app: resource group, App Service plan, Linux Web App (Python 3.12, HTTPS only, managed identity, `APP_ENV`). |
| `infra/variables.tf` | Terraform | Deploy stages | Inputs: `env`, `location`, `sku` (values come from the pipeline with `-var`). |
| `infra/outputs.tf` | Terraform | Deploy stages | Outputs after apply: `app_name`, `app_url` (the pipeline reads `app_name`). |
| `infra-vm/main.tf` | Terraform | VM pipeline | VNet, subnet, NSG (SSH + HTTP), public IP, NIC, Ubuntu VM with your SSH public key. |
| `infra-vm/cfdemo_id_ed25519.pub` | SSH public key | VM pipeline | *You create it* (`ssh-keygen`). Safe to commit. The private key goes to Azure DevOps *Secure files*, never to Git. |
| `ansible/site.yml` | Ansible playbook (YAML) | VM pipeline | Installs python3-venv + nginx, copies the app, virtualenv, systemd service with gunicorn, nginx reverse proxy. |
| `src/app.py` | Python (Flask) | The application | Two endpoints: `/` (app name, env, version) and `/health` (`{"status":"ok"}`). |
| `src/requirements.txt` | pip | Build stage + App Service | Python dependencies: flask, gunicorn. |
| `tests/test_app.py` | pytest | Build stage | Unit test: `/health` returns 200 and `ok`. A failing test stops the pipeline. |
| `scripts/check-appservice-quota.sh` | Bash | You, on your Mac | Tests which regions/sizes your subscription can create an App Service plan in (quota check). |
| `.gitignore` | Git | Git | Files never committed: Terraform state/plugins, virtualenv, private SSH key. |
| `DEMO-STEPS.md` | Notes | You | Setup steps and troubleshooting. |
| `deployment.yaml`, `service.yaml` (older, if present) | Kubernetes manifests | Not used by these pipelines | From an earlier AKS experiment; harmless. |

> Three different "YAML dialects" live here: **Azure Pipelines** YAML (`azure-pipelines*.yml`, `templates/`), **Ansible** YAML (`ansible/site.yml`) and **Kubernetes** YAML (`deployment.yaml`, `service.yaml`). Same syntax, different meaning: each tool defines its own keywords.

## How the pieces connect
```
git push github main
  └─> Azure DevOps reads azure-pipelines.yml
        ├─ Stage Build: tests/test_app.py, src/ → artifact "app" (app.zip), infra/ → artifact "infra"
        ├─ Stage Deploy dev  (templates/deploy-stage.yml, env=dev)
        │     Terraform (infra/*.tf) → rg-cfdemo-dev + plan + web app → upload app.zip → curl /health
        └─ Stage Deploy prod (same template, env=prod, waits for approval on environment "prod")
Service connection sc-azure-demo = how the pipeline logs in to Azure
Storage account sttfstatekmav01/tfstate = where Terraform remembers what it created
```

## How to modify a pipeline YAML file

### 1. YAML basics (5 rules)
1. **Indentation = structure.** Use **spaces, never tabs**; be consistent (2 spaces here). A wrong indent is the #1 error.
2. `key: value` pairs; a **space after the colon** is required.
3. Lists start with `- ` (dash + space). Each `- task:` / `- script:` / `- stage:` is one list item.
4. `|` starts a multi-line block (used for scripts); everything indented below it is the text.
5. `#` starts a comment. Quote values with special characters: `'B1'`, `'*'`, `': '`.

```yaml
variables:            # a map
  location: 'northeurope'
steps:                # a list
- script: |           # multi-line script
    echo one
    echo two
  displayName: 'Two lines'
```

### 2. Azure Pipelines structure
```
trigger / pr / schedules      → when it runs
pool                          → which agent (vmImage: ubuntu-latest, or name: <self-hosted pool>)
variables                     → values reused below
stages → jobs → steps         → what runs (steps = - task: ... or - script: ...)
```
- `job` = runs on one agent; `deployment` = a job that targets an **environment** (approvals, history).
- `- task: Name@version` = a built-in task (e.g. `AzureCLI@2`, `Maven@4`); `inputs:` are its settings.
- `- script:` = shell commands (bash on Linux). `- pwsh:` = PowerShell.
- `- template: file.yml` + `parameters:` = include reusable YAML.

### 3. Three ways to use a value (the confusing part)
| Syntax | When it's resolved | Use for | Example |
|---|---|---|---|
| `${{ parameters.env }}` / `${{ variables.x }}` | **Compile time** (before the run starts) | Template parameters, building stage names, conditions on structure | `stage: Deploy_${{ parameters.env }}` |
| `$(location)` | **Runtime**, just before a step runs | Variables in task inputs and scripts | `-var="location=$(location)"` |
| `$[ ... ]` | Runtime expression | Variables computed at runtime | `isMain: $[eq(variables['Build.SourceBranch'], 'refs/heads/main')]` |

(`condition:` lines are also evaluated at runtime and are written without `$[ ]`, e.g. `condition: succeeded()`.)

Predefined variables exist too: `$(Build.BuildId)`, `$(Build.SourceBranch)`, `$(Pipeline.Workspace)`, `$(Build.ArtifactStagingDirectory)`.

### 4. Common edits in this repo
- **Change region:** `azure-pipelines.yml` → `location: 'swedencentral'`
- **Change size per environment:** in the `- template:` block for that env → `sku: 'B1'`
- **Add a step** (e.g. lint) in the Build job, at the same indentation as the other `- task:` lines:
  ```yaml
      - script: pip install flake8 && flake8 src
        displayName: 'Lint'
  ```
- **Add an environment** (e.g. test): copy a `- template:` block, set `env: test`, `dependsOn: [ Deploy_dev ]`, and change prod to `dependsOn: [ Deploy_test ]`; create environment `test` in Azure DevOps.
- **Run only on main:** add to a stage `condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))`
- **Secret value:** never in YAML. Use a *variable group* / Key Vault and reference it with `$(name)`.

### 5. How to edit safely
- **Azure DevOps web editor** (*Pipelines → pipeline → Edit*): syntax highlighting, **Validate** (⋯ → Validate), and the **task assistant** on the right that generates task YAML for you. Saving commits to the repo.
- **VS Code** with the *Azure Pipelines* extension (and *YAML* extension): autocomplete and error underlining.
- After a change: commit → push → watch the run. If it fails *before* starting ("could not be found", "unexpected value"), it's a YAML/configuration error: the message names the line.
- *⋯ → Download full YAML* on a run shows the YAML **after** templates are expanded: useful to understand templates.
- Reference: [YAML schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/), [expressions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/expressions), [variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/variables).
