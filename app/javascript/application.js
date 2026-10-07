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

const escapeAttribute = (value) =>
  String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character])

const setupTableSearch = () => {
  document.querySelectorAll(".app-table-wrap").forEach((tableWrap, index) => {
    if (tableWrap.dataset.tableSearch === "false") return
    const serverSearch = tableWrap.dataset.serverSearch === "true"
    if (tableWrap.dataset.searchReady === "true" && !serverSearch) return

    const table = tableWrap.querySelector("table")
    const tbody = tableWrap.querySelector("tbody")
    if (!table || !tbody) return

    const placeholder = tableWrap.dataset.searchPlaceholder || "Search in this table..."
    const searchSlotName = tableWrap.dataset.searchSlot
    const searchSlot = searchSlotName
      ? document.querySelector(`[data-table-search-slot="${searchSlotName}"]`)
      : null
    const existingInput = searchSlot?.querySelector(".app-table-search-input")
    let searchBar = existingInput?.closest(".app-table-search")

    if (!searchBar || (serverSearch && searchBar.tagName !== "FORM")) {
      searchBar = document.createElement(serverSearch ? "form" : "div")
      searchBar.className = "app-table-search"
    }

    if (serverSearch) {
      const urlParams = new URLSearchParams(window.location.search)
      const preservedFields = Array.from(urlParams.entries())
        .filter(([key]) => key !== "page" && key !== "q")
        .map(([key, value]) => `<input type="hidden" name="${escapeAttribute(key)}" value="${escapeAttribute(value)}">`)
        .join("")

      searchBar.setAttribute("method", "get")
      searchBar.setAttribute("action", window.location.pathname)
      searchBar.innerHTML = `
        ${preservedFields}
        <input type="search" name="q" class="app-table-search-input" placeholder="${escapeAttribute(placeholder)}" value="${escapeAttribute(urlParams.get("q") || "")}">
        <button type="submit" class="app-form-submit app-table-search-btn">Search</button>
      `
    } else if (!existingInput) {
      searchBar.innerHTML = `
        <input type="search" class="app-table-search-input" placeholder="${placeholder}">
      `
    }

    const input = searchBar.querySelector(".app-table-search-input")
    input.setAttribute("placeholder", placeholder)
    if (serverSearch) {
      if (searchSlot) {
        if (!searchSlot.contains(searchBar)) searchSlot.replaceChildren(searchBar)
      } else {
        tableWrap.parentNode.insertBefore(searchBar, tableWrap)
      }

      tableWrap.dataset.searchReady = "true"
      return
    }

    input.addEventListener("input", () => {
      const query = input.value.trim().toLowerCase()

      tbody.querySelectorAll("tr").forEach((row) => {
        const text = row.innerText.toLowerCase()
        row.dataset.searchHidden = text.includes(query) ? "false" : "true"
        if (tableWrap.dataset.paginationReady !== "true") {
          row.style.display = row.dataset.searchHidden === "true" ? "none" : ""
        }
      })

      tableWrap.dispatchEvent(new CustomEvent("app:table-filtered"))
    })

    if (searchSlot) {
      if (!searchSlot.contains(searchBar)) searchSlot.replaceChildren(searchBar)
    } else {
      tableWrap.parentNode.insertBefore(searchBar, tableWrap)
    }

    tableWrap.dataset.searchReady = "true"
  })
}

const setupTablePagination = () => {
  document.querySelectorAll(".app-table-wrap").forEach((tableWrap) => {
    if (tableWrap.dataset.paginationReady === "true") return
    if (tableWrap.dataset.tablePagination === "false") return
    if (tableWrap.dataset.serverSearch === "true") return

    const table = tableWrap.querySelector("table")
    const tbody = tableWrap.querySelector("tbody")
    if (!table || !tbody) return
    if (tableWrap.querySelector("input[required], select[required], textarea[required]")) return

    const rows = Array.from(tbody.querySelectorAll("tr"))
    const pageSize = Number(tableWrap.dataset.pageSize || 10)
    if (rows.length <= pageSize) return

    let currentPage = 1
    const controls = document.createElement("div")
    controls.className = "app-table-pagination"
    controls.innerHTML = `
      <div class="app-table-pagination-info" data-pagination-info></div>
      <div class="app-table-pagination-actions">
        <button type="button" class="app-pagination-btn" data-pagination-prev>Previous</button>
        <span class="app-pagination-pages" data-pagination-pages></span>
        <button type="button" class="app-pagination-btn" data-pagination-next>Next</button>
      </div>
    `

    const info = controls.querySelector("[data-pagination-info]")
    const pagesNode = controls.querySelector("[data-pagination-pages]")
    const prevButton = controls.querySelector("[data-pagination-prev]")
    const nextButton = controls.querySelector("[data-pagination-next]")

    tableWrap.insertAdjacentElement("afterend", controls)

    const visibleRows = () => rows.filter((row) => row.dataset.searchHidden !== "true")

    const render = () => {
      const filteredRows = visibleRows()
      const totalPages = Math.max(1, Math.ceil(filteredRows.length / pageSize))
      currentPage = Math.min(currentPage, totalPages)

      const start = (currentPage - 1) * pageSize
      const end = start + pageSize
      const visibleSet = new Set(filteredRows.slice(start, end))

      rows.forEach((row) => {
        row.style.display = visibleSet.has(row) ? "" : "none"
      })

      if (info) {
        if (filteredRows.length === 0) {
          info.textContent = "No records found"
        } else {
          info.textContent = `Showing ${start + 1}-${Math.min(end, filteredRows.length)} of ${filteredRows.length}`
        }
      }

      if (pagesNode) pagesNode.textContent = `Page ${currentPage} of ${totalPages}`
      if (prevButton) prevButton.disabled = currentPage <= 1
      if (nextButton) nextButton.disabled = currentPage >= totalPages
    }

    prevButton?.addEventListener("click", () => {
      currentPage -= 1
      render()
    })

    nextButton?.addEventListener("click", () => {
      currentPage += 1
      render()
    })

    tableWrap.addEventListener("app:table-filtered", () => {
      currentPage = 1
      render()
    })

    render()
    tableWrap.dataset.paginationReady = "true"
  })
}

// Extra checks a step must pass that plain HTML validation cannot express
// (vendor count, committee member). Each runs only for the step holding it.
const registerStepValidator = (form, element, validate) => {
  if (!form || !element) return
  form.appStepValidators ||= []
  form.appStepValidators.push({ element, validate })
}

// Step guard for the radio-driven paged forms (Vendor Registration, Request
// for Proposal): "Next" only moves on when the current step is valid, and a
// submit jumps back to the first step that still has an error.
const setupStaticPagerValidation = () => {
  document.querySelectorAll("form").forEach((form) => {
    if (form.dataset.stepGuardReady === "true") return
    const toggles = Array.from(form.querySelectorAll(".app-static-page-toggle"))
    const pages = Array.from(form.querySelectorAll(".app-static-page"))
    if (toggles.length < 2 || toggles.length !== pages.length) return
    form.dataset.stepGuardReady = "true"

    const fieldSelector = "input:not([type='hidden']):not([type='radio'].app-static-page-toggle), select, textarea"
    const isShown = (element) => !element.closest("[hidden], template") && element.type !== "hidden"
    const wordCount = (value) => (value.match(/\b[\w]+\b/g) || []).length

    const errorNodeFor = (field) => field.closest(".app-form-field")?.querySelector("[data-field-error='true']")

    const messageFor = (field) => {
      const label = field.dataset.validationLabel || field.getAttribute("aria-label") ||
        field.closest(".app-form-field")?.querySelector("label")?.textContent?.trim() || "This field"
      const value = (field.value || "").trim()
      const minWords = parseInt(field.dataset.minWords || "0", 10)
      const maxWords = parseInt(field.dataset.maxWords || "0", 10)

      if (field.validity && !field.validity.valid) {
        if (field.validity.valueMissing) return field.type === "file" ? `${label} must be uploaded.` : `${label} is required.`
        if (field.validity.customError) return field.validationMessage
        if (field.validity.typeMismatch || field.validity.patternMismatch) return field.title || `Enter a valid ${label.toLowerCase()}.`
        if (field.validity.rangeUnderflow) return `${label} must be at least ${field.min}.`
        if (field.validity.tooShort) return `${label} must be at least ${field.minLength} characters.`
        return field.validationMessage || `${label} is invalid.`
      }
      if (minWords > 0 && value && wordCount(value) < minWords) return `${label} must be at least ${minWords} words.`
      if (maxWords > 0 && value && wordCount(value) > maxWords) return `${label} must not exceed ${maxWords} words.`
      return ""
    }

    const showError = (field, message) => {
      const wrapper = field.closest(".app-form-field")
      const node = errorNodeFor(field)
      wrapper?.classList.add("has-error")
      if (node) {
        node.textContent = message
        node.classList.add("is-visible")
      }
    }

    // Returns the first field that fails, after marking every failing field.
    const validatePage = (page) => {
      let firstInvalid = null
      page.querySelectorAll(fieldSelector).forEach((field) => {
        if (field.disabled || !isShown(field)) return
        const message = messageFor(field)
        if (!message) return
        showError(field, message)
        firstInvalid ||= field
      })

      // Checkbox groups (e.g. Theme / Product) need at least one choice.
      page.querySelectorAll("[data-checkbox-group='true']").forEach((group) => {
        if (!isShown(group)) return
        const boxes = Array.from(group.querySelectorAll("input[type='checkbox']"))
        if (boxes.length === 0 || boxes.some((box) => box.checked)) return
        const node = group.querySelector("[data-field-error='true']")
        group.classList.add("has-error")
        if (node) {
          node.textContent = `Select at least one ${(group.dataset.checkboxGroupLabel || "option").toLowerCase()}.`
          node.classList.add("is-visible")
        }
        firstInvalid ||= boxes[0]
      })

      ;(form.appStepValidators || []).forEach(({ element, validate }) => {
        if (!page.contains(element) || !isShown(element)) return
        if (validate() === false) firstInvalid ||= element.querySelector(fieldSelector) || element
      })
      return firstInvalid
    }

    // Visual stepper built from the existing "Step N of M - Title" labels. Each
    // step is a <label for=…>, so moving forward through it is guarded too.
    const stepTitles = pages.map((_, index) => {
      const row = Array.from(form.querySelectorAll(".app-static-pager-status"))[index]
      const text = row?.textContent?.trim() || ""
      return text.includes(" - ") ? text.split(" - ").slice(1).join(" - ") : `Step ${index + 1}`
    })
    const stepper = document.createElement("ol")
    stepper.className = "app-form-stepper"
    stepper.setAttribute("aria-label", "Form steps")
    stepper.innerHTML = stepTitles.map((title, index) => `
      <li class="app-form-stepper__item">
        <label for="${toggles[index].id}" class="app-form-stepper__step">
          <span class="app-form-stepper__dot">${index + 1}</span>
          <span class="app-form-stepper__title">${title.replace(/[<>&]/g, "")}</span>
        </label>
      </li>`).join("")
    pages[0].parentNode.insertBefore(stepper, pages[0])

    const syncStepper = () => {
      const active = toggles.findIndex((toggle) => toggle.checked)
      stepper.querySelectorAll(".app-form-stepper__item").forEach((item, index) => {
        item.classList.toggle("is-active", index === active)
        item.classList.toggle("is-done", index < active)
        // Narrow screens scroll the stepper: keep the current step in view.
        if (index === active && stepper.scrollWidth > stepper.clientWidth) {
          stepper.scrollLeft = item.offsetLeft - (stepper.clientWidth - item.offsetWidth) / 2
        }
      })
    }
    toggles.forEach((toggle) => toggle.addEventListener("change", syncStepper))
    syncStepper()

    // The submit button of the last step goes into the bottom bar, next to Previous.
    const lastRowActions = Array.from(form.querySelectorAll(".app-static-pager-row"))[pages.length - 1]?.querySelector(".app-static-pager-actions")
    const submitActions = pages[pages.length - 1].querySelector(":scope > .app-form-actions")
    if (lastRowActions && submitActions) {
      Array.from(submitActions.children).forEach((child) => lastRowActions.appendChild(child))
      submitActions.remove()
    }
    enhancePagedFormFields(form)

    const currentIndex = () => toggles.findIndex((toggle) => toggle.checked)
    const goTo = (index) => {
      toggles[index].checked = true
      toggles[index].dispatchEvent(new Event("change", { bubbles: true }))
    }
    const focusInvalid = (element) => {
      element.scrollIntoView({ block: "center", behavior: "smooth" })
      if (typeof element.focus === "function") element.focus({ preventScroll: true })
    }

    // Clear a step-guard message as soon as the field is corrected.
    form.addEventListener("input", (event) => clearIfValid(event.target))
    form.addEventListener("change", (event) => clearIfValid(event.target))
    function clearIfValid(field) {
      if (!(field instanceof HTMLElement)) return
      const group = field.closest("[data-checkbox-group='true']")
      if (group) {
        if (Array.from(group.querySelectorAll("input[type='checkbox']")).some((box) => box.checked)) {
          group.classList.remove("has-error")
          group.querySelector("[data-field-error='true']")?.classList.remove("is-visible")
        }
        return
      }
      if (!field.matches?.(fieldSelector) || messageFor(field)) return
      field.closest(".app-form-field")?.classList.remove("has-error")
      const node = errorNodeFor(field)
      if (node) {
        node.textContent = ""
        node.classList.remove("is-visible")
      }
    }

    form.addEventListener("click", (event) => {
      // Only a real user click moves between steps through this guard.
      if (!event.isTrusted) return
      const label = event.target.closest("label[for]")
      if (!label) return
      const target = toggles.findIndex((toggle) => toggle.id === label.htmlFor)
      const current = currentIndex()
      if (target < 0 || current < 0 || target <= current) return

      for (let index = current; index < target; index += 1) {
        const invalid = validatePage(pages[index])
        if (invalid) {
          event.preventDefault()
          if (index !== current) goTo(index)
          focusInvalid(invalid)
          return
        }
      }
    }, true)

    form.addEventListener("submit", (event) => {
      for (let index = 0; index < pages.length; index += 1) {
        const invalid = validatePage(pages[index])
        if (invalid) {
          event.preventDefault()
          event.stopImmediatePropagation()
          goTo(index)
          focusInvalid(invalid)
          return
        }
      }
    }, true)
  })
}

// Icons shown in front of form fields, picked from the field's name.
const FIELD_ICONS = {
  mail: '<path d="M4 6h16v12H4z"/><path d="m4 7 8 6 8-6"/>',
  phone: '<path d="M6.6 10.8a15 15 0 0 0 6.6 6.6l2.2-2.2a1 1 0 0 1 1-.25 11.4 11.4 0 0 0 3.6.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1 11.4 11.4 0 0 0 .57 3.6 1 1 0 0 1-.25 1z"/>',
  document: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h6"/>',
  pin: '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
  map: '<path d="m3 6 6-2 6 2 6-2v14l-6 2-6-2-6 2z"/><path d="M9 4v14M15 6v14"/>',
  hash: '<path d="M5 9h14M5 15h14M10 3 8 21M16 3l-2 18"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/>',
  message: '<path d="M4 5h16v11H8l-4 4z"/>',
  grid: '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/>',
  rupee: '<path d="M7 5h10M7 9h10M14 5c2.5 0 3 4 0 4H8l7 10"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  bank: '<path d="m3 10 9-6 9 6M5 10v8M9 10v8M15 10v8M19 10v8M3 20h18"/>',
  building: '<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2"/>'
}

const fieldIconFor = (control, labelText) => {
  // Use the attribute part of "model[attribute]" so the model name does not decide the icon.
  const attribute = (control.name || "").match(/\[([^\]]+)\](?:\[\])?$/)?.[1] || control.name || ""
  const key = `${attribute} ${labelText}`.toLowerCase()
  const rules = [
    [/email/, "mail"], [/mobile|phone/, "phone"], [/thematic[ _]head|search/, "search"],
    [/date/, "calendar"], [/pin_no|pin code|pincode/, "hash"], [/address/, "pin"],
    [/state|district|block/, "map"], [/ifsc|account/, "hash"], [/bank/, "bank"],
    [/gst|pan|registration|document|msme/, "document"], [/designation/, "briefcase"],
    [/subject/, "document"], [/remark|description|profile|note/, "message"],
    [/theme|stakeholder|category/, "grid"], [/bucket|value|amount|rate/, "rupee"],
    [/firm_type|firm type/, "building"], [/firm|company/, "building"], [/name|person/, "user"]
  ]
  const match = rules.find(([pattern]) => pattern.test(key))
  return match ? match[1] : null
}

// Visual polish for the paged forms: an icon in front of each field, a red
// mark on required labels and a word counter where a word limit applies.
// Fields inside the item / committee tables are left as they are.
const enhancePagedFormFields = (form) => {
  if (form.dataset.fieldsEnhanced === "true") return
  form.dataset.fieldsEnhanced = "true"

  form.querySelectorAll(".app-form-field").forEach((field) => {
    if (field.closest("table:not(.app-rfp-form-table)")) return
    const control = Array.from(field.querySelectorAll("input, select, textarea")).find((element) => {
      if (element.closest(".app-field-icon, .app-multiselect-dropdown, [data-logic-note-help]")) return false
      if (element.tagName === "INPUT" && /^(hidden|checkbox|radio|file|submit|button)$/.test(element.type)) return false
      return true
    })
    if (!control) return

    const label = field.querySelector("label:not(.visually-hidden)") || field.closest("tr")?.querySelector("th")
    const labelText = label?.textContent?.trim() || ""
    if (control.required && label && !label.classList.contains("is-required")) label.classList.add("is-required")

    const icon = fieldIconFor(control, labelText)
    if (icon && control.tagName !== "TEXTAREA") {
      const wrapper = document.createElement("div")
      wrapper.className = "app-field-icon"
      wrapper.innerHTML = `<span class="app-field-icon__icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${FIELD_ICONS[icon]}</svg></span>`
      control.parentNode.insertBefore(wrapper, control)
      wrapper.appendChild(control)
    }

    const maxWords = parseInt(control.dataset.maxWords || "0", 10)
    if (maxWords > 0 && !field.querySelector("[data-word-counter]")) {
      const counter = document.createElement("span")
      counter.className = "app-word-counter"
      counter.dataset.wordCounter = "true"
      const update = () => {
        const count = (control.value.match(/\b[\w]+\b/g) || []).length
        counter.textContent = `${count}/${maxWords} words`
        counter.classList.toggle("is-over", count > maxWords)
      }
      const anchor = control.closest(".app-field-icon") || control
      anchor.insertAdjacentElement("afterend", counter)
      control.addEventListener("input", update)
      update()
    }
  })

  // "Step 1 of 5 - Quotation Details" -> two lines
  form.querySelectorAll(".app-static-pager-status").forEach((status) => {
    if (status.dataset.split === "true") return
    const [step, ...rest] = status.textContent.trim().split(" - ")
    status.dataset.split = "true"
    status.innerHTML = `<strong>${step.replace(/[<>&]/g, "")}</strong>${rest.length ? `<small>${rest.join(" - ").replace(/[<>&]/g, "")}</small>` : ""}`
  })
}

// The same field polish on every form of the vendor registration and
// quotation pages (single-page forms included).
const setupProcurementFormFields = () => {
  if (!document.body.classList.contains("app-procure")) return
  document.querySelectorAll(".app-content form").forEach((form) => enhancePagedFormFields(form))
}

// Searchable dropdowns: every single-choice <select> gets a box you can type
// in to filter its options. The real <select> stays in the form (hidden) and
// keeps its value, events and validation, so all existing code still works.
const SEARCHABLE_SELECT_SKIP = "[multiple], [size]:not([size='0']):not([size='1']), [data-native-select], .app-static-page-toggle"

const enhanceSearchableSelect = (select) => {
  if (select.dataset.searchableReady === "true" || select.matches(SEARCHABLE_SELECT_SKIP)) return
  if (select.closest("[data-native-selects], .dataTables_length")) return
  select.dataset.searchableReady = "true"

  const combo = document.createElement("div")
  combo.className = "app-combo"
  const input = document.createElement("input")
  input.type = "text"
  input.className = `${select.className} app-combo__input`.trim()
  input.setAttribute("role", "combobox")
  input.setAttribute("aria-expanded", "false")
  input.setAttribute("aria-autocomplete", "list")
  input.autocomplete = "off"
  const label = select.id ? document.querySelector(`label[for="${CSS.escape(select.id)}"]`) : null
  if (label) {
    input.id = `${select.id}__search`
    label.htmlFor = input.id
  } else if (select.getAttribute("aria-label")) {
    input.setAttribute("aria-label", select.getAttribute("aria-label"))
  }
  combo.appendChild(input)
  select.insertAdjacentElement("afterend", combo)
  select.classList.add("app-combo__native")
  select.tabIndex = -1

  const list = document.createElement("ul")
  list.className = "app-combo__list"
  list.setAttribute("role", "listbox")
  list.hidden = true
  document.body.appendChild(list)

  let matches = []
  let active = -1
  let open = false

  const optionsNow = () => Array.from(select.options).filter((option) => !option.hidden)
  const placeholderOption = () => Array.from(select.options).find((option) => option.value === "")
  const selectedText = () => {
    const option = select.selectedOptions[0]
    return option && option.value !== "" ? option.textContent.trim() : ""
  }

  const sync = () => {
    if (!open) input.value = selectedText()
    input.placeholder = placeholderOption()?.textContent.trim() || "Select"
    input.disabled = select.disabled
    combo.classList.toggle("is-disabled", select.disabled)
    combo.hidden = select.hidden
  }

  const position = () => {
    const rect = input.getBoundingClientRect()
    const below = window.innerHeight - rect.bottom
    const height = Math.min(300, list.scrollHeight || 300)
    list.style.left = `${Math.max(4, rect.left)}px`
    list.style.width = `${Math.max(rect.width, 180)}px`
    if (below < height + 12 && rect.top > below) {
      list.style.top = ""
      list.style.bottom = `${window.innerHeight - rect.top + 4}px`
    } else {
      list.style.bottom = ""
      list.style.top = `${rect.bottom + 4}px`
    }
  }

  const escapeHtml = (text) => text.replace(/[&<>"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[char]))

  const render = () => {
    const query = open && input.dataset.typed === "true" ? input.value.trim().toLowerCase() : ""
    const words = query.split(/\s+/).filter(Boolean)
    matches = optionsNow().filter((option) => {
      if (option.value === "" && words.length) return false
      const text = option.textContent.toLowerCase()
      return words.every((word) => text.includes(word))
    })
    const shown = matches.slice(0, 300)
    if (active >= shown.length) active = shown.length - 1
    list.innerHTML = shown.length
      ? shown.map((option, index) => {
          let text = escapeHtml(option.textContent.trim())
          words.forEach((word) => {
            text = text.replace(new RegExp(`(${word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "ig"), "<mark>$1</mark>")
          })
          const classes = ["app-combo__option"]
          if (index === active) classes.push("is-active")
          if (option.selected && option.value !== "") classes.push("is-selected")
          if (option.disabled) classes.push("is-disabled")
          if (option.value === "") classes.push("is-placeholder")
          return `<li class="${classes.join(" ")}" role="option" data-index="${index}" aria-selected="${option.selected}">${text}</li>`
        }).join("") + (matches.length > shown.length ? `<li class="app-combo__more">Type to narrow ${matches.length - shown.length} more…</li>` : "")
      : `<li class="app-combo__empty">No match found</li>`
    position()
    list.querySelector(".is-active")?.scrollIntoView({ block: "nearest" })
  }

  const openList = () => {
    if (select.disabled || open) return
    open = true
    input.dataset.typed = "false"
    active = Math.max(0, optionsNow().filter((option) => !option.hidden).findIndex((option) => option.selected && option.value !== ""))
    list.hidden = false
    input.setAttribute("aria-expanded", "true")
    combo.classList.add("is-open")
    render()
    input.select()
  }

  const closeList = () => {
    if (!open) return
    open = false
    list.hidden = true
    input.setAttribute("aria-expanded", "false")
    combo.classList.remove("is-open")
    input.dataset.typed = "false"
    input.value = selectedText()
  }

  const choose = (option) => {
    if (!option || option.disabled) return
    const changed = select.value !== option.value
    select.value = option.value
    closeList()
    if (changed) {
      select.dispatchEvent(new Event("input", { bubbles: true }))
      select.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  input.addEventListener("focus", openList)
  input.addEventListener("click", openList)
  input.addEventListener("input", () => {
    if (!open) openList()
    input.dataset.typed = "true"
    active = 0
    render()
  })
  input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      if (!open) return openList()
      const count = Math.min(matches.length, 300)
      if (!count) return
      active = (active + (event.key === "ArrowDown" ? 1 : -1) + count) % count
      render()
    } else if (event.key === "Enter") {
      if (!open) return
      event.preventDefault()
      choose(matches[active])
    } else if (event.key === "Escape") {
      if (open) { event.preventDefault(); closeList() }
    } else if (event.key === "Tab") {
      if (open && input.dataset.typed === "true" && matches.length === 1) choose(matches[0])
      closeList()
    }
  })
  input.addEventListener("blur", () => setTimeout(() => {
    if (document.activeElement !== input) closeList()
  }, 120))
  list.addEventListener("mousedown", (event) => {
    event.preventDefault()
    const item = event.target.closest("[data-index]")
    if (item) choose(matches[Number(item.dataset.index)])
  })

  // The hidden select may still receive focus (e.g. from the step check).
  select.addEventListener("focus", () => input.focus())
  select.addEventListener("change", sync)
  select.form?.addEventListener("reset", () => setTimeout(sync, 0))

  // Code that sets select.value directly does not fire events: watch it too.
  ;["value", "selectedIndex"].forEach((property) => {
    const descriptor = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, property)
    Object.defineProperty(select, property, {
      configurable: true,
      get() { return descriptor.get.call(this) },
      set(value) { descriptor.set.call(this, value); sync() }
    })
  })
  new MutationObserver(() => { sync(); if (open) render() })
    .observe(select, { childList: true, subtree: true, attributes: true, attributeFilter: ["disabled", "hidden", "selected"] })

  const reposition = () => { if (open) position() }
  window.addEventListener("resize", reposition)
  document.addEventListener("scroll", (event) => {
    if (open && !list.contains(event.target)) closeList()
  }, true)
  document.addEventListener("turbo:before-cache", () => { closeList(); list.remove() }, { once: true })

  sync()
}

const setupSearchableSelects = (root = document) => {
  root.querySelectorAll("select").forEach(enhanceSearchableSelect)

  if (!window.appSearchableSelectObserver) {
    let pending = false
    window.appSearchableSelectObserver = new MutationObserver((mutations) => {
      if (pending) return
      if (!mutations.some((mutation) => Array.from(mutation.addedNodes).some((node) => node.nodeType === 1 && (node.matches("select") || node.querySelector?.("select"))))) return
      pending = true
      requestAnimationFrame(() => {
        pending = false
        document.querySelectorAll("select:not([data-searchable-ready])").forEach(enhanceSearchableSelect)
      })
    })
    window.appSearchableSelectObserver.observe(document.body, { childList: true, subtree: true })
  }
}

const setupFormPagination = () => {
  document.querySelectorAll("[data-ui-form-pager='true']").forEach((form) => {
    if (form.dataset.uiFormPagerReady === "true") return

    const card = Array.from(form.querySelectorAll(".app-form-card")).find((candidate) =>
      candidate.querySelector(":scope > .app-form-section, :scope > .app-page-header.app-subsection-header")
    )
    if (!card) return
    if (card.classList.contains("app-static-paged-form")) return

    const sections = Array.from(card.querySelectorAll(":scope > .app-form-section, :scope > .app-page-header.app-subsection-header"))
    if (sections.length <= 1) return

    const leadingNodes = []
    let firstNode = card.firstChild
    while (firstNode && firstNode !== sections[0]) {
      const nextNode = firstNode.nextSibling
      leadingNodes.push(firstNode)
      firstNode = nextNode
    }

    const stepGroups = sections.map((section, index) => {
      const group = document.createElement("div")
      group.className = "app-form-page"
      group.dataset.formPageIndex = String(index)

      section.parentNode.insertBefore(group, section)
      if (index === 0) {
        leadingNodes.forEach((node) => group.appendChild(node))
      }
      group.appendChild(section)

      let next = group.nextSibling
      while (next && !(next.nodeType === Node.ELEMENT_NODE && (next.classList.contains("app-form-section") || (next.classList.contains("app-page-header") && next.classList.contains("app-subsection-header"))))) {
        const node = next
        next = next.nextSibling
        group.appendChild(node)
      }

      return group
    })

    let currentStep = 0
    const nav = document.createElement("div")
    nav.className = "app-form-pager"
    nav.innerHTML = `
      <div class="app-form-pager-status" data-form-pager-status></div>
      <div class="app-form-pager-actions">
        <button type="button" class="app-secondary-btn app-form-pager-btn" data-form-pager-prev>Previous</button>
        <button type="button" class="app-secondary-btn app-form-pager-btn" data-form-pager-next>Next</button>
      </div>
    `

    const status = nav.querySelector("[data-form-pager-status]")
    const prevButton = nav.querySelector("[data-form-pager-prev]")
    const nextButton = nav.querySelector("[data-form-pager-next]")
    card.appendChild(nav)
    card.classList.add("app-form-card-paged")

    const submitActions = card.querySelector(".app-form-actions")
    if (submitActions) submitActions.classList.add("app-form-actions-sticky")

    const showStep = (stepIndex, scrollToTop = true) => {
      currentStep = Math.max(0, Math.min(stepIndex, stepGroups.length - 1))

      stepGroups.forEach((group, index) => {
        group.hidden = index !== currentStep
        group.classList.toggle("is-active", index === currentStep)
      })

      if (status) status.textContent = `Step ${currentStep + 1} of ${stepGroups.length}`
      if (prevButton) prevButton.disabled = currentStep === 0
      if (nextButton) nextButton.hidden = currentStep === stepGroups.length - 1
      if (submitActions) submitActions.hidden = currentStep !== stepGroups.length - 1

      if (scrollToTop) {
        card.scrollTo({ top: 0, behavior: "smooth" })
      }
    }

    const stepForElement = (element) => {
      const group = element?.closest(".app-form-page")
      if (!group) return -1
      return stepGroups.indexOf(group)
    }

    prevButton?.addEventListener("click", () => showStep(currentStep - 1))
    nextButton?.addEventListener("click", () => showStep(currentStep + 1))

    form.addEventListener("submit", () => {
      const invalidInput = form.querySelector("input:invalid, select:invalid, textarea:invalid")
      const invalidStep = stepForElement(invalidInput)
      if (invalidStep >= 0) showStep(invalidStep)
    }, true)

    form.addEventListener("invalid", (event) => {
      const invalidStep = stepForElement(event.target)
      if (invalidStep >= 0) showStep(invalidStep)
    }, true)

    showStep(0, false)
    form.dataset.uiFormPagerReady = "true"
  })
}

const setupFormDraftAutosave = () => {
  const storagePrefix = "asa-form-draft"
  const ignoredFieldNames = new Set(["authenticity_token", "utf8", "commit"])
  const draftSelector = "[data-draft-autosave='true']"

  const storageAvailable = () => {
    try {
      const testKey = `${storagePrefix}:test`
      window.localStorage.setItem(testKey, "1")
      window.localStorage.removeItem(testKey)
      return true
    } catch (_error) {
      return false
    }
  }

  if (!storageAvailable()) return

  const draftStorageKey = (form) => `${storagePrefix}:${form.dataset.draftKey || `${window.location.pathname}:${form.action}`}`

  const shouldSkipField = (field) =>
    !field.name ||
    ignoredFieldNames.has(field.name) ||
    field.name.endsWith("_form_step") ||
    field.disabled ||
    field.type === "file" ||
    field.type === "submit" ||
    field.type === "button" ||
    field.type === "reset"

  const readDraft = (key) => {
    try {
      return JSON.parse(window.localStorage.getItem(key) || "null")
    } catch (_error) {
      window.localStorage.removeItem(key)
      return null
    }
  }

  const valuePresent = (value) => String(value || "").trim() !== ""

  const valuesHaveContent = (values) =>
    Object.entries(values).some(([name, entries]) => {
      if (name.endsWith("[_destroy]")) return false
      return entries.some(valuePresent)
    })

  const collectValues = (form) => {
    const values = {}

    Array.from(form.elements).forEach((field) => {
      if (shouldSkipField(field)) return

      if (field.type === "checkbox" || field.type === "radio") {
        if (!field.checked) return
        values[field.name] ||= []
        values[field.name].push(field.value)
        return
      }

      if (field.tagName === "SELECT" && field.multiple) {
        values[field.name] = Array.from(field.selectedOptions).map((option) => option.value)
        return
      }

      values[field.name] ||= []
      values[field.name].push(field.value)
    })

    return values
  }

  const keysForNestedAttributes = (values, prefix) => {
    const escapedPrefix = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const matcher = new RegExp(`^${escapedPrefix}\\[([^\\]]+)\\]\\[`)
    const keys = new Set()

    Object.keys(values).forEach((name) => {
      const match = name.match(matcher)
      if (match) keys.add(match[1])
    })

    return Array.from(keys)
  }

  const formHasNestedKey = (form, prefix, key) =>
    Array.from(form.elements).some((field) => field.name?.startsWith(`${prefix}[${key}]`))

  const nestedKeyMarkedForDestroy = (values, prefix, key) =>
    values[`${prefix}[${key}][_destroy]`]?.includes("1")

  const restoreQuotationRows = (form, values) => {
    const itemPrefix = "quotation_proposal[quotation_proposal_items_attributes]"
    const itemList = form.querySelector("[data-quotation-item-list]")
    const itemTemplate = form.querySelector("[data-quotation-item-template]")

    if (itemList && itemTemplate) {
      keysForNestedAttributes(values, itemPrefix).forEach((key) => {
        if (nestedKeyMarkedForDestroy(values, itemPrefix, key)) return
        if (formHasNestedKey(form, itemPrefix, key)) return

        itemList.insertAdjacentHTML("beforeend", itemTemplate.innerHTML.replace(/NEW_ITEM/g, key))
      })
    }

  }

  const applyValues = (form, values) => {
    Array.from(form.elements).forEach((field) => {
      if (shouldSkipField(field)) return
      if (!Object.prototype.hasOwnProperty.call(values, field.name)) return

      const savedValues = values[field.name].map(String)

      if (field.type === "checkbox" || field.type === "radio") {
        field.checked = savedValues.includes(String(field.value))
      } else if (field.tagName === "SELECT" && field.multiple) {
        Array.from(field.options).forEach((option) => {
          option.selected = savedValues.includes(String(option.value))
        })
      } else {
        field.value = savedValues[0] || ""
      }

      // Validators skip these events: a restored draft must not show errors
      // before the user has done anything.
      form.dataset.draftRestoring = "true"
      try {
        field.dispatchEvent(new Event("input", { bubbles: true }))
        field.dispatchEvent(new Event("change", { bubbles: true }))
      } finally {
        delete form.dataset.draftRestoring
      }
    })
  }

  document.querySelectorAll(draftSelector).forEach((form) => {
    if (form.dataset.draftAutosaveReady === "true") return

    const key = draftStorageKey(form)
    const draft = readDraft(key)

    if (draft?.values) {
      restoreQuotationRows(form, draft.values)
      applyValues(form, draft.values)
      window.setTimeout(() => applyValues(form, draft.values), 150)
      window.setTimeout(() => applyValues(form, draft.values), 600)
    }

    const persistDraft = () => {
      const values = collectValues(form)
      if (!valuesHaveContent(values)) {
        window.localStorage.removeItem(key)
        return
      }

      window.localStorage.setItem(key, JSON.stringify({
        savedAt: new Date().toISOString(),
        values,
      }))
    }

    let saveTimer
    const saveDraft = () => {
      window.clearTimeout(saveTimer)
      saveTimer = window.setTimeout(persistDraft, 200)
    }

    form.addEventListener("input", saveDraft)
    form.addEventListener("change", saveDraft)
    form.addEventListener("click", () => window.setTimeout(saveDraft, 0))

    form.addEventListener("submit", (event) => {
      window.setTimeout(() => {
        if (!event.defaultPrevented) window.localStorage.removeItem(key)
      }, 0)
    })

    document.addEventListener("turbo:before-cache", persistDraft)
    window.addEventListener("beforeunload", persistDraft)

    form.dataset.draftAutosaveReady = "true"
    saveDraft()
  })
}

const setupPageSectionPagination = () => {
  document.querySelectorAll("[data-ui-page-pager='true']").forEach((container) => {
    if (container.dataset.uiPagePagerReady === "true") return
    if (container.classList.contains("employee-master-workspace")) return

    const sections = Array.from(container.children).filter((child) => {
      if (!(child instanceof HTMLElement)) return false
      if (child.matches(".app-page-header, .app-detail-actions, .app-form-pager")) return false
      return child.matches(".app-detail-card, .app-form-card, .app-card, .app-table-wrap, details")
    })

    if (sections.length <= 2) return

    let currentPage = 0
    const nav = document.createElement("div")
    nav.className = "app-form-pager app-page-section-pager"
    nav.innerHTML = `
      <div class="app-form-pager-status" data-page-pager-status></div>
      <div class="app-form-pager-actions">
        <button type="button" class="app-secondary-btn app-form-pager-btn" data-page-pager-prev>Previous</button>
        <button type="button" class="app-secondary-btn app-form-pager-btn" data-page-pager-next>Next</button>
      </div>
    `

    const status = nav.querySelector("[data-page-pager-status]")
    const prevButton = nav.querySelector("[data-page-pager-prev]")
    const nextButton = nav.querySelector("[data-page-pager-next]")
    container.appendChild(nav)
    container.classList.add("app-page-paged")

    const showPage = (pageIndex) => {
      currentPage = Math.max(0, Math.min(pageIndex, sections.length - 1))

      sections.forEach((section, index) => {
        section.hidden = index !== currentPage
        section.style.minHeight = index === currentPage ? "0" : ""
        section.style.overflowY = index === currentPage ? "auto" : ""
      })

      if (status) status.textContent = `Page ${currentPage + 1} of ${sections.length}`
      if (prevButton) prevButton.disabled = currentPage === 0
      if (nextButton) nextButton.disabled = currentPage === sections.length - 1
      container.scrollTo({ top: 0, behavior: "smooth" })
    }

    prevButton?.addEventListener("click", () => showPage(currentPage - 1))
    nextButton?.addEventListener("click", () => showPage(currentPage + 1))

    showPage(0)
    container.dataset.uiPagePagerReady = "true"
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
      if (form.dataset.draftRestoring === "true") return true

      clearFieldError(input)

      const label = input.dataset.validationLabel || input.getAttribute("aria-label") || "This field"
      const minWords = parseInt(input.dataset.minWords || "0", 10)
      if (minWords > 0 && input.value.trim() !== "") {
        const wordCount = (input.value.match(/\b[\w]+\b/g) || []).length
        if (wordCount < minWords) {
          showFieldError(input, `${label} must be at least ${minWords} words.`)
          return false
        }
      }
      const maxWords = parseInt(input.dataset.maxWords || "0", 10)
      if (maxWords > 0 && input.value.trim() !== "") {
        const wordCount = (input.value.match(/\b[\w]+\b/g) || []).length
        if (wordCount > maxWords) {
          showFieldError(input, `${label} must not exceed ${maxWords} words.`)
          return false
        }
      }

      if (input.checkValidity()) return true

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
          criteriaSelectedPreview.textContent = "No criteria selected."
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
          ? "Below 10K: one vendor only."
          : "Vendors of the selected theme."
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
      const query = (search?.value || "").trim().toLowerCase()
      const selectedCheckboxes = vendorOptions
        .map((option) => option.querySelector(".quotation-vendor-checkbox"))
        .filter((checkbox) => checkbox?.checked)
      const lockedSelection = singleVendorMode() && selectedCheckboxes.length > 0 ? selectedCheckboxes[0].value : null

      vendorOptions.forEach((option) => {
        const themeIds = (option.dataset.themeIds || "").split(",").filter(Boolean)
        const text = option.innerText.toLowerCase()
        const matchesTheme = selectedThemeId === "" || themeIds.includes(selectedThemeId)
        const matchesSearch = query === "" || text.includes(query)
        const checkbox = option.querySelector(".quotation-vendor-checkbox")
        const isSelected = !!checkbox?.checked
        const shouldShow = matchesTheme && matchesSearch && !isSelected

        option.classList.toggle("is-hidden", !shouldShow)
        if (!matchesTheme && checkbox) checkbox.checked = false
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
          const text = option.innerText.toLowerCase()
          const matchesTheme = selectedThemeId === "" || themeIds.includes(selectedThemeId)
          const matchesSearch = query === "" || text.includes(query)
          return matchesTheme && matchesSearch
        })

        emptyState.textContent = selectedMatchingOptions.length > 0
          ? "All matching vendors are selected."
          : "No vendor matches the selected theme or search."
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

    const form = container.closest("[data-quotation-validation-form]")
    const approvalRoute = form?.querySelector("[name='quotation_proposal[committee_approval_required]']")
    const committeeRequired = () => approvalRoute?.value !== "false"
    const skippedNotice = container.querySelector("[data-quotation-committee-skipped]")
    const policyBlock = container.querySelector("[data-quotation-committee-policy-block]")
    const amountNode = container.querySelector("[data-committee-amount]")
    const searchField = container.querySelector("[data-committee-member-search]")
    const idField = container.querySelector("[data-committee-member-id]")
    // With a Thematic Head selected, the head builds the committee instead.
    const headIdField = form?.querySelector("[name='quotation_proposal[thematic_head_id]']")
    const headNote = form?.querySelector("[data-thematic-head-committee-note]")
    const headChosen = () => Boolean(headIdField?.value)
    // One vendor (Above 10K): approved by the Director only, no committee step.
    const singleVendorNote = form?.querySelector("[data-single-vendor-committee-note]")
    const singleVendor = () => {
      const bucket = form?.querySelector("#quotation_proposal_procurement_amount_bucket")?.value
      const checked = form ? form.querySelectorAll(".quotation-vendor-checkbox:checked").length : 0
      return bucket !== "below_10k" && checked === 1
    }
    const memberOptions = searchField?.list ? Array.from(searchField.list.options) : []
    let policy = {}
    try {
      policy = JSON.parse(container.dataset.committeePolicy || "{}")
    } catch (error) {
      policy = {}
    }
    if (!searchField || !idField) return

    const threshold = Number(policy.threshold || 1000000)
    const rupees = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 })

    // Same rule as QuotationProposal#estimated_procurement_amount: every kept
    // item needs a quantity and max rate before the value can be known.
    const estimatedAmount = () => {
      const rows = Array.from(form?.querySelectorAll("[data-quotation-item-row]") || []).filter((row) => {
        const destroyField = row.querySelector("[data-quotation-item-destroy]")
        return row.style.display !== "none" && (!destroyField || destroyField.value !== "1")
      })
      if (!rows.length) return null

      let total = 0
      for (const row of rows) {
        const quantity = row.querySelector("[name$='[quantity]']")?.value
        const maxRate = row.querySelector("[name$='[max_rate]']")?.value
        if (quantity === "" || quantity == null || maxRate === "" || maxRate == null) return null
        total += Number(quantity) * Number(maxRate)
      }
      return Number.isFinite(total) ? total : null
    }

    const policyMembers = () => {
      const amount = estimatedAmount()
      const upToThreshold = amount !== null && amount <= threshold
      return {
        amount,
        2: upToThreshold
          ? { role: "COO (up to ₹10 lakh)", member: policy.coo }
          : { role: amount === null ? "Director (above ₹10 lakh) – COO if value is up to ₹10 lakh" : "Director (above ₹10 lakh)", member: policy.director },
        3: { role: "Programme Director – Finance", member: policy.finance }
      }
    }

    const renderPolicy = () => {
      const required = committeeRequired()
      container.hidden = headChosen() || singleVendor()
      if (headNote) headNote.hidden = !headChosen() || singleVendor()
      if (singleVendorNote) singleVendorNote.hidden = !singleVendor()
      if (skippedNotice) skippedNotice.hidden = required
      if (policyBlock) policyBlock.hidden = !required

      const members = policyMembers()
      if (amountNode) {
        amountNode.textContent = members.amount === null ? "Add item quantity and max rate" : rupees.format(members.amount)
      }

      ;[2, 3].forEach((level) => {
        const node = container.querySelector(`[data-committee-policy-member="${level}"]`)
        if (!node) return
        const { role, member } = members[level]
        node.querySelector("[data-committee-policy-role]").textContent = role
        const nameNode = node.querySelector("[data-committee-policy-name]")
        nameNode.textContent = member ? member.name : "Not configured in Employee Master"
        nameNode.classList.toggle("is-missing", !member)
      })
      return members
    }

    const normalizeName = (value) => value.replace(/\s+/g, " ").trim().toLowerCase()
    const matchedOption = () => {
      const typed = normalizeName(searchField.value)
      if (!typed) return null
      return memberOptions.find((option) => normalizeName(option.value) === typed) || null
    }

    const syncSelectedMember = () => {
      const option = matchedOption()
      idField.value = option ? option.dataset.id : ""
    }

    const fillSearchFromId = () => {
      if (!idField.value || searchField.value.trim()) return
      const option = memberOptions.find((candidate) => candidate.dataset.id === String(idField.value))
      if (option) searchField.value = option.value
    }

    const setError = (message) => {
      const wrapper = searchField.closest(".app-form-field")
      const errorNode = wrapper?.querySelector("[data-field-error='true']")
      wrapper?.classList.toggle("has-error", Boolean(message))
      if (errorNode) {
        errorNode.textContent = message || ""
        errorNode.classList.toggle("is-visible", Boolean(message))
      }
    }

    const validateCommittee = ({ showEmpty = false } = {}) => {
      const members = renderPolicy()
      if (!committeeRequired() || headChosen() || singleVendor()) {
        setError("")
        return true
      }

      if (!idField.value) {
        const typed = searchField.value.trim()
        if (typed || showEmpty) {
          setError(typed ? "Pick a name from the suggestions list." : "1st Committee Member is required.")
          return false
        }
        setError("")
        return true
      }

      const policyIds = [members[2].member?.id, members[3].member?.id].filter(Boolean).map(String)
      if (policyIds.includes(String(idField.value))) {
        setError("This person is already a mandatory committee member. Choose someone else.")
        return false
      }

      setError("")
      return true
    }

    searchField.addEventListener("input", () => {
      syncSelectedMember()
      validateCommittee()
    })
    searchField.addEventListener("change", () => {
      syncSelectedMember()
      validateCommittee()
    })
    searchField.addEventListener("blur", () => validateCommittee())
    idField.addEventListener("change", () => {
      fillSearchFromId()
      validateCommittee()
    })

    form?.addEventListener("input", (event) => {
      if (event.target.matches("[name$='[quantity]'], [name$='[max_rate]']")) renderPolicy()
      if (event.target.matches("#thematic-head-search")) validateCommittee()
    })
    form?.addEventListener("change", (event) => {
      if (event.target.matches(".quotation-vendor-checkbox, #quotation_proposal_procurement_amount_bucket")) validateCommittee()
    })
    form?.addEventListener("click", (event) => {
      if (event.target.closest("[data-remove-quotation-item], [data-add-quotation-item]")) setTimeout(renderPolicy, 0)
    })
    form?.addEventListener("submit", (event) => {
      if (!validateCommittee({ showEmpty: true })) {
        event.preventDefault()
        const step5 = document.getElementById("quotation-step-5")
        if (step5) step5.checked = true
        searchField.focus()
      }
    })
    approvalRoute?.addEventListener("change", () => validateCommittee())
    registerStepValidator(form, container, () => validateCommittee({ showEmpty: true }))

    fillSearchFromId()
    renderPolicy()
    container.dataset.ready = "true"
  })

  // Initialisers can run twice (turbo:load and DOMContentLoaded); bind once.
  if (vendorDropdown && vendorDropdown.dataset.vendorRuleReady !== "true") {
    vendorDropdown.dataset.vendorRuleReady = "true"
    const form = vendorDropdown.closest("[data-quotation-validation-form]")
    const errorNode = form?.querySelector("[data-vendor-selection-error='true']")
    const fieldWrapper = form?.querySelector("[data-vendor-selection-field]")
    const vendorCheckboxes = Array.from(vendorDropdown.querySelectorAll(".quotation-vendor-checkbox"))

    const bucketField = form?.querySelector("#quotation_proposal_procurement_amount_bucket")
    const justificationBlock = form?.querySelector("[data-single-vendor-justification]")
    const justificationField = justificationBlock?.querySelector("textarea")
    // Above 10K: 3 or more vendors, or exactly one vendor with a note.
    const vendorRuleApplies = () => bucketField?.value !== "below_10k"

    const validateVendorSelection = ({ quiet = false } = {}) => {
      const count = vendorCheckboxes.filter((checkbox) => checkbox.checked).length
      let message = ""
      if (count === 0) {
        message = "Select at least one vendor."
      } else if (vendorRuleApplies() && count === 2) {
        message = "Select at least 3 vendors, or a single vendor with a Logic Note."
      }

      const single = vendorRuleApplies() && count === 1
      if (justificationBlock) justificationBlock.hidden = !single
      if (justificationField) justificationField.required = single
      if (quiet) return !message

      if (fieldWrapper) fieldWrapper.classList.toggle("has-error", Boolean(message))
      if (errorNode) {
        errorNode.textContent = message
        errorNode.classList.toggle("is-visible", Boolean(message))
      }
      return !message
    }

    // Lets the step guard check the vendor choice before leaving this step.
    registerStepValidator(form, fieldWrapper, () => validateVendorSelection())

    // Draft restore fires synthetic change events: update the Logic Note block
    // but show an error only after a real change by the user.
    vendorCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", (event) => validateVendorSelection({ quiet: !event.isTrusted }))
    })
    bucketField?.addEventListener("change", (event) => validateVendorSelection({ quiet: !event.isTrusted }))
    validateVendorSelection({ quiet: true })

    // Logic Note: "i" shows the sample format, which can be inserted into the field.
    const logicNoteToggle = form?.querySelector("[data-logic-note-toggle]")
    const logicNoteHelp = form?.querySelector("[data-logic-note-help]")
    const logicNoteCount = form?.querySelector("[data-logic-note-count]")
    const setLogicNoteHelp = (open) => {
      if (!logicNoteHelp) return
      logicNoteHelp.hidden = !open
      logicNoteToggle?.setAttribute("aria-expanded", String(open))
    }
    const updateLogicNoteCount = () => {
      if (!logicNoteCount || !justificationField) return
      logicNoteCount.textContent = String((justificationField.value.match(/\b[\w]+\b/g) || []).length)
    }
    logicNoteToggle?.addEventListener("click", () => setLogicNoteHelp(logicNoteHelp?.hidden))
    form?.querySelector("[data-logic-note-close]")?.addEventListener("click", () => setLogicNoteHelp(false))
    // Fills the format with what this Request for Proposal already contains;
    // anything not filled in yet stays as a [ ] placeholder.
    const logicNoteValues = () => {
      const rupees = new Intl.NumberFormat("en-IN", { maximumFractionDigits: 2 })
      const text = (node) => node?.textContent?.replace(/\s+/g, " ").trim() || ""
      // The format already starts with "Procurement of", so do not repeat it.
      const subject = form.querySelector("[name='quotation_proposal[subject]']")?.value.trim().replace(/^procurement\s+of\s+/i, "")
      const themeSelect = form.querySelector("#quotation_proposal_theme_id")
      const theme = themeSelect?.value ? text(themeSelect.selectedOptions[0]) : ""
      const vendor = vendorCheckboxes.filter((checkbox) => checkbox.checked)
        .map((checkbox) => text(checkbox.closest("[data-vendor-option]")?.querySelector("strong")))
        .filter(Boolean).join(", ")
      const endDate = form.querySelector("[name='quotation_proposal[proposal_end_date]']")?.value
      const formattedDate = endDate ? endDate.split("-").reverse().join("-") : ""

      let total = 0
      const items = Array.from(form.querySelectorAll("[data-quotation-item-row]")).filter((row) => {
        const destroyField = row.querySelector("[data-quotation-item-destroy]")
        return row.style.display !== "none" && (!destroyField || destroyField.value !== "1")
      }).map((row) => {
        const nameSelect = row.querySelector("[name$='[item_name]']")
        const name = nameSelect?.value ? (text(nameSelect.selectedOptions?.[0]) || nameSelect.value) : ""
        const unitSelect = row.querySelector("[name$='[unit_id]']")
        const unit = unitSelect?.value ? text(unitSelect.selectedOptions[0]) : ""
        const quantity = Number(row.querySelector("[name$='[quantity]']")?.value || 0)
        const maxRate = Number(row.querySelector("[name$='[max_rate]']")?.value || 0)
        if (!name || !quantity || !maxRate) return null
        total += quantity * maxRate
        return `- ${name}: ${quantity} ${unit} x Rs. ${rupees.format(maxRate)} = Rs. ${rupees.format(quantity * maxRate)}`.replace(/\s+x/, " x")
      }).filter(Boolean)

      return {
        subject: subject || "[item / purpose]",
        theme: theme || "[theme]",
        items: items.length ? items.join("\n") : "- [Item]: [qty] [unit] x Rs. [max rate] = Rs. [amount]",
        total: items.length ? rupees.format(total) : "[total]",
        vendor: vendor || "[vendor name]",
        end_date: formattedDate || "[date]"
      }
    }

    form?.querySelector("[data-logic-note-use]")?.addEventListener("click", () => {
      const template = form.querySelector("[data-logic-note-template]")
      if (!template || !justificationField) return
      const values = logicNoteValues()
      const text = template.content.textContent.trim().replace(/\{\{(\w+)\}\}/g, (match, key) => values[key] ?? match)
      justificationField.value = justificationField.value.trim() ? `${justificationField.value.trim()}\n\n${text}` : text
      justificationField.dispatchEvent(new Event("input", { bubbles: true }))
      setLogicNoteHelp(false)
      justificationField.focus()
    })
    justificationField?.addEventListener("input", updateLogicNoteCount)
    updateLogicNoteCount()

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

const setupBulkDeleteSelections = () => {
  const rowCheckboxesFor = (formId) =>
    Array.from(document.querySelectorAll("[data-bulk-delete-checkbox]")).filter((checkbox) => checkbox.getAttribute("form") === formId)

  const selectAllCheckboxFor = (formId) =>
    Array.from(document.querySelectorAll("[data-bulk-delete-select-all]")).find((checkbox) => checkbox.getAttribute("form") === formId)

  const syncSelectionState = (formId) => {
    const rowCheckboxes = rowCheckboxesFor(formId)
    const selectAllCheckbox = selectAllCheckboxFor(formId)
    if (!selectAllCheckbox || rowCheckboxes.length === 0) return

    const checkedCount = rowCheckboxes.filter((checkbox) => checkbox.checked).length
    selectAllCheckbox.checked = checkedCount === rowCheckboxes.length
    selectAllCheckbox.indeterminate = checkedCount > 0 && checkedCount < rowCheckboxes.length
  }

  if (document.body.dataset.bulkDeleteDelegationReady !== "true") {
    document.addEventListener("change", (event) => {
      const target = event.target
      if (!(target instanceof HTMLInputElement)) return

      if (target.matches("[data-bulk-delete-select-all]")) {
        const formId = target.getAttribute("form")
        if (!formId) return

        rowCheckboxesFor(formId).forEach((checkbox) => {
          checkbox.checked = target.checked
        })
        syncSelectionState(formId)
        return
      }

      if (target.matches("[data-bulk-delete-checkbox]")) {
        const formId = target.getAttribute("form")
        if (formId) syncSelectionState(formId)
      }
    })

    document.addEventListener("submit", (event) => {
      const form = event.target
      if (!(form instanceof HTMLFormElement) || !form.matches("[data-bulk-delete-form]") || !form.id) return

      const selectAllCheckbox = selectAllCheckboxFor(form.id)
      if (!selectAllCheckbox?.checked) return

      rowCheckboxesFor(form.id).forEach((checkbox) => {
        checkbox.checked = true
      })
    })

    document.body.dataset.bulkDeleteDelegationReady = "true"
  }

  document.querySelectorAll("[data-bulk-delete-form]").forEach((form) => {
    if (!form.id) return

    syncSelectionState(form.id)
  })
}

const setupProductBatchForm = () => {
  document.querySelectorAll("[data-product-batch-form]").forEach((form) => {
    if (form.dataset.productBatchReady === "true") return

    const rowsContainer = form.querySelector("[data-product-rows]")
    const template = form.querySelector("[data-product-row-template]")
    const addButton = form.querySelector("[data-add-product-row]")
    const rowCount = form.querySelector("[data-product-row-count]")
    if (!rowsContainer || !template || !addButton) return

    let nextIndex = Array.from(rowsContainer.querySelectorAll("[data-product-row]")).length

    const syncRows = () => {
      const rows = Array.from(rowsContainer.querySelectorAll("[data-product-row]"))

      if (rowCount) rowCount.textContent = String(rows.length)

      rows.forEach((row, index) => {
        const number = row.querySelector("[data-product-row-number]")
        const removeButton = row.querySelector("[data-remove-product-row]")

        if (number) number.textContent = String(index + 1)
        if (removeButton) removeButton.hidden = rows.length === 1
      })
    }

    addButton.addEventListener("click", () => {
      const html = template.innerHTML.replaceAll("NEW_RECORD", String(nextIndex))
      nextIndex += 1

      rowsContainer.insertAdjacentHTML("beforeend", html)
      syncRows()

      const lastRow = rowsContainer.querySelector("[data-product-row]:last-child")
      lastRow?.querySelector("input[type='text'], select, textarea")?.focus()
    })

    rowsContainer.addEventListener("click", (event) => {
      const removeButton = event.target instanceof Element ? event.target.closest("[data-remove-product-row]") : null
      if (!removeButton) return

      const rows = Array.from(rowsContainer.querySelectorAll("[data-product-row]"))
      if (rows.length <= 1) return

      removeButton.closest("[data-product-row]")?.remove()
      syncRows()
    })

    form.dataset.productBatchReady = "true"
    syncRows()
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

const setupQuotationShowDetails = () => {
  document.querySelectorAll(".quotation-proposal-show details").forEach((details) => {
    if (details.dataset.quotationAlwaysOpenReady === "true") {
      details.open = true
      return
    }

    details.open = true
    details.addEventListener("toggle", () => {
      if (!details.open) details.open = true
    })
    details.dataset.quotationAlwaysOpenReady = "true"
  })
}

// Narrow table cells clip their text to an ellipsis. Give every clipped cell a
// native tooltip so the full value is one hover away, and re-check on resize
// because the clipping depends on the column width.
// Type-to-search employee field: the visible input shows "Name (Designation)"
// from a datalist and the hidden field carries the chosen employee id.
const setupEmployeePickers = () => {
  document.querySelectorAll("[data-employee-picker]").forEach((wrapper) => {
    if (wrapper.dataset.pickerReady === "true") return
    const searchField = wrapper.querySelector("[data-employee-picker-search]")
    const idField = wrapper.querySelector("[data-employee-picker-id]")
    if (!searchField || !idField) return
    wrapper.dataset.pickerReady = "true"

    const options = searchField.list ? Array.from(searchField.list.options) : []
    const normalize = (value) => value.replace(/\s+/g, " ").trim().toLowerCase()
    const errorNode = wrapper.querySelector("[data-field-error='true']")

    const sync = () => {
      const typed = normalize(searchField.value)
      const match = typed ? options.find((option) => normalize(option.value) === typed) : null
      idField.value = match ? match.dataset.id : ""
      const invalid = typed !== "" && !match
      searchField.setCustomValidity(invalid ? "Pick a name from the suggestions list." : "")
      wrapper.classList.toggle("has-error", invalid)
      if (errorNode) {
        errorNode.textContent = invalid ? "Pick a name from the suggestions list." : ""
        errorNode.classList.toggle("is-visible", invalid)
      }
    }

    if (idField.value && !searchField.value.trim()) {
      const option = options.find((candidate) => candidate.dataset.id === String(idField.value))
      if (option) searchField.value = option.value
    }

    searchField.addEventListener("input", sync)
    searchField.addEventListener("change", sync)
    idField.addEventListener("change", () => {
      if (idField.value && !searchField.value.trim()) {
        const option = options.find((candidate) => candidate.dataset.id === String(idField.value))
        if (option) searchField.value = option.value
      }
    })
    if (searchField.value.trim()) sync()
  })
}

const setupTruncatedCellTooltips = () => {
  // Fixed-layout list tables split the card width evenly, so on a small laptop
  // a dozen columns shrink until even dates are cut off. Give each column a
  // readable minimum; the table wrapper scrolls sideways when it needs more.
  document.querySelectorAll(".app-table-wrap table.app-table").forEach((table) => {
    if (table.dataset.minWidthReady === "true") return
    table.dataset.minWidthReady = "true"
    if (table.querySelector("tbody input:not([type='checkbox']):not([type='hidden']):not([type='submit']), tbody select, tbody textarea")) return

    const columnCount = table.querySelector("thead tr")?.children.length || 0
    if (columnCount < 5) return

    const existingMinWidth = parseFloat(window.getComputedStyle(table).minWidth) || 0
    table.style.minWidth = `${Math.max(columnCount * 118, existingMinWidth)}px`
  })

  const applyTooltips = () => {
    document.querySelectorAll(".app-table td, .app-table th").forEach((cell) => {
      if (cell.querySelector("input, select, textarea, button, .app-form-field")) return

      const target = cell.querySelector("[data-truncate-target]") || cell
      const full = target.textContent.trim()

      if (!full) {
        target.removeAttribute("title")
        return
      }

      const clipped = target.scrollWidth > target.clientWidth + 1 || target.scrollHeight > target.clientHeight + 1
      if (clipped) {
        if (target.getAttribute("title") !== full) target.setAttribute("title", full)
        target.classList.add("is-truncated")
      } else if (target.dataset.keepTitle !== "true") {
        target.removeAttribute("title")
        target.classList.remove("is-truncated")
      }
    })
  }

  applyTooltips()

  if (window.__truncationTooltipsBound) return
  window.__truncationTooltipsBound = true

  let resizeTimer = null
  window.addEventListener("resize", () => {
    window.clearTimeout(resizeTimer)
    resizeTimer = window.setTimeout(applyTooltips, 150)
  })
}

const setupCopyLinkButtons = () => {
  document.querySelectorAll("[data-copy-text]").forEach((button) => {
    if (button.dataset.copyReady === "true") return
    button.dataset.copyReady = "true"

    const originalLabel = button.textContent
    button.addEventListener("click", async () => {
      const value = button.dataset.copyText
      if (!value) return

      let copied = false
      try {
        await navigator.clipboard.writeText(value)
        copied = true
      } catch (error) {
        const scratch = document.createElement("textarea")
        scratch.value = value
        scratch.setAttribute("readonly", "readonly")
        scratch.style.position = "fixed"
        scratch.style.opacity = "0"
        document.body.appendChild(scratch)
        scratch.select()
        try {
          copied = document.execCommand("copy")
        } catch (fallbackError) {
          copied = false
        }
        document.body.removeChild(scratch)
      }

      button.textContent = copied ? "Copied" : "Press Ctrl+C"
      window.setTimeout(() => {
        button.textContent = originalLabel
      }, 2000)
    })
  })
}

const setupAutoDismissFlash = () => {
  document.querySelectorAll("[data-auto-dismiss-flash='true']").forEach((flash) => {
    if (flash.dataset.autoDismissReady === "true") return

    flash.dataset.autoDismissReady = "true"
    window.setTimeout(() => {
      flash.classList.add("is-dismissing")
      window.setTimeout(() => flash.remove(), 250)
    }, 3000)
  })
}

const runAppInitializers = () => {
  setupFormDraftAutosave()
  setupVendorRegistrationSelections()
  setupVendorDocumentToggle()
  setupMsmeToggle()
  setupTableSearch()
  setupTablePagination()
  setupTableSorting()
  setupApprovalChannelSteps()
  setupQuotationProposalForm()
  setupVendorApprovalSelections()
  setupQuotationApprovalSelections()
  setupVendorQuotationCalculations()
  setupAssetProductCodeAutofill()
  setupAssetInsuranceFields()
  setupFinanceQueueBulkSelection()
  setupBulkDeleteSelections()
  setupProductBatchForm()
  setupPasswordVisibility()
  setupQuotationShowDetails()
  setupEmployeePickers()
  setupStaticPagerValidation()
  setupProcurementFormFields()
  setupSearchableSelects()
  setupTruncatedCellTooltips()
  setupCopyLinkButtons()
  setupAutoDismissFlash()
  setupFormPagination()
  setupPageSectionPagination()
}

const scheduleAppInitializers = () => {
  window.requestAnimationFrame(() => {
    runAppInitializers()
  })
}

window.addEventListener("pageshow", (event) => {
  const navigationEntry = performance.getEntriesByType("navigation")[0]
  const restoredFromHistory = event.persisted || navigationEntry?.type === "back_forward"

  if (restoredFromHistory) window.location.reload()
})

// Below the desktop breakpoint the sidebar collapses behind the navbar menu
// button. Delegated once so it survives Turbo page swaps.
if (!window.__sidebarToggleBound) {
  window.__sidebarToggleBound = true

  const setSidebarOpen = (open) => {
    document.body.classList.toggle("app-sidebar-open", open)
    document.querySelectorAll("[data-sidebar-toggle]").forEach((button) => {
      button.setAttribute("aria-expanded", String(open))
      button.setAttribute("aria-label", open ? "Close menu" : "Open menu")
    })
  }

  document.addEventListener("click", (event) => {
    if (event.target.closest("[data-sidebar-toggle]")) {
      setSidebarOpen(!document.body.classList.contains("app-sidebar-open"))
      return
    }

    // Following a menu link closes the menu on small screens.
    if (event.target.closest(".app-sidebar a[href]:not([data-bs-toggle])")) setSidebarOpen(false)
  })

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setSidebarOpen(false)
  })

  document.addEventListener("turbo:load", () => setSidebarOpen(false))
}

document.addEventListener("turbo:load", scheduleAppInitializers)
document.addEventListener("DOMContentLoaded", scheduleAppInitializers)
if (document.readyState !== "loading") {
  scheduleAppInitializers()
}
