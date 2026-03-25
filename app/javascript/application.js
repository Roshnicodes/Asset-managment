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
        const fromUserInput = row.querySelector("[data-approval-from-user]")
        
        if (index === 0) {
          if (prevInput) prevInput.value = "NA"
        } else {
          const prevRow = rows[index - 1]
          const prevCurrentActionInput = prevRow.querySelector("[data-approval-current-action]")
          const prevToUserInput = prevRow.querySelector("[data-approval-to-user]")

          if (prevInput && prevCurrentActionInput) {
            prevInput.value = prevCurrentActionInput.value || ""
          }

          // Sync From User with previous step's To User (Chain flow)
          if (fromUserInput && prevToUserInput && prevToUserInput.value && !fromUserInput.value) {
            fromUserInput.value = prevToUserInput.value
          }
        }

        // Action consistency check
        const currentActionSelect = row.querySelector("[data-approval-current-action]")
        if (currentActionSelect && prevInput && currentActionSelect.value === prevInput.value && prevInput.value !== "NA" && prevInput.value !== "") {
          currentActionSelect.style.borderColor = "#d85f52"
          currentActionSelect.style.backgroundColor = "#fff5f4"
        } else if (currentActionSelect) {
          currentActionSelect.style.borderColor = ""
          currentActionSelect.style.backgroundColor = ""
        }
      })
    }

    const handleInput = (event) => {
      if (event.target.closest("[data-approval-current-action]")) {
        renumberAndSyncSteps()
      }
    }

    addButton.addEventListener("click", () => {
      const uniqueKey = `${Date.now()}${Math.floor(Math.random() * 1000)}`
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

const setupVendorApprovalSelections = () => {
  const selectAllCheckbox = document.getElementById("select_all_checkbox");
  const rowCheckboxes = document.querySelectorAll(".row-approval-checkbox");
  const button = document.getElementById("send_for_approval_button");

  if (!button) return;

  const toggleButton = () => {
    const anyChecked = Array.from(rowCheckboxes).some(cb => cb.checked);
    if (anyChecked) {
      button.classList.remove("d-none");
    } else {
      button.classList.add("d-none");
    }
  }

  if (selectAllCheckbox) {
    selectAllCheckbox.addEventListener("change", function() {
      rowCheckboxes.forEach(cb => cb.checked = this.checked);
      toggleButton();
    });
  }

  rowCheckboxes.forEach(cb => {
    cb.addEventListener("change", function() {
      if (!this.checked && selectAllCheckbox) selectAllCheckbox.checked = false;
      
      const allChecked = Array.from(rowCheckboxes).every(cb => cb.checked);
      if (allChecked && selectAllCheckbox) selectAllCheckbox.checked = true;
      
      toggleButton();
    });
  });

  // Initial state check
  toggleButton();
}

const setupQuotationApprovalSelections = () => {
  const selectAllCheckbox = document.getElementById("quotation_select_all_checkbox");
  const rowCheckboxes = document.querySelectorAll(".quotation-approval-checkbox");
  const button = document.getElementById("send_quotation_for_approval_button");

  if (!button) return;

  const toggleButton = () => {
    const anyChecked = Array.from(rowCheckboxes).some(cb => cb.checked);
    button.classList.toggle("d-none", !anyChecked);
  }

  if (selectAllCheckbox) {
    selectAllCheckbox.addEventListener("change", function() {
      rowCheckboxes.forEach(cb => cb.checked = this.checked);
      toggleButton();
    });
  }

  rowCheckboxes.forEach(cb => {
    cb.addEventListener("change", function() {
      if (!this.checked && selectAllCheckbox) selectAllCheckbox.checked = false;
      const allChecked = Array.from(rowCheckboxes).every(box => box.checked);
      if (allChecked && selectAllCheckbox) selectAllCheckbox.checked = true;
      toggleButton();
    });
  });

  toggleButton();
}

const setupQuotationProposalForm = () => {
  const themeSelect = document.getElementById("quotation_proposal_theme_id")
  const vendorDropdown = document.querySelector("[data-quotation-vendor-dropdown]")

  if (themeSelect && vendorDropdown) {
    const trigger = vendorDropdown.querySelector("[data-quotation-vendor-trigger]")
    const label = vendorDropdown.querySelector("[data-quotation-vendor-label]")
    const search = vendorDropdown.querySelector("[data-quotation-vendor-search]")
    const selectedWrap = vendorDropdown.querySelector("[data-quotation-vendor-selected]")
    const vendorOptions = Array.from(vendorDropdown.querySelectorAll("[data-vendor-option]"))

    const updateLabel = () => {
      const selected = vendorOptions.filter((option) => option.querySelector(".quotation-vendor-checkbox")?.checked)
      label.textContent = selected.length > 0 ? `${selected.length} vendor(s) selected` : "Select vendors"

      if (selectedWrap) {
        selectedWrap.innerHTML = ""

        selected.forEach((option) => {
          const checkbox = option.querySelector(".quotation-vendor-checkbox")
          const strong = option.querySelector("strong")
          const chip = document.createElement("button")
          chip.type = "button"
          chip.className = "app-selected-vendor-chip"
          chip.textContent = strong ? strong.textContent : option.innerText.trim()
          chip.addEventListener("click", () => {
            if (checkbox) {
              checkbox.checked = false
              updateLabel()
            }
          })
          selectedWrap.appendChild(chip)
        })
      }
    }

    const syncVendors = () => {
      const selectedThemeId = themeSelect.value
      const query = (search?.value || "").trim().toLowerCase()

      vendorOptions.forEach((option) => {
        const themeIds = (option.dataset.themeIds || "").split(",").filter(Boolean)
        const text = option.innerText.toLowerCase()
        const matchesTheme = selectedThemeId === "" || themeIds.includes(selectedThemeId)
        const matchesSearch = query === "" || text.includes(query)
        const shouldShow = matchesTheme && matchesSearch
        const checkbox = option.querySelector(".quotation-vendor-checkbox")

        option.classList.toggle("is-hidden", !shouldShow)
        if (!matchesTheme && checkbox) checkbox.checked = false
      })

      updateLabel()
    }

    trigger?.addEventListener("click", () => {
      vendorDropdown.classList.toggle("is-open")
    })

    vendorOptions.forEach((option) => {
      const checkbox = option.querySelector(".quotation-vendor-checkbox")
      checkbox?.addEventListener("change", () => {
        updateLabel()
        syncVendors()
      })
    })

    search?.addEventListener("input", syncVendors)
    themeSelect.addEventListener("change", syncVendors)

    document.addEventListener("click", (event) => {
      if (!vendorDropdown.contains(event.target)) {
        vendorDropdown.classList.remove("is-open")
      }
    })

    syncVendors()
  }

  document.querySelectorAll("[data-quotation-items]").forEach((container) => {
    if (container.dataset.ready === "true") return

    const list = container.querySelector("[data-quotation-item-list]")
    const template = container.querySelector("[data-quotation-item-template]")
    const addButton = container.querySelector("[data-add-quotation-item]")
    if (!list || !template || !addButton) return

    addButton.addEventListener("click", () => {
      const uniqueKey = `${Date.now()}-${Math.floor(Math.random() * 1000)}`
      const html = template.innerHTML.replace(/NEW_ITEM/g, uniqueKey)
      list.insertAdjacentHTML("beforeend", html)
    })

    container.addEventListener("click", (event) => {
      const removeButton = event.target.closest("[data-remove-quotation-item]")
      if (!removeButton) return

      const row = removeButton.closest("[data-quotation-item-row]")
      if (!row) return

      const destroyField = row.querySelector("[data-quotation-item-destroy]")
      if (destroyField) {
        destroyField.value = "1"
        row.style.display = "none"
      } else {
        row.remove()
      }
    })

    container.dataset.ready = "true"
  })
}

document.addEventListener("turbo:load", setupVendorRegistrationSelections)
document.addEventListener("turbo:load", setupTableSearch)
document.addEventListener("turbo:load", setupApprovalChannelSteps)
document.addEventListener("turbo:load", setupQuotationProposalForm)
document.addEventListener("turbo:load", setupVendorApprovalSelections)
document.addEventListener("turbo:load", setupQuotationApprovalSelections)
