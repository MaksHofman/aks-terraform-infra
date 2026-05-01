# AKS via Terraform — instrukcja

## Struktura plików
```
repo/
├── terraform/
│   ├── main.tf        ← zasoby Azure + backend
│   ├── variables.tf   ← parametry (region, rozmiar VM itp.)
│   └── outputs.tf     ← co wyświetlić po apply
└── .github/
    └── workflows/
        └── terraform.yml  ← pipeline CI/CD
```

---

## KROK 1 — Przygotuj container w Blob Storage

Twój storage account `tfstatetest331` już istnieje.
Musisz stworzyć container o nazwie `tfstate`:

```bash
az storage container create \
  --name tfstate \
  --account-name tfstatetest331
```

---

## KROK 2 — Stwórz Service Principal (tożsamość dla pipeline'u)

```bash
az ad sp create-for-rbac \
  --name "terraform-aks-sp" \
  --role Contributor \
  --scopes /subscriptions/<TWOJA_SUBSCRIPTION_ID> \
  --sdk-auth
```

Zwróci JSON — zapisz te 4 wartości:
- `clientId`     → AZURE_CLIENT_ID
- `clientSecret` → AZURE_CLIENT_SECRET
- `subscriptionId` → AZURE_SUBSCRIPTION_ID
- `tenantId`     → AZURE_TENANT_ID

---

## KROK 3 — Dodaj Secrets do GitHub

W repo: Settings → Secrets and variables → Actions → New repository secret

Dodaj 4 sekrety:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

---

## KROK 4 — Wrzuć kod do repo i pushuj

```bash
git init
git add .
git commit -m "init terraform aks"
git remote add origin <url-twojego-repo>
git push origin main
```

Pipeline odpali się automatycznie.

---

## Co się dzieje krok po kroku w pipeline

| Krok | Co robi |
|------|---------|
| `terraform init` | Pobiera provider azurerm (~50MB), łączy się z backendem w Blob Storage — tam będzie trzymany plik `terraform.tfstate` |
| `terraform fmt -check` | Sprawdza czy kod jest sformatowany — failuje jeśli nie |
| `terraform validate` | Sprawdza składnię HCL bez łączenia się z Azure |
| `terraform plan` | Loguje się do Azure i oblicza diff: co stworzyć/zmienić/usunąć. Zapisuje plan do pliku `tfplan` |
| `terraform apply` | Wykonuje plan. Tworzy: Resource Group → VNet → Subnet → AKS cluster (~5-8 minut) |
| `kubectl get nodes` | Po apply pobiera kubeconfig i weryfikuje że węzły są `Ready` |

---

## Co Terraform tworzy na Azure

```
Resource Group: aks-learning-rg
└── Virtual Network: aks-vnet (10.0.0.0/16)
    └── Subnet: aks-subnet (10.0.1.0/24)
        └── AKS Cluster: aks-learning-cluster
            ├── Control plane (zarządzany przez Azure, BEZPŁATNY)
            ├── Worker node 1 (Standard_B2s)
            └── Worker node 2 (Standard_B2s)
```

---

## Po apply — ręczne sprawdzenie

```bash
# Pobierz kubeconfig
az aks get-credentials --resource-group aks-learning-rg --name aks-learning-cluster

# Sprawdź węzły
kubectl get nodes

# Sprawdź system pody
kubectl get pods -n kube-system
```

---

## Koszty

| Zasób | Koszt |
|-------|-------|
| Control plane AKS | BEZPŁATNY |
| 2x Standard_B2s | ~$0.08/h (~$58/mies.) |
| VNet, Subnet | bezpłatne |
| Blob Storage (tfstate) | grosze |

**Pamiętaj o zniszczeniu po nauce:**
```bash
terraform destroy
```
