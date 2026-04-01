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

const setupVendorDocumentToggle = () => {
  const firmTypeInput = document.querySelector("[data-vendor-firm-type]")
  const aadharInput = document.querySelector("[data-aadhar-upload]")
  const aadharWrap = document.querySelector("[data-aadhar-upload-wrap]")
  const proprietorOnlyDocumentWraps = Array.from(document.querySelectorAll("[data-proprietor-only-document]"))

  if (!firmTypeInput) return

  const syncAadharState = () => {
    const isProprietor = firmTypeInput.value.toLowerCase().includes("propriet")

    if (aadharInput) {
      aadharInput.disabled = !isProprietor
      aadharInput.required = false
      if (!isProprietor) aadharInput.value = ""
    }

    if (aadharWrap) {
      aadharWrap.classList.toggle("is-hidden", !isProprietor)
      aadharWrap.hidden = !isProprietor
    }

    proprietorOnlyDocumentWraps.forEach((wrap) => {
      wrap.classList.toggle("is-hidden", !isProprietor)
      wrap.hidden = !isProprietor
      wrap.querySelectorAll("input[type='file']").forEach((input) => {
        input.disabled = !isProprietor
        if (!isProprietor) input.value = ""
      })
    })
  }

  firmTypeInput.addEventListener("input", syncAadharState)
  firmTypeInput.addEventListener("change", syncAadharState)
  syncAadharState()
}

const setupMsmeToggle = () => {
  const msmeSelect = document.querySelector("[data-msme-toggle]")
  const msmeNumberInput = document.querySelector("[data-msme-number]")
  const certificateInput = document.querySelector("[data-msme-certificate]")
  const certificateWrap = document.querySelector("[data-msme-certificate-wrap]")
  const msmeOnlyDocumentWraps = Array.from(document.querySelectorAll("[data-msme-only-document]"))

  if (!msmeSelect || !msmeNumberInput) return

  const syncMsmeState = () => {
    const isMsme = msmeSelect.value === "true"

    msmeNumberInput.disabled = !isMsme
    msmeNumberInput.required = isMsme
    if (!isMsme) msmeNumberInput.value = ""

    if (certificateInput) {
      certificateInput.disabled = !isMsme
      certificateInput.required = isMsme
      if (!isMsme) certificateInput.value = ""
    }

    if (certificateWrap) {
      certificateWrap.classList.toggle("is-hidden", !isMsme)
    }

    msmeOnlyDocumentWraps.forEach((wrap) => {
      wrap.classList.toggle("is-hidden", !isMsme)
      wrap.querySelectorAll("input[type='file']").forEach((input) => {
        input.disabled = !isMsme
        if (!isMsme) input.value = ""
      })
    })
  }

  msmeSelect.addEventListener("change", syncMsmeState)
  syncMsmeState()
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
    const emptyState = vendorDropdown.querySelector("[data-quotation-vendor-empty]")
    const vendorOptions = Array.from(vendorDropdown.querySelectorAll("[data-vendor-option]"))
    const setDropdownOpen = (isOpen) => {
      vendorDropdown.classList.toggle("is-open", isOpen)
      trigger?.setAttribute("aria-expanded", isOpen ? "true" : "false")
    }

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

      const visibleOptions = vendorOptions.filter((option) => !option.classList.contains("is-hidden"))
      emptyState?.classList.toggle("is-hidden", visibleOptions.length > 0)
      updateLabel()
    }

    trigger?.addEventListener("click", () => {
      setDropdownOpen(!vendorDropdown.classList.contains("is-open"))
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
        setDropdownOpen(false)
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

const setupVendorQuotationCalculations = () => {
  const forms = document.querySelectorAll("[data-vendor-quote-calc]")
  if (forms.length === 0) return

  const numberToWords = (value) => {
    const ones = ["zero","one","two","three","four","five","six","seven","eight","nine","ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen"]
    const tens = ["zero","ten","twenty","thirty","forty","fifty","sixty","seventy","eighty","ninety"]

    const toWords = (num) => {
      num = Math.floor(num)
      if (num < 20) return ones[num]
      if (num < 100) return `${tens[Math.floor(num / 10)]} ${ones[num % 10]}`.trim()
      if (num < 1000) return `${ones[Math.floor(num / 100)]} hundred ${num % 100 ? toWords(num % 100) : ""}`.trim()
      if (num < 100000) return `${toWords(Math.floor(num / 1000))} thousand ${num % 1000 ? toWords(num % 1000) : ""}`.trim()
      if (num < 10000000) return `${toWords(Math.floor(num / 100000))} lakh ${num % 100000 ? toWords(num % 100000) : ""}`.trim()
      return `${toWords(Math.floor(num / 10000000))} crore ${num % 10000000 ? toWords(num % 10000000) : ""}`.trim()
    }

    const amount = Number(value || 0)
    const rupees = Math.floor(amount)
    const paise = Math.round((amount - rupees) * 100)
    const paiseWords = paise > 0 ? ` and ${toWords(paise)} paise` : ""
    return `${toWords(rupees)} rupees${paiseWords} only`
  }

  forms.forEach((form) => {
    const rows = Array.from(form.querySelectorAll("[data-vendor-quote-row]"))
    const amountTotalNode = form.querySelector("[data-summary-amount-total]")
    const grandNode = form.querySelector("[data-summary-grand-total]")
    const wordsNode = form.querySelector("[data-summary-grand-words]")

    const recalc = () => {
      let amountTotal = 0
      let grandTotal = 0

      rows.forEach((row) => {
        const quantity = Number(row.querySelector("[data-quote-quantity]")?.textContent || 0)
        const rate = Number(row.querySelector("[data-quote-rate]")?.value || 0)
        const gst = Number(row.querySelector("[data-quote-gst]")?.value || 0)
        const amount = quantity * rate
        const gstAmount = amount * gst / 100
        const total = amount + gstAmount

        const setText = (selector, value) => {
          const node = row.querySelector(selector)
          if (node) node.textContent = value.toFixed(2)
        }

        setText("[data-amount-total]", amount)
        setText("[data-grand-total]", total)

        amountTotal += amount
        grandTotal += total
      })

      if (amountTotalNode) amountTotalNode.textContent = amountTotal.toFixed(2)
      if (grandNode) grandNode.textContent = grandTotal.toFixed(2)
      if (wordsNode) wordsNode.textContent = numberToWords(grandTotal)
    }

    form.addEventListener("input", (event) => {
      if (event.target.matches("[data-quote-rate], [data-quote-gst]")) recalc()
    })

    recalc()
  })
}

document.addEventListener("turbo:load", setupVendorRegistrationSelections)
document.addEventListener("turbo:load", setupVendorDocumentToggle)
document.addEventListener("turbo:load", setupMsmeToggle)
document.addEventListener("turbo:load", setupTableSearch)
document.addEventListener("turbo:load", setupApprovalChannelSteps)
document.addEventListener("turbo:load", setupQuotationProposalForm)
document.addEventListener("turbo:load", setupVendorApprovalSelections)
document.addEventListener("turbo:load", setupQuotationApprovalSelections)
document.addEventListener("turbo:load", setupVendorQuotationCalculations)
