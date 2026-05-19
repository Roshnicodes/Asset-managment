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
    if (tableWrap.dataset.tableSearch === "false") return

    const table = tableWrap.querySelector("table")
    const tbody = tableWrap.querySelector("tbody")
    if (!table || !tbody) return

    const placeholder = tableWrap.dataset.searchPlaceholder || "Search in this table..."
    const searchSlotName = tableWrap.dataset.searchSlot
    const searchSlot = searchSlotName
      ? document.querySelector(`[data-table-search-slot="${searchSlotName}"]`)
      : null
    const existingInput = searchSlot?.querySelector(".app-table-search-input")
    const searchBar = existingInput?.closest(".app-table-search") || document.createElement("div")

    if (!existingInput) {
      searchBar.className = "app-table-search"
      searchBar.innerHTML = `
        <input type="search" class="app-table-search-input" placeholder="${placeholder}">
      `
    }

    const input = searchBar.querySelector("input")
    input.setAttribute("placeholder", placeholder)
    input.addEventListener("input", () => {
      const query = input.value.trim().toLowerCase()

      tbody.querySelectorAll("tr").forEach((row) => {
        const text = row.innerText.toLowerCase()
        row.style.display = text.includes(query) ? "" : "none"
      })
    })

    if (searchSlot) {
      if (!searchSlot.contains(searchBar)) searchSlot.replaceChildren(searchBar)
    } else {
      tableWrap.parentNode.insertBefore(searchBar, tableWrap)
    }

    tableWrap.dataset.searchReady = "true"
  })
}

const normalizeAssetsPage = () => {
  const assetsPage = document.querySelector(".assets-page")
  const assetsTable = document.querySelector(".assets-records-table")
  if (!assetsPage || !assetsTable) return

  assetsPage.classList.add("assets-page--normalized")

  assetsPage.querySelectorAll("h1, h2, h3").forEach((heading) => {
    const text = heading.textContent.trim().replace(/\s+/g, " ")
    if (text === "Assets") {
      const wrapper = heading.closest(".app-page-header, .assets-toolbar-copy, .assets-section-head, .app-toolbar") || heading
      wrapper.style.display = "none"
    }
  })

  assetsPage.querySelectorAll("p").forEach((paragraph) => {
    const text = paragraph.textContent.trim().toLowerCase()
    if (text.includes("maintain asset master records")) {
      paragraph.style.display = "none"
    }
  })
}

const setupTableSorting = () => {
  document.querySelectorAll("table[data-sortable-table='true']").forEach((table) => {
    if (table.dataset.sortReady === "true") return

    const tbody = table.querySelector("tbody")
    const triggers = Array.from(table.querySelectorAll("[data-sort-trigger]"))
    if (!tbody || triggers.length === 0) return

    const normalizeText = (value) => value.toString().replace(/\s+/g, " ").trim().toLowerCase()

    const sortRows = (columnIndex, direction) => {
      const rows = Array.from(tbody.querySelectorAll("tr"))
      const multiplier = direction === "asc" ? 1 : -1

      rows.sort((leftRow, rightRow) => {
        const leftValue = normalizeText(leftRow.cells[columnIndex]?.dataset.sortValue || leftRow.cells[columnIndex]?.innerText || "")
        const rightValue = normalizeText(rightRow.cells[columnIndex]?.dataset.sortValue || rightRow.cells[columnIndex]?.innerText || "")

        return leftValue.localeCompare(rightValue, undefined, { numeric: true, sensitivity: "base" }) * multiplier
      })

      rows.forEach((row) => tbody.appendChild(row))
    }

    triggers.forEach((trigger) => {
      const header = trigger.closest("th")
      if (!header) return

      trigger.addEventListener("click", () => {
        const currentDirection = header.dataset.sortDirection === "asc" ? "asc" : header.dataset.sortDirection === "desc" ? "desc" : "none"
        const nextDirection = currentDirection === "asc" ? "desc" : "asc"
        const columnIndex = Number(trigger.dataset.sortIndex)

        triggers.forEach((item) => {
          const itemHeader = item.closest("th")
          if (itemHeader) itemHeader.dataset.sortDirection = "none"
        })

        header.dataset.sortDirection = nextDirection
        sortRows(columnIndex, nextDirection)
      })
    })

    table.dataset.sortReady = "true"
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
  const quotationForms = document.querySelectorAll("[data-quotation-validation-form]")
  quotationForms.forEach((form) => {
    if (form.dataset.validationReady === "true") return

    const fieldWrapperFor = (input) => input?.closest(".app-form-field")
    const clientErrorFor = (input) => fieldWrapperFor(input)?.querySelector("[data-field-error='true']")
    const validatableSelector = "input[required], input[pattern], input[type='email'], input[min], select[required], textarea[required]"

    const clearFieldError = (input) => {
      const wrapper = fieldWrapperFor(input)
      const errorNode = clientErrorFor(input)
      if (wrapper) wrapper.classList.remove("has-error")
      if (errorNode) {
        errorNode.textContent = ""
        errorNode.classList.remove("is-visible")
      }
    }

    const showFieldError = (input, message) => {
      const wrapper = fieldWrapperFor(input)
      const errorNode = clientErrorFor(input)
      if (wrapper) wrapper.classList.add("has-error")
      if (errorNode) {
        errorNode.textContent = message
        errorNode.classList.add("is-visible")
      }
    }

    const validateField = (input) => {
      if (!input || input.disabled || input.type === "hidden") return true

      clearFieldError(input)

      if (input.checkValidity()) return true

      const label = input.dataset.validationLabel || input.getAttribute("aria-label") || "This field"
      let message = `${label} is invalid.`

      if (input.validity.valueMissing) {
        message = `${label} is required.`
      } else if (input.validity.typeMismatch || input.validity.patternMismatch) {
        message = input.title || `Enter a valid ${label.toLowerCase()}.`
      } else if (input.validity.rangeUnderflow) {
        message = `${label} must be greater than ${input.min}.`
      } else if (input.validationMessage) {
        message = input.validationMessage
      }

      showFieldError(input, message)
      return false
    }

    form.querySelectorAll(validatableSelector).forEach((input) => {
      input.addEventListener("input", () => validateField(input))
      input.addEventListener("change", () => validateField(input))
    })

    const delegatedValidationHandler = (event) => {
      const input = event.target
      if (!(input instanceof HTMLElement)) return
      if (!input.matches(validatableSelector)) return

      validateField(input)
    }

    form.addEventListener("input", delegatedValidationHandler)
    form.addEventListener("change", delegatedValidationHandler)
    form.addEventListener("submit", (event) => {
      let firstInvalidField = null

      form.querySelectorAll(validatableSelector).forEach((input) => {
        if (input.disabled || input.type === "hidden") return

        const isValid = validateField(input)
        if (!isValid && !firstInvalidField) firstInvalidField = input
      })

      if (firstInvalidField) {
        event.preventDefault()
        firstInvalidField.focus()
      }
    })

    form.dataset.validationReady = "true"
  })

  const themeSelect = document.getElementById("quotation_proposal_theme_id")
  const amountBucketSelect = document.getElementById("quotation_proposal_procurement_amount_bucket")
  const vendorDropdown = document.querySelector("[data-quotation-vendor-dropdown]")
  const criteriaSection = document.querySelector("[data-quotation-criteria-section]")

  if (themeSelect && criteriaSection) {
    const criteriaOptions = Array.from(criteriaSection.querySelectorAll("[data-quotation-criteria-option]"))
    const criteriaEmpty = criteriaSection.querySelector("[data-quotation-criteria-empty]")
    const criteriaSummary = criteriaSection.querySelector("[data-quotation-criteria-summary]")
    const criteriaSearch = criteriaSection.querySelector("[data-quotation-criteria-search]")
    const criteriaSelectedPreview = criteriaSection.querySelector("[data-quotation-criteria-selected-preview]")
    const criteriaListWrap = criteriaSection.querySelector("[data-quotation-criteria-list-wrap]")
    const criteriaToggle = criteriaSection.querySelector("[data-quotation-criteria-toggle]")
    let criteriaExpanded = false
    let criteriaToggleTouched = false

    const syncCriteriaOptions = () => {
      const selectedThemeId = themeSelect.value
      const query = (criteriaSearch?.value || "").trim().toLowerCase()
      let themeCount = 0
      let visibleCount = 0
      let selectedCount = 0
      const selectedLabels = []

      criteriaOptions.forEach((option) => {
        const checkbox = option.querySelector("[data-quotation-criteria-checkbox]")
        const labelText = option.querySelector("strong")?.textContent?.trim() || ""
        const matchesTheme = selectedThemeId !== "" && option.dataset.themeId === selectedThemeId
        const matchesQuery = query === "" || labelText.toLowerCase().includes(query)
        const shouldShow = matchesTheme && matchesQuery

        if (matchesTheme) themeCount += 1
        option.classList.toggle("is-hidden", !shouldShow)
        if (!matchesTheme && checkbox) checkbox.checked = false
        if (shouldShow) visibleCount += 1
        if (checkbox?.checked) {
          selectedCount += 1
          if (labelText !== "") selectedLabels.push(labelText)
        }
      })

      if (criteriaEmpty) {
        if (selectedThemeId === "") {
          criteriaEmpty.textContent = "Select a theme to view vendor selection criteria."
          criteriaEmpty.classList.remove("is-hidden")
        } else if (themeCount === 0) {
          criteriaEmpty.textContent = "No vendor selection criteria is configured for this theme."
          criteriaEmpty.classList.remove("is-hidden")
        } else if (visibleCount === 0) {
          criteriaEmpty.textContent = "No criteria matches your search."
          criteriaEmpty.classList.remove("is-hidden")
        } else {
          criteriaEmpty.classList.add("is-hidden")
        }
      }

      if (criteriaSummary) {
        if (selectedThemeId === "") {
          criteriaSummary.textContent = "Choose a theme first to load the matching criteria."
        } else {
          criteriaSummary.textContent = `${selectedCount} selected out of ${themeCount} available criteria.`
        }
      }

      if (criteriaSelectedPreview) {
        if (selectedCount === 0) {
          criteriaSelectedPreview.textContent = "No criteria selected yet. The committee can still use manual scoring if you leave this blank."
        } else {
          const previewLabels = selectedLabels.slice(0, 3)
          const remainingCount = selectedLabels.length - previewLabels.length
          const suffix = remainingCount > 0 ? ` +${remainingCount} more` : ""
          criteriaSelectedPreview.textContent = `Selected: ${previewLabels.join(", ")}${suffix}`
        }
      }

      if (criteriaSearch) {
        criteriaSearch.disabled = selectedThemeId === "" || themeCount === 0
      }

      const hasThemeCriteria = selectedThemeId !== "" && themeCount > 0
      const hasActiveSearch = query !== ""
      const shouldAutoExpand = hasThemeCriteria && themeCount <= 8
      const effectiveExpanded = hasThemeCriteria && (hasActiveSearch || (criteriaToggleTouched ? criteriaExpanded : shouldAutoExpand))

      if (criteriaListWrap) {
        criteriaListWrap.classList.toggle("is-hidden", !hasThemeCriteria)
        criteriaListWrap.classList.toggle("is-collapsed", hasThemeCriteria && !effectiveExpanded)
      }

      if (criteriaToggle) {
        criteriaToggle.disabled = !hasThemeCriteria
        criteriaToggle.classList.toggle("is-hidden", !hasThemeCriteria)
        criteriaToggle.textContent = effectiveExpanded ? "Hide Criteria" : `Show Criteria (${themeCount})`
      }
    }

    criteriaOptions.forEach((option) => {
      option.querySelector("[data-quotation-criteria-checkbox]")?.addEventListener("change", syncCriteriaOptions)
    })

    criteriaToggle?.addEventListener("click", () => {
      criteriaToggleTouched = true
      criteriaExpanded = !criteriaExpanded
      syncCriteriaOptions()
    })

    criteriaSearch?.addEventListener("input", syncCriteriaOptions)
    themeSelect.addEventListener("change", syncCriteriaOptions)
    syncCriteriaOptions()
  }

  if (themeSelect && vendorDropdown) {
    const trigger = vendorDropdown.querySelector("[data-quotation-vendor-trigger]")
    const label = vendorDropdown.querySelector("[data-quotation-vendor-label]")
    const search = vendorDropdown.querySelector("[data-quotation-vendor-search]")
    const selectedWrap = vendorDropdown.querySelector("[data-quotation-vendor-selected]")
    const emptyState = vendorDropdown.querySelector("[data-quotation-vendor-empty]")
    const selectionNote = document.querySelector("[data-vendor-selection-note]")
    const vendorOptions = Array.from(vendorDropdown.querySelectorAll("[data-vendor-option]"))
    const singleVendorMode = () => amountBucketSelect?.value === "below_10k"
    const setDropdownOpen = (isOpen) => {
      vendorDropdown.classList.toggle("is-open", isOpen)
      trigger?.setAttribute("aria-expanded", isOpen ? "true" : "false")
    }

    const updateLabel = () => {
      const selected = vendorOptions.filter((option) => option.querySelector(".quotation-vendor-checkbox")?.checked)
      if (label) label.textContent = selected.length > 0 ? "" : "Select vendors"
      if (selectionNote) {
        selectionNote.textContent = singleVendorMode()
          ? "Only one vendor can be selected for Below 10K quotations."
          : "After you select a theme, only vendors matching the same stakeholder appear here."
      }

      if (selectedWrap) {
        selectedWrap.innerHTML = ""

        selected.forEach((option) => {
          const checkbox = option.querySelector(".quotation-vendor-checkbox")
          const strong = option.querySelector("strong")
          const chip = document.createElement("button")
          chip.type = "button"
          chip.className = "app-selected-vendor-chip"
          chip.textContent = strong ? strong.textContent : option.innerText.trim()
          chip.addEventListener("click", (event) => {
            event.stopPropagation()
            if (checkbox) {
              checkbox.checked = false
              syncVendors()
            }
          })
          selectedWrap.appendChild(chip)
        })
      }
    }

    const syncVendors = () => {
      const selectedThemeId = themeSelect.value
      const selectedThemeOption = themeSelect.options[themeSelect.selectedIndex]
      const selectedStakeholderId = selectedThemeOption?.dataset?.stakeholderId || ""
      const query = (search?.value || "").trim().toLowerCase()
      const selectedCheckboxes = vendorOptions
        .map((option) => option.querySelector(".quotation-vendor-checkbox"))
        .filter((checkbox) => checkbox?.checked)
      const lockedSelection = singleVendorMode() && selectedCheckboxes.length > 0 ? selectedCheckboxes[0].value : null

      vendorOptions.forEach((option) => {
        const themeIds = (option.dataset.themeIds || "").split(",").filter(Boolean)
        const vendorStakeholderId = option.dataset.stakeholderId || ""
        const text = option.innerText.toLowerCase()
        const matchesTheme = selectedThemeId === "" || themeIds.includes(selectedThemeId)
        const matchesStakeholder = selectedStakeholderId === "" || vendorStakeholderId === "" || vendorStakeholderId === selectedStakeholderId
        const matchesSearch = query === "" || text.includes(query)
        const checkbox = option.querySelector(".quotation-vendor-checkbox")
        const isSelected = !!checkbox?.checked
        const shouldShow = matchesTheme && matchesStakeholder && matchesSearch && !isSelected

        option.classList.toggle("is-hidden", !shouldShow)
        if ((!matchesTheme || !matchesStakeholder) && checkbox) checkbox.checked = false
        if (checkbox) {
          checkbox.disabled = !!(singleVendorMode() && lockedSelection && checkbox.value !== lockedSelection)
        }
      })

      const visibleOptions = vendorOptions.filter((option) => !option.classList.contains("is-hidden"))
      if (emptyState) {
        const selectedMatchingOptions = vendorOptions.filter((option) => {
          const checkbox = option.querySelector(".quotation-vendor-checkbox")
          if (!checkbox?.checked) return false

          const themeIds = (option.dataset.themeIds || "").split(",").filter(Boolean)
          const vendorStakeholderId = option.dataset.stakeholderId || ""
          const text = option.innerText.toLowerCase()
          const matchesTheme = selectedThemeId === "" || themeIds.includes(selectedThemeId)
          const matchesStakeholder = selectedStakeholderId === "" || vendorStakeholderId === "" || vendorStakeholderId === selectedStakeholderId
          const matchesSearch = query === "" || text.includes(query)
          return matchesTheme && matchesStakeholder && matchesSearch
        })

        emptyState.textContent = selectedMatchingOptions.length > 0
          ? "All matching vendors are selected."
          : "No vendor matches the selected theme, stakeholder, or search."
        emptyState.classList.toggle("is-hidden", visibleOptions.length > 0)
      }
      updateLabel()
    }

    trigger?.addEventListener("click", () => {
      setDropdownOpen(!vendorDropdown.classList.contains("is-open"))
    })

    trigger?.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return

      event.preventDefault()
      setDropdownOpen(!vendorDropdown.classList.contains("is-open"))
    })

    vendorOptions.forEach((option) => {
      const checkbox = option.querySelector(".quotation-vendor-checkbox")
      checkbox?.addEventListener("change", () => {
        if (singleVendorMode() && checkbox.checked) {
          vendorOptions.forEach((otherOption) => {
            const otherCheckbox = otherOption.querySelector(".quotation-vendor-checkbox")
            if (otherCheckbox && otherCheckbox !== checkbox) otherCheckbox.checked = false
          })
        }
        updateLabel()
        syncVendors()
      })
    })

    search?.addEventListener("input", syncVendors)
    themeSelect.addEventListener("change", syncVendors)
    amountBucketSelect?.addEventListener("change", () => {
      if (singleVendorMode()) {
        let foundChecked = false
        vendorOptions.forEach((option) => {
          const checkbox = option.querySelector(".quotation-vendor-checkbox")
          if (!checkbox?.checked) return
          if (foundChecked) {
            checkbox.checked = false
          } else {
            foundChecked = true
          }
        })
      }
      syncVendors()
    })

    document.addEventListener("click", (event) => {
      if (!vendorDropdown.contains(event.target)) {
        setDropdownOpen(false)
      }
    })

    syncVendors()
  }

  const syncProposalItemOptions = () => {
    const selectedThemeId = themeSelect?.value || ""

    document.querySelectorAll("[data-proposal-item-name]").forEach((selectField) => {
      const currentValue = selectField.value
      let currentValueStillVisible = currentValue === ""

      Array.from(selectField.querySelectorAll("option[data-theme-id]")).forEach((option) => {
        const matchesTheme = selectedThemeId === "" || option.dataset.themeId === selectedThemeId
        option.hidden = !matchesTheme
        option.disabled = !matchesTheme

        if (matchesTheme && option.value === currentValue) currentValueStillVisible = true
      })

      if (!currentValueStillVisible) selectField.value = ""
    })
  }

  document.querySelectorAll("[data-quotation-items]").forEach((container) => {
    if (container.dataset.ready === "true") return

    const list = container.querySelector("[data-quotation-item-list]")
    const template = container.querySelector("[data-quotation-item-template]")
    const addButton = container.querySelector("[data-add-quotation-item]")
    const form = container.closest("[data-quotation-validation-form]")
    const errorNode = container.querySelector("[data-quotation-items-error='true']")
    if (!list || !template || !addButton) return

    const activeRows = () =>
      Array.from(list.querySelectorAll("[data-quotation-item-row]")).filter((row) => {
        const destroyField = row.querySelector("[data-quotation-item-destroy]")
        return !destroyField || destroyField.value !== "1"
      })

    const validateItems = () => {
      const rows = activeRows()
      let isValid = rows.length > 0

      if (errorNode) {
        errorNode.textContent = ""
        errorNode.classList.remove("is-visible")
      }

      rows.forEach((row) => {
        row.querySelectorAll("input[required], input[min], select[required]").forEach((input) => {
          if (!input.checkValidity()) {
            input.dispatchEvent(new Event("change", { bubbles: true }))
            isValid = false
          }
        })
      })

      if (rows.length === 0 && errorNode) {
        errorNode.textContent = "Add at least one proposal item."
        errorNode.classList.add("is-visible")
      }

      return isValid
    }

    addButton.addEventListener("click", () => {
      const uniqueKey = `${Date.now()}-${Math.floor(Math.random() * 1000)}`
      const html = template.innerHTML.replace(/NEW_ITEM/g, uniqueKey)
      list.insertAdjacentHTML("beforeend", html)
      syncProposalItemOptions()
      validateItems()
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

      validateItems()
    })

    form?.addEventListener("submit", (event) => {
      if (!validateItems()) event.preventDefault()
    })

    syncProposalItemOptions()
    container.dataset.ready = "true"
  })

  document.querySelectorAll("[data-quotation-committee]").forEach((container) => {
    if (container.dataset.ready === "true") return

    const list = container.querySelector("[data-quotation-committee-list]")
    const template = container.querySelector("[data-quotation-committee-template]")
    const addButton = container.querySelector("[data-add-committee-step]")
    const minimumMembers = Number(container.dataset.minCommitteeMembers || "2")
    const form = container.closest("[data-quotation-validation-form]")
    if (!list || !template || !addButton) return

    const activeRows = () =>
      Array.from(list.querySelectorAll("[data-quotation-committee-row]")).filter((row) => {
        const destroyField = row.querySelector("[data-committee-destroy]")
        return !destroyField || destroyField.value !== "1"
      })

    const syncCommitteeRows = () => {
      const rows = activeRows()
      const selectedMemberIds = rows
        .map((row) => row.querySelector("[data-committee-member-select]")?.value)
        .filter((value) => value)

      rows.forEach((row, index) => {
        const level = index + 1
        const label = row.querySelector("[data-committee-label]")
        const levelField = row.querySelector("[data-committee-level]")
        const removeButton = row.querySelector("[data-remove-committee-step]")
        const selectField = row.querySelector("[data-committee-member-select]")
        const requiredLevel = level <= 3

        if (label) label.textContent = `Committee Member ${level}`
        if (levelField) levelField.value = level
        if (selectField) {
          selectField.required = requiredLevel
          selectField.dataset.validationLabel = `Committee Member ${level}`
          Array.from(selectField.querySelectorAll("option")).forEach((option) => {
            if (!option.value) return

            const selectedElsewhere = selectedMemberIds.includes(option.value) && option.value !== selectField.value
            option.disabled = selectedElsewhere
            option.hidden = selectedElsewhere
          })
        }
        if (removeButton) removeButton.disabled = requiredLevel || rows.length <= minimumMembers
      })
    }

    const showCommitteeFieldError = (selectField, message) => {
      const wrapper = selectField?.closest(".app-form-field")
      const errorNode = wrapper?.querySelector("[data-field-error='true']")
      if (wrapper) wrapper.classList.add("has-error")
      if (errorNode) {
        errorNode.textContent = message
        errorNode.classList.add("is-visible")
      }
    }

    const clearCommitteeFieldError = (selectField) => {
      const wrapper = selectField?.closest(".app-form-field")
      const errorNode = wrapper?.querySelector("[data-field-error='true']")
      if (wrapper) wrapper.classList.remove("has-error")
      if (errorNode) {
        errorNode.textContent = ""
        errorNode.classList.remove("is-visible")
      }
    }

    const validateCommittee = () => {
      const rows = activeRows()
      let isValid = rows.length >= 3
      const selectedCounts = {}

      rows.forEach((row) => {
        const selectField = row.querySelector("[data-committee-member-select]")
        if (!selectField?.value) return

        selectedCounts[selectField.value] = (selectedCounts[selectField.value] || 0) + 1
      })

      rows.forEach((row, index) => {
        const selectField = row.querySelector("[data-committee-member-select]")

        if (!selectField) {
          isValid = false
          return
        }

        if (!selectField.value && index < 3) {
          showCommitteeFieldError(selectField, `Committee Member ${index + 1} is required.`)
          isValid = false
        } else if (selectedCounts[selectField.value] > 1) {
          showCommitteeFieldError(selectField, "Committee member must be unique.")
          isValid = false
        } else {
          clearCommitteeFieldError(selectField)
        }
      })

      return isValid
    }

    addButton.addEventListener("click", () => {
      const uniqueKey = `${Date.now()}-${Math.floor(Math.random() * 1000)}`
      const html = template.innerHTML.replace(/NEW_COMMITTEE_STEP/g, uniqueKey)
      list.insertAdjacentHTML("beforeend", html)
      syncCommitteeRows()
      validateCommittee()
    })

    container.addEventListener("click", (event) => {
      const removeButton = event.target.closest("[data-remove-committee-step]")
      if (!removeButton) return

      if (removeButton.disabled || activeRows().length <= minimumMembers) return

      const row = removeButton.closest("[data-quotation-committee-row]")
      if (!row) return

      const destroyField = row.querySelector("[data-committee-destroy]")
      if (destroyField) {
        destroyField.value = "1"
        row.style.display = "none"
      } else {
        row.remove()
      }

      syncCommitteeRows()
      validateCommittee()
    })

    container.addEventListener("change", (event) => {
      if (!event.target.matches("[data-committee-member-select]")) return
      syncCommitteeRows()
      validateCommittee()
    })

    form?.addEventListener("submit", (event) => {
      if (!validateCommittee()) event.preventDefault()
    })

    syncCommitteeRows()
    container.dataset.ready = "true"
  })

  if (vendorDropdown) {
    const form = vendorDropdown.closest("[data-quotation-validation-form]")
    const errorNode = form?.querySelector("[data-vendor-selection-error='true']")
    const fieldWrapper = form?.querySelector("[data-vendor-selection-field]")
    const vendorCheckboxes = Array.from(vendorDropdown.querySelectorAll(".quotation-vendor-checkbox"))

    const validateVendorSelection = () => {
      const hasSelectedVendor = vendorCheckboxes.some((checkbox) => checkbox.checked)
      if (fieldWrapper) fieldWrapper.classList.toggle("has-error", !hasSelectedVendor)
      if (errorNode) {
        errorNode.textContent = hasSelectedVendor ? "" : "Select at least one vendor."
        errorNode.classList.toggle("is-visible", !hasSelectedVendor)
      }
      return hasSelectedVendor
    }

    vendorCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", validateVendorSelection)
    })

    form?.addEventListener("submit", (event) => {
      if (!validateVendorSelection()) event.preventDefault()
    })
  }

  themeSelect?.addEventListener("change", syncProposalItemOptions)
  syncProposalItemOptions()
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

const setupAssetProductCodeAutofill = () => {
  document.querySelectorAll("[data-asset-product-code-map]").forEach((container) => {
    if (container.dataset.assetProductCodeReady === "true") return

    let productCodeMap = {}

    try {
      productCodeMap = JSON.parse(container.dataset.assetProductCodeMap || "{}")
    } catch (error) {
      productCodeMap = {}
    }

    const rows = Array.from(container.querySelectorAll("[data-asset-product-code-row]"))
    const scopedRows = rows.length > 0 ? rows : [container]

    const syncItemCode = (row) => {
      const productSelect = row.querySelector("[data-asset-product-select]")
      const itemCodeInput = row.querySelector("[data-asset-item-code]")
      if (!productSelect || !itemCodeInput) return

      const selectedCode = productCodeMap[productSelect.value] || ""
      const previousAutofilledCode = itemCodeInput.dataset.autofilledCode || ""
      const currentValue = itemCodeInput.value.trim()
      const shouldAutofill = currentValue === "" || currentValue === previousAutofilledCode

      if (shouldAutofill) itemCodeInput.value = selectedCode
      itemCodeInput.dataset.autofilledCode = selectedCode
    }

    scopedRows.forEach((row) => {
      const productSelect = row.querySelector("[data-asset-product-select]")
      if (!productSelect) return

      productSelect.addEventListener("change", () => syncItemCode(row))
      syncItemCode(row)
    })

    container.dataset.assetProductCodeReady = "true"
  })
}

const setupAssetInsuranceFields = () => {
  document.querySelectorAll("[data-asset-insurance-card]").forEach((card) => {
    if (card.dataset.assetInsuranceReady === "true") return

    const statusSelect = card.querySelector("[data-insurance-status-select]")
    const extraFields = card.querySelector("[data-insurance-extra-fields]")
    if (!statusSelect || !extraFields) return

    const syncInsuranceFields = () => {
      const showInsuranceFields = statusSelect.value === "true"

      extraFields.classList.toggle("is-hidden", !showInsuranceFields)
      extraFields.hidden = !showInsuranceFields
      extraFields.querySelectorAll("input").forEach((input) => {
        input.disabled = !showInsuranceFields
      })
    }

    statusSelect.addEventListener("change", syncInsuranceFields)
    syncInsuranceFields()
    card.dataset.assetInsuranceReady = "true"
  })
}

const setupFinanceQueueBulkSelection = () => {
  document.querySelectorAll("[data-finance-bulk-form]").forEach((form) => {
    if (form.dataset.financeBulkReady === "true") return

    const selectAllCheckbox = form.querySelector("[data-finance-select-all]")
    const rowCheckboxes = Array.from(form.querySelectorAll("[data-finance-row-checkbox]"))
    const selectedCount = form.querySelector("[data-finance-selected-count]")
    if (rowCheckboxes.length === 0) return

    const syncSelectionState = () => {
      const checkedCount = rowCheckboxes.filter((checkbox) => checkbox.checked).length

      if (selectedCount) selectedCount.textContent = checkedCount.toString()
      if (!selectAllCheckbox) return

      selectAllCheckbox.checked = checkedCount === rowCheckboxes.length
      selectAllCheckbox.indeterminate = checkedCount > 0 && checkedCount < rowCheckboxes.length
    }

    selectAllCheckbox?.addEventListener("change", () => {
      rowCheckboxes.forEach((checkbox) => {
        checkbox.checked = selectAllCheckbox.checked
      })
      syncSelectionState()
    })

    rowCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", syncSelectionState)
    })

    syncSelectionState()
    form.dataset.financeBulkReady = "true"
  })
}

const passwordVisibilityIcon = (visible) => {
  if (visible) {
    return `
      <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <path d="M3 3l18 18" />
        <path d="M10.6 10.6a2 2 0 0 0 2.8 2.8" />
        <path d="M9.9 4.2A9.8 9.8 0 0 1 12 4c5 0 8.5 4.4 9.7 6.3a3.2 3.2 0 0 1 0 3.4 17 17 0 0 1-2 2.6" />
        <path d="M6.2 6.2a17 17 0 0 0-3.9 4.1 3.2 3.2 0 0 0 0 3.4C3.5 15.6 7 20 12 20a9.7 9.7 0 0 0 4.5-1.2" />
      </svg>
    `
  }

  return `
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path d="M2.3 10.3a3.2 3.2 0 0 0 0 3.4C3.5 15.6 7 20 12 20s8.5-4.4 9.7-6.3a3.2 3.2 0 0 0 0-3.4C20.5 8.4 17 4 12 4s-8.5 4.4-9.7 6.3Z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  `
}

const setupPasswordVisibility = () => {
  document.querySelectorAll("input[type='password']").forEach((input) => {
    if (input.dataset.passwordVisibilityReady === "true") return

    const wrapper = document.createElement("div")
    wrapper.className = "password-visibility-wrapper"
    input.parentNode.insertBefore(wrapper, input)
    wrapper.appendChild(input)

    input.classList.add("password-visibility-input")
    input.dataset.passwordVisibilityReady = "true"

    const toggle = document.createElement("button")
    toggle.type = "button"
    toggle.className = "password-visibility-toggle"
    toggle.setAttribute("aria-label", "Show password")
    toggle.setAttribute("title", "Show password")
    toggle.innerHTML = passwordVisibilityIcon(false)

    toggle.addEventListener("click", () => {
      const visible = input.type === "text"
      input.type = visible ? "password" : "text"
      toggle.setAttribute("aria-label", visible ? "Show password" : "Hide password")
      toggle.setAttribute("title", visible ? "Show password" : "Hide password")
      toggle.innerHTML = passwordVisibilityIcon(!visible)
    })

    wrapper.appendChild(toggle)
  })
}

document.addEventListener("turbo:load", setupVendorRegistrationSelections)
document.addEventListener("turbo:load", setupVendorDocumentToggle)
document.addEventListener("turbo:load", setupMsmeToggle)
document.addEventListener("turbo:load", normalizeAssetsPage)
document.addEventListener("turbo:load", setupTableSearch)
document.addEventListener("turbo:load", setupTableSorting)
document.addEventListener("turbo:load", setupApprovalChannelSteps)
document.addEventListener("turbo:load", setupQuotationProposalForm)
document.addEventListener("turbo:load", setupVendorApprovalSelections)
document.addEventListener("turbo:load", setupQuotationApprovalSelections)
document.addEventListener("turbo:load", setupVendorQuotationCalculations)
document.addEventListener("turbo:load", setupAssetProductCodeAutofill)
document.addEventListener("turbo:load", setupAssetInsuranceFields)
document.addEventListener("turbo:load", setupFinanceQueueBulkSelection)
document.addEventListener("turbo:load", setupPasswordVisibility)
