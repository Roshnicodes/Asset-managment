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

const setupTableSearch = () => {
  document.querySelectorAll(".app-table-wrap").forEach((tableWrap, index) => {
    if (tableWrap.dataset.searchReady === "true") return

    const table = tableWrap.querySelector("table")
    const tbody = tableWrap.querySelector("tbody")
    if (!table || !tbody) return

    const searchBar = document.createElement("div")
    searchBar.className = "app-table-search"
    searchBar.innerHTML = `
      <input type="search" class="app-table-search-input" placeholder="Search in this table...">
    `

    const input = searchBar.querySelector("input")
    input.addEventListener("input", () => {
      const query = input.value.trim().toLowerCase()

      tbody.querySelectorAll("tr").forEach((row) => {
        const text = row.innerText.toLowerCase()
        row.style.display = text.includes(query) ? "" : "none"
      })
    })

    tableWrap.parentNode.insertBefore(searchBar, tableWrap)
    tableWrap.dataset.searchReady = "true"
  })
}

const setupApprovalChannelSteps = () => {
  document.querySelectorAll("[data-approval-steps]").forEach((container) => {
    if (container.dataset.ready === "true") return

    const list = container.querySelector("[data-approval-step-list]")
    const template = container.querySelector("[data-approval-step-template]")
    const addButton = container.querySelector("[data-add-approval-step]")
    if (!list || !template || !addButton) return

    const renumberAndSyncSteps = () => {
      const rows = Array.from(list.querySelectorAll("[data-approval-step-row]")).filter(row => {
        const destroyField = row.querySelector("[data-approval-step-destroy]")
        return !destroyField || destroyField.value !== "1"
      })

      rows.forEach((row, index) => {
        const stepInput = row.querySelector("[data-approval-step-number]")
        if (stepInput) stepInput.value = index + 1

        const prevInput = row.querySelector("[data-approval-previous-action]")
        if (index === 0) {
          if (prevInput) prevInput.value = "NA"
        } else {
          const prevRow = rows[index - 1]
          const prevCurrentActionInput = prevRow.querySelector("[data-approval-current-action]")
          if (prevInput && prevCurrentActionInput) {
            prevInput.value = prevCurrentActionInput.value || ""
          }
        }
      })
    }

    const handleInput = (event) => {
      if (event.target.closest("[data-approval-current-action]")) {
        renumberAndSyncSteps()
      }
    }

    addButton.addEventListener("click", () => {
      const uniqueKey = `${Date.now()}-${Math.floor(Math.random() * 1000)}`
      const html = template.innerHTML.replace(/NEW_RECORD/g, uniqueKey)
      list.insertAdjacentHTML("beforeend", html)
      renumberAndSyncSteps()
    })

    container.addEventListener("click", (event) => {
      const removeButton = event.target.closest("[data-remove-approval-step]")
      if (!removeButton) return

      const row = removeButton.closest("[data-approval-step-row]")
      if (!row) return

      const destroyField = row.querySelector("[data-approval-step-destroy]")
      if (destroyField) {
        destroyField.value = "1"
        row.style.display = "none"
      } else {
        row.remove()
      }
      renumberAndSyncSteps()
    })

    container.addEventListener("input", handleInput)
    container.addEventListener("change", handleInput)

    renumberAndSyncSteps()
    container.dataset.ready = "true"
  })
}

document.addEventListener("turbo:load", setupVendorRegistrationSelections)
document.addEventListener("turbo:load", setupTableSearch)
document.addEventListener("turbo:load", setupApprovalChannelSteps)
