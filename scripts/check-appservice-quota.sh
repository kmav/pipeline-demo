#!/usr/bin/env bash
# Finds Azure regions where this subscription can create a Linux App Service plan (F1 free / B1 basic).
# Creates a tiny test plan, prints OK/NO, deletes it again. Run on your Mac after 'az login'.
RG=rg-quota-test
az group create -n $RG -l northeurope -o none
for region in northeurope swedencentral germanywestcentral francecentral uksouth westeurope italynorth polandcentral; do
  for sku in F1 B1; do
    name="plan-qt-${region}-$(echo $sku | tr A-Z a-z)"
    if az appservice plan create -g $RG -n "$name" -l "$region" --sku "$sku" --is-linux -o none 2>/dev/null; then
      echo "OK  $region $sku"
      az appservice plan delete -g $RG -n "$name" --yes -o none
    else
      echo "NO  $region $sku"
    fi
  done
done
az group delete -n $RG --yes --no-wait
