output "app_name" {
  value = azurerm_linux_web_app.app.name
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}
