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
    createRecordUrl: String
  }

  static targets = [
    "navItem", "panel",
    "companyName", "adviceNo", "payeeName", "payeeEmail", "invoiceNo", "invoiceDate",
    "paymentMode", "referenceNo", "bankSelect", "paymentDate", "grossAmount", "tdsAmount",
    "otherDeduction", "remarks", "newBankName", "bankList", "bankCount", "netPreview",
    "recordList", "recordCount", "saveMessage",
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
    this.showSaveMessage("Saving...", "muted")

    try {
      const response = await fetch(this.createRecordUrlValue, {
        method: "POST",
        headers: this.requestHeaders(),
        credentials: "same-origin",
        body: JSON.stringify({ payment_advice: this.recordPayload() })
      })

      const payload = await this.responsePayload(response)
      if (!response.ok) {
        this.showSaveMessage(payload.errors?.join(", ") || payload.error || "Record could not be saved.", "error")
        return
      }

      this.currentRecordId = payload.id
      this.records = [payload, ...this.records.filter((item) => item.id !== payload.id)]
      this.renderRecords()
      this.nextAdviceNoValue = this.nextAdviceNumber()
      this.showSaveMessage("Record saved successfully.", "success")
      this.activateView("preview")
    } catch (error) {
      this.showSaveMessage(error.message || "Record could not be saved.", "error")
    }
  }

  async removeRecord(event) {
    const recordId = event.currentTarget.dataset.recordId
    if (!recordId) return

    const response = await fetch(`/payment_advices/${recordId}`, {
      method: "DELETE",
      headers: this.requestHeaders(),
      credentials: "same-origin"
    })

    if (!response.ok) return

    this.records = this.records.filter((record) => String(record.id) !== String(recordId))
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
    this.invoiceNoTarget.value = ""
    this.paymentModeTarget.value = "NEFT"
    this.referenceNoTarget.value = ""
    this.grossAmountTarget.value = "0"
    this.tdsAmountTarget.value = "0"
    this.otherDeductionTarget.value = "0"
    this.remarksTarget.value = ""
    this.renderBanks("HDFC Bank")
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

    if (!this.currentRecordId) {
      alert("Please save the record first, then open it from Saved Records to send mail.")
      this.activateView("advice")
      return
    }

    const response = await fetch(`/payment_advices/${this.currentRecordId}/send_mail`, {
      method: "POST",
      headers: this.requestHeaders(),
      credentials: "same-origin"
    })

    const payload = await this.responsePayload(response)
    alert(payload.message || payload.error || "Mail request completed.")
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
        meta.textContent = `${record.invoice_no} | ${record.bank_name || "-"} | ${record.created_at}`
        amount.textContent = this.formatCurrency(this.numberValue(record.net_amount))
        details.append(title, meta, amount)

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

        actions.append(view, remove)
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

    return `PA-2026-${String(nextNumber).padStart(3, "0")}`
  }

  sequentialNumber(adviceNo) {
    const match = String(adviceNo || "").match(/^PA-2026-(\d{3})$/)
    return match ? Number.parseInt(match[1], 10) : 0
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
