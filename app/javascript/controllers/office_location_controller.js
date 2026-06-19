import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "district", "block"]
  static values = { districts: Array, blocks: Array }

  connect() {
    this.renderDistricts()
    this.renderBlocks()
  }

  stateChanged() {
    this.renderDistricts()
    this.renderBlocks()
  }

  districtChanged() {
    this.renderBlocks()
  }

  renderDistricts() {
    const stateId = this.stateTarget.value
    const selectedDistrictId = this.districtTarget.value
    const districts = stateId
      ? this.districtsValue.filter((district) => String(district.state_id) === stateId)
      : []

    this.populateSelect(this.districtTarget, districts, selectedDistrictId, "Select district")
  }

  renderBlocks() {
    const districtId = this.districtTarget.value
    const selectedBlockId = this.blockTarget.value

    const blocks = districtId
      ? this.blocksValue.filter((block) => String(block.district_id) === districtId)
      : []

    this.populateSelect(this.blockTarget, blocks, selectedBlockId, "Select block")
  }

  populateSelect(select, items, selectedValue, promptText) {
    const promptOption = new Option(promptText, "")
    select.innerHTML = ""
    select.add(promptOption)

    let matchedSelection = false

    items.forEach((item) => {
      const option = new Option(item.name, item.id)

      if (String(item.id) === String(selectedValue)) {
        option.selected = true
        matchedSelection = true
      }

      select.add(option)
    })

    if (!matchedSelection) {
      select.value = ""
    }
  }
}
