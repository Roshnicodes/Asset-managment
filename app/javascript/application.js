// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const setupVendorRegistrationSelections = () => {
  const themeCheckboxes = Array.from(document.querySelectorAll(".vendor-theme-checkbox"))
  const productCheckboxes = Array.from(document.querySelectorAll(".vendor-product-checkbox"))
  const varietyCheckboxes = Array.from(document.querySelectorAll(".vendor-variety-checkbox"))

  if (themeCheckboxes.length === 0 && productCheckboxes.length === 0 && varietyCheckboxes.length === 0) return

  const syncSelections = () => {
    const selectedThemeIds = new Set(themeCheckboxes.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value))
    const selectedProductIds = new Set()

    productCheckboxes.forEach((checkbox) => {
      const card = checkbox.closest(".vendor-product-card")
      const shouldShow = selectedThemeIds.has(String(checkbox.dataset.themeId))
      card.classList.toggle("is-hidden", !shouldShow)

      if (!shouldShow) checkbox.checked = false
      if (checkbox.checked) selectedProductIds.add(checkbox.value)
    })

    varietyCheckboxes.forEach((checkbox) => {
      const card = checkbox.closest(".vendor-variety-card")
      const shouldShow = selectedProductIds.has(String(checkbox.dataset.productId))
      card.classList.toggle("is-hidden", !shouldShow)

      if (!shouldShow) checkbox.checked = false
    })
  }

  themeCheckboxes.forEach((checkbox) => checkbox.addEventListener("change", syncSelections))
  productCheckboxes.forEach((checkbox) => checkbox.addEventListener("change", syncSelections))
  syncSelections()
}

document.addEventListener("turbo:load", setupVendorRegistrationSelections)
