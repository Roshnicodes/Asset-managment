import { Controller } from "@hotwired/stimulus"

const DEFAULT_BANKS = [
  { id: "default-hdfc-bank", name: "HDFC Bank" },
  { id: "default-icici-bank", name: "ICICI Bank" },
  { id: "default-state-bank-of-india", name: "State Bank of India" },
  { id: "default-axis-bank", name: "Axis Bank" },
  { id: "default-kotak-mahindra-bank", name: "Kotak Mahindra Bank" },
  { id: "default-punjab-national-bank", name: "Punjab National Bank" }
]

export default class extends Controller {
  static values = {
    banks: Array,
    records: Array,
    nextAdviceNo: String,
    createBankUrl: String,
    createRecordUrl: String,
    usedEmails: Array,
    canDelete: Boolean
  }

  static targets = [
    "navItem", "panel",
    "companyName", "adviceNo", "payeeName", "payeeEmail", "ccEmails", "bccEmails", "invoiceNo", "invoiceDate",
    "paymentMode", "referenceNo", "bankSelect", "paymentDate", "grossAmount", "tdsAmount",
    "otherDeduction", "remarks", "newBankName", "bankList", "bankCount", "netPreview",
    "recordList", "recordCount", "saveMessage", "modeBanner", "saveButton", "sendButton",
    "previewCompany", "previewAdviceNo", "previewPayee", "previewEmail", "previewInvoiceSubject",
    "previewInvoiceNo", "previewInvoiceDate", "previewGrossAmount", "previewTdsAmount",
    "previewOtherDeduction", "previewNetAmount", "previewNetAmountTable", "previewPaymentMode",
    "previewReferenceNo", "previewBankName", "previewPaymentDate", "previewRemarks"
  ]

  connect() {
    const today = new Date().toISOString().slice(0, 10)

    this.currentRecordId = null
    this.banks = this.banksValue.length > 0 ? this.banksValue : DEFAULT_BANKS
    this.records = this.recordsValue
    this.renderBanks("HDFC Bank")
    this.renderRecords()
    this.setupEmailSuggestions()
    this.setMode(null)

    this.companyNameTarget.value = "Accounts Department"
    if (this.adviceNoTarget.value === "PA-2026-001") this.adviceNoTarget.value = this.nextAdviceNoValue
    if (!this.invoiceDateTarget.value) this.invoiceDateTarget.value = today
    if (!this.paymentDateTarget.value) this.paymentDateTarget.value = today

    this.activateInitialView()
    this.refresh()
  }

  showView(event) {
    const view = event.currentTarget.dataset.view
    if (!view) return

    this.activateView(view)
  }

  refresh() {
    const gross = this.numberValue(this.grossAmountTarget.value)
    const tds = this.numberValue(this.tdsAmountTarget.value)
    const other = this.numberValue(this.otherDeductionTarget.value)
    const net = Math.max(gross - tds - other, 0)
    const formattedNet = this.formatCurrency(net)

    this.previewCompanyTarget.textContent = this.fallback(this.companyNameTarget.value, "Accounts Department")
    this.previewAdviceNoTarget.textContent = this.fallback(this.adviceNoTarget.value, "-")
    this.previewPayeeTarget.textContent = this.fallback(this.payeeNameTarget.value, "-")
    this.previewEmailTarget.textContent = this.fallback(this.payeeEmailTarget.value, "-")
    this.previewInvoiceSubjectTarget.textContent = this.fallback(this.invoiceNoTarget.value, "-")
    this.previewInvoiceNoTarget.textContent = this.fallback(this.invoiceNoTarget.value, "-")
    this.previewInvoiceDateTarget.textContent = this.formatDate(this.invoiceDateTarget.value)
    this.previewGrossAmountTarget.textContent = this.formatCurrency(gross)
    this.previewTdsAmountTarget.textContent = this.formatCurrency(tds)
    this.previewOtherDeductionTarget.textContent = this.formatCurrency(other)
    this.previewNetAmountTarget.textContent = formattedNet
    this.previewNetAmountTableTarget.textContent = formattedNet
    this.netPreviewTarget.textContent = formattedNet
    this.previewPaymentModeTarget.textContent = this.paymentModeTarget.value
    this.previewReferenceNoTarget.textContent = this.fallback(this.referenceNoTarget.value, "-")
    this.previewBankNameTarget.textContent = this.fallback(this.bankSelectTarget.value, "-")
    this.previewPaymentDateTarget.textContent = this.formatDate(this.paymentDateTarget.value)
    this.previewRemarksTarget.textContent = this.fallback(this.remarksTarget.value, "-")
  }

  async addBank() {
    const bankName = this.newBankNameTarget.value.trim()
    if (!bankName) return

    const existingBank = this.banks.find((bank) => bank.name.toLowerCase() === bankName.toLowerCase())
    if (existingBank) {
      this.newBankNameTarget.value = ""
      this.renderBanks(existingBank.name)
      this.refresh()
      return
    }

    try {
      const response = await fetch(this.createBankUrlValue, {
        method: "POST",
        headers: this.requestHeaders(),
        credentials: "same-origin",
        body: JSON.stringify({ bank: { name: bankName } })
      })

      const payload = await this.responsePayload(response)
      if (!response.ok) {
        this.showSaveMessage(payload.errors?.join(", ") || payload.error || "Bank could not be saved.", "error")
        return
      }

      this.banks = [...this.banks, payload].sort((a, b) => a.name.localeCompare(b.name))
      this.newBankNameTarget.value = ""
      this.renderBanks(payload.name)
      this.refresh()
    } catch (error) {
      this.showSaveMessage(error.message || "Bank could not be saved.", "error")
    }
  }

  async saveAdvice() {
    if (this.currentRecordLocked()) {
      this.showSaveMessage("This advice was already mailed and cannot be edited.", "error")
      return
    }

    this.showSaveMessage("Saving...", "muted")

    try {
      await this.persistAdvice()
      this.showSaveMessage("Record saved successfully.", "success")
      this.activateView("preview")
    } catch (error) {
      this.showSaveMessage(error.message || "Record could not be saved.", "error")
    }
  }

  async removeRecord(event) {
    const recordId = event.currentTarget.dataset.recordId
    if (!recordId) return

    const record = this.records.find((item) => String(item.id) === String(recordId))
    if (!window.confirm(`Delete payment advice ${record?.advice_no || ""}?`)) return

    const response = await fetch(`/payment_advices/${recordId}`, {
      method: "DELETE",
      headers: this.requestHeaders(),
      credentials: "same-origin"
    })

    // Delete is allowed for admins only; anything but 204 means it stayed.
    if (response.status !== 204) {
      const payload = response.redirected ? {} : await response.json().catch(() => ({}))
      alert(payload.error || "Record could not be deleted. Only an admin can delete a payment advice.")
      return
    }

    this.records = this.records.filter((record) => String(record.id) !== String(recordId))
    if (String(this.currentRecordId) === String(recordId)) this.resetForm()
    this.renderRecords()
  }

  loadRecord(event) {
    const recordId = event.currentTarget.dataset.recordId
    const record = this.records.find((item) => String(item.id) === String(recordId))
    if (!record) return

    this.currentRecordId = record.id
    this.companyNameTarget.value = record.company_name || ""
    this.adviceNoTarget.value = record.advice_no || ""
    this.payeeNameTarget.value = record.payee_name || ""
    this.payeeEmailTarget.value = record.payee_email || ""
    this.ccEmailsTarget.value = record.cc_emails || ""
    this.bccEmailsTarget.value = record.bcc_emails || ""
    this.invoiceNoTarget.value = record.invoice_no || ""
    this.invoiceDateTarget.value = record.invoice_date || ""
    this.paymentModeTarget.value = record.payment_mode || "NEFT"
    this.referenceNoTarget.value = record.reference_no || ""
    this.grossAmountTarget.value = record.gross_amount || "0"
    this.tdsAmountTarget.value = record.tds_amount || "0"
    this.otherDeductionTarget.value = record.other_deduction || "0"
    this.paymentDateTarget.value = record.payment_date || ""
    this.remarksTarget.value = record.remarks || ""
    this.renderBanks(record.bank_name || this.bankSelectTarget.value)
    this.setMode(record)
    this.showSaveMessage("", "muted")
    this.refresh()
    this.activateView("advice")
  }

  viewRecord(event) {
    this.loadRecord(event)
    this.activateView("preview")
  }

  async removeBank(event) {
    const bankId = event.currentTarget.dataset.bankId
    const bankName = event.currentTarget.dataset.bankName

    if (!bankId || bankId.startsWith("default-")) return

    const response = await fetch(`/banks/${bankId}`, {
      method: "DELETE",
      headers: this.requestHeaders(),
      credentials: "same-origin"
    })

    if (!response.ok) return

    this.banks = this.banks.filter((bank) => String(bank.id) !== String(bankId))
    if (this.banks.length === 0) this.banks = DEFAULT_BANKS

    this.renderBanks(this.bankSelectTarget.value === bankName ? this.banks[0].name : this.bankSelectTarget.value)
    this.refresh()
  }

  resetForm(options = {}) {
    this.currentRecordId = null
    this.companyNameTarget.value = "Accounts Department"
    this.adviceNoTarget.value = this.nextAdviceNumber()
    this.payeeNameTarget.value = ""
    this.payeeEmailTarget.value = ""
    this.ccEmailsTarget.value = ""
    this.bccEmailsTarget.value = ""
    this.invoiceNoTarget.value = ""
    this.paymentModeTarget.value = "NEFT"
    this.referenceNoTarget.value = ""
    this.grossAmountTarget.value = "0"
    this.tdsAmountTarget.value = "0"
    this.otherDeductionTarget.value = "0"
    this.remarksTarget.value = ""
    this.renderBanks("HDFC Bank")
    this.setMode(null)
    if (!options.keepMessage) this.showSaveMessage("", "muted")
    this.refresh()
  }

  printAdvice() {
    window.print()
  }

  async sendMail() {
    const recipientEmail = this.payeeEmailTarget.value.trim()

    if (!recipientEmail) {
      alert("Recipient Email is required before sending mail.")
      this.activateView("advice")
      return
    }

    const locked = this.currentRecordLocked()
    let savedRecord

    if (locked) {
      // A mailed advice is final; it can only be sent again as it is.
      const record = this.currentRecord()
      if (!window.confirm(`This advice was already mailed on ${record.mail_sent_at}. Send the same mail again?`)) return
      savedRecord = record
    } else {
      this.showSaveMessage("Saving before mail...", "muted")
      try {
        savedRecord = await this.persistAdvice()
      } catch (error) {
        this.showSaveMessage(error.message || "Record could not be saved.", "error")
        alert(error.message || "Record could not be saved before sending mail.")
        this.activateView("advice")
        return
      }
    }

    this.sendButtonTarget.disabled = true
    this.showSaveMessage("Sending mail...", "muted")
    try {
      const response = await fetch(`/payment_advices/${savedRecord.id}/send_mail`, {
        method: "POST",
        headers: this.requestHeaders(),
        credentials: "same-origin",
        body: JSON.stringify(locked ? {} : { payment_advice: this.recordPayload() })
      })

      const payload = await this.responsePayload(response)
      const message = payload.message || payload.error || payload.errors?.join(", ") || "Mail request completed."
      if (payload.payment_advice) this.storeRecord(payload.payment_advice)
      this.showSaveMessage(message, response.ok ? "success" : "error")
      alert(message)
    } catch (error) {
      this.showSaveMessage(error.message || "Mail could not be sent.", "error")
      alert(error.message || "Mail could not be sent.")
    } finally {
      this.sendButtonTarget.disabled = false
    }
  }

  async persistAdvice() {
    const response = await fetch(this.createRecordUrlValue, {
      method: "POST",
      headers: this.requestHeaders(),
      credentials: "same-origin",
      body: JSON.stringify({ record_id: this.currentRecordId, payment_advice: this.recordPayload() })
    })

    const payload = await this.responsePayload(response)
    if (!response.ok) throw new Error(payload.errors?.join(", ") || payload.error || "Record could not be saved.")

    this.storeRecord(payload)
    this.nextAdviceNoValue = this.nextAdviceNumber()

    return payload
  }

  // Keeps the list, the form mode and the email suggestions in step with a saved record.
  storeRecord(record) {
    this.currentRecordId = record.id
    this.records = [record, ...this.records.filter((item) => String(item.id) !== String(record.id))]
    this.renderRecords()
    this.rememberEmails([record.payee_email, record.cc_emails, record.bcc_emails])
    this.setMode(record)
  }

  currentRecord() {
    return this.records.find((item) => String(item.id) === String(this.currentRecordId)) || null
  }

  currentRecordLocked() {
    return Boolean(this.currentRecord()?.mail_sent_at)
  }

  // New advice, editing a saved one, or a mailed (locked) one.
  setMode(record) {
    const locked = Boolean(record?.mail_sent_at)
    const banner = this.modeBannerTarget

    banner.hidden = !record
    banner.dataset.tone = locked ? "locked" : "editing"
    banner.textContent = !record ? "" : locked
      ? `${record.advice_no} was mailed on ${record.mail_sent_at}. It is locked and cannot be edited. Use New Advice to make another advice.`
      : `Editing saved advice ${record.advice_no}. Save Record keeps your changes.`

    this.element.querySelectorAll(".payment-advice-entry-panel input:not([type='hidden']), .payment-advice-entry-panel select, .payment-advice-entry-panel textarea")
      .forEach((field) => { field.disabled = locked })
    this.saveButtonTargets.forEach((button) => {
      button.disabled = locked
      button.title = locked ? "Mailed advice cannot be edited" : ""
    })
    this.sendButtonTarget.textContent = locked ? "Resend Mail" : "Send Mail"
  }

  renderBanks(selectedBank) {
    const selected = this.banks.some((bank) => bank.name === selectedBank) ? selectedBank : this.banks[0].name

    this.bankSelectTarget.replaceChildren(
      ...this.banks.map((bank) => new Option(bank.name, bank.name, bank.name === selected, bank.name === selected))
    )

    this.bankListTarget.replaceChildren(
      ...this.banks.map((bank) => {
        const item = document.createElement("div")
        const name = document.createElement("span")
        const button = document.createElement("button")

        item.className = "payment-advice-bank-item"
        name.textContent = bank.name
        button.type = "button"
        button.textContent = "Remove"
        button.dataset.action = "payment-advice#removeBank"
        button.dataset.bankId = bank.id
        button.dataset.bankName = bank.name

        item.append(name, button)
        return item
      })
    )

    this.bankCountTarget.textContent = `${this.banks.length} Banks`
  }

  renderRecords() {
    this.recordCountTarget.textContent = `${this.records.length} Records`

    if (this.records.length === 0) {
      const empty = document.createElement("div")
      empty.className = "payment-advice-empty-state"
      empty.textContent = "No saved payment advice records."
      this.recordListTarget.replaceChildren(empty)
      return
    }

    this.recordListTarget.replaceChildren(
      ...this.records.map((record) => {
        const item = document.createElement("div")
        const details = document.createElement("button")
        const actions = document.createElement("div")
        const view = document.createElement("button")
        const title = document.createElement("strong")
        const meta = document.createElement("span")
        const amount = document.createElement("b")
        const remove = document.createElement("button")

        item.className = "payment-advice-record-item"
        details.type = "button"
        details.className = "payment-advice-record-load"
        details.dataset.action = "payment-advice#loadRecord"
        details.dataset.recordId = record.id
        title.textContent = `${record.advice_no} - ${record.payee_name}`
        meta.textContent = `${record.invoice_no} | ${record.payee_email || "-"} | ${record.bank_name || "-"} | ${record.created_at}`
        amount.textContent = this.formatCurrency(this.numberValue(record.net_amount))
        const status = document.createElement("small")
        status.className = `payment-advice-record-status ${record.mail_sent_at ? "is-sent" : "is-draft"}`
        status.textContent = record.mail_sent_at ? `Mail sent · ${record.mail_sent_at} · Locked` : "Not mailed yet · Editable"
        details.append(title, meta, status, amount)

        actions.className = "payment-advice-record-actions"
        view.type = "button"
        view.className = "payment-advice-record-view"
        view.textContent = "View"
        view.dataset.action = "payment-advice#viewRecord"
        view.dataset.recordId = record.id

        remove.type = "button"
        remove.className = "payment-advice-record-remove"
        remove.textContent = "Delete"
        remove.dataset.action = "payment-advice#removeRecord"
        remove.dataset.recordId = record.id

        if (record.mail_sent_at) {
          actions.classList.add("is-locked")
          actions.append(view)
        } else {
          const edit = document.createElement("button")
          edit.type = "button"
          edit.className = "payment-advice-record-edit"
          edit.textContent = "Edit"
          edit.dataset.action = "payment-advice#loadRecord"
          edit.dataset.recordId = record.id
          actions.append(view, edit)
          if (this.canDeleteValue) actions.append(remove)
        }
        item.append(details, actions)
        return item
      })
    )
  }

  recordPayload() {
    return {
      company_name: this.companyNameTarget.value,
      advice_no: this.adviceNoTarget.value,
      payee_name: this.payeeNameTarget.value,
      payee_email: this.payeeEmailTarget.value,
      cc_emails: this.ccEmailsTarget.value,
      bcc_emails: this.bccEmailsTarget.value,
      invoice_no: this.invoiceNoTarget.value,
      invoice_date: this.invoiceDateTarget.value,
      gross_amount: this.grossAmountTarget.value,
      tds_amount: this.tdsAmountTarget.value,
      other_deduction: this.otherDeductionTarget.value,
      payment_mode: this.paymentModeTarget.value,
      reference_no: this.referenceNoTarget.value,
      bank_name: this.bankSelectTarget.value,
      payment_date: this.paymentDateTarget.value,
      remarks: this.remarksTarget.value
    }
  }

  showSaveMessage(message, tone) {
    this.saveMessageTarget.textContent = message
    this.saveMessageTarget.dataset.tone = tone
  }

  nextAdviceNumber() {
    const numbers = this.records.map((record) => this.sequentialNumber(record.advice_no)).filter(Boolean)
    const currentNumber = this.sequentialNumber(this.nextAdviceNoValue)
    const nextNumber = Math.max(0, currentNumber - 1, ...numbers) + 1

    return `PA-${this.adviceYear()}-${String(nextNumber).padStart(3, "0")}`
  }

  // The year of the numbers the server hands out (PA-<year>-001).
  adviceYear() {
    return String(this.nextAdviceNoValue || "").match(/^PA-(\d{4})-/)?.[1] || String(new Date().getFullYear())
  }

  sequentialNumber(adviceNo) {
    const match = String(adviceNo || "").match(new RegExp(`^PA-${this.adviceYear()}-(\\d{3,})$`))
    return match ? Number.parseInt(match[1], 10) : 0
  }

  // Email suggestions: addresses used before, offered under To / CC / BCC.
  setupEmailSuggestions() {
    this.knownEmails = []
    this.rememberEmails(this.usedEmailsValue)
    this.rememberEmails(this.records.flatMap((record) => [record.payee_email, record.cc_emails, record.bcc_emails]))

    this.element.querySelectorAll("[data-email-list]").forEach((input) => {
      const box = document.createElement("div")
      box.className = "payment-advice-email-suggest"
      box.hidden = true
      box.setAttribute("role", "listbox")
      input.insertAdjacentElement("afterend", box)
      input.emailSuggest = box

      input.addEventListener("focus", () => this.showEmailSuggestions(input))
      input.addEventListener("input", () => this.showEmailSuggestions(input))
      input.addEventListener("blur", () => setTimeout(() => { box.hidden = true }, 150))
      input.addEventListener("keydown", (event) => this.emailSuggestKey(event, input))
    })
  }

  rememberEmails(values) {
    const seen = new Set(this.knownEmails.map((email) => email.toLowerCase()))
    values.flatMap((value) => String(value || "").split(/[,;\s]+/)).map((email) => email.trim()).filter(Boolean).forEach((email) => {
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || seen.has(email.toLowerCase())) return
      seen.add(email.toLowerCase())
      this.knownEmails.push(email)
    })
  }

  showEmailSuggestions(input) {
    const box = input.emailSuggest
    if (!box || input.disabled) return

    const parts = input.value.split(",")
    const typed = parts[parts.length - 1].trim().toLowerCase()
    const chosen = new Set(parts.slice(0, -1).map((part) => part.trim().toLowerCase()))
    const matches = this.knownEmails
      .filter((email) => !chosen.has(email.toLowerCase()) && email.toLowerCase() !== typed && email.toLowerCase().includes(typed))
      .slice(0, 8)

    box.replaceChildren(...matches.map((email, index) => {
      const option = document.createElement("button")
      option.type = "button"
      option.className = `payment-advice-email-option${index === 0 ? " is-active" : ""}`
      option.setAttribute("role", "option")
      option.textContent = email
      option.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.pickEmail(input, email)
      })
      return option
    }))
    box.hidden = matches.length === 0
  }

  emailSuggestKey(event, input) {
    const box = input.emailSuggest
    if (!box || box.hidden) return

    const options = [...box.children]
    const current = options.findIndex((option) => option.classList.contains("is-active"))
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const next = (current + (event.key === "ArrowDown" ? 1 : -1) + options.length) % options.length
      options.forEach((option, index) => option.classList.toggle("is-active", index === next))
    } else if (event.key === "Enter" && current >= 0) {
      event.preventDefault()
      this.pickEmail(input, options[current].textContent)
    } else if (event.key === "Escape") {
      box.hidden = true
    }
  }

  pickEmail(input, email) {
    const parts = input.value.split(",").slice(0, -1).map((part) => part.trim()).filter(Boolean)
    input.value = [...parts, email].join(", ") + ", "
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.focus()
    input.emailSuggest.hidden = true
  }

  activateInitialView() {
    const viewByHash = {
      "#advice-form": "advice",
      "#bank-master": "banks",
      "#payment-preview": "preview",
      "#saved-records": "records"
    }

    this.activateView(viewByHash[window.location.hash] || "advice")
  }

  activateView(view) {
    const panel = this.panelTargets.find((item) => item.dataset.view === view)
    if (!panel) return

    this.navItemTargets.forEach((item) => item.classList.toggle("active", item.dataset.view === view))
    this.panelTargets.forEach((item) => item.classList.toggle("active", item.dataset.view === view))
    window.history.replaceState(null, "", `#${panel.id}`)
  }

  requestHeaders() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
    }
  }

  async responsePayload(response) {
    const contentType = response.headers.get("content-type") || ""
    if (contentType.includes("application/json")) return response.json()

    if (response.redirected) throw new Error("Session expired. Please refresh and login again.")

    const text = await response.text()
    throw new Error(text.trim() || "Unexpected server response.")
  }

  numberValue(value) {
    return Number.parseFloat(value) || 0
  }

  fallback(value, fallback) {
    return value.trim() || fallback
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      minimumFractionDigits: 2
    }).format(value)
  }

  formatDate(value) {
    if (!value) return "-"

    return new Intl.DateTimeFormat("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric"
    }).format(new Date(`${value}T00:00:00`))
  }
}
