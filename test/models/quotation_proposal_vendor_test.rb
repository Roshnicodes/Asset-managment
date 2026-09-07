require "test_helper"
require "ostruct"

class QuotationProposalVendorTest < ActiveSupport::TestCase
  LoadedCriteriaScoreCollection = Struct.new(:records, keyword_init: true) do
    include Enumerable

    def loaded?
      true
    end

    def each(&block)
      records.each(&block)
    end
  end

  test "criteria_scores_for returns saved marks keyed by criterion selection" do
    vendor = QuotationProposalVendor.new
    employee = OpenStruct.new(id: 7)
    collection = LoadedCriteriaScoreCollection.new(
      records: [
        OpenStruct.new(employee_master_id: 7, quotation_proposal_criteria_selection_id: 11, score: 8),
        OpenStruct.new(employee_master_id: 7, quotation_proposal_criteria_selection_id: 12, score: 6),
        OpenStruct.new(employee_master_id: 9, quotation_proposal_criteria_selection_id: 11, score: 9)
      ]
    )

    vendor.define_singleton_method(:committee_criteria_scores) { collection }

    assert_equal({ 11 => 8, 12 => 6 }, vendor.criteria_scores_for(employee))
    assert_equal [11, 12], vendor.checked_criteria_selection_ids_for(employee)
  end

  test "criteria_score_totals_for_selection_ids sums marks criterion wise" do
    vendor = QuotationProposalVendor.new
    collection = LoadedCriteriaScoreCollection.new(
      records: [
        OpenStruct.new(employee_master_id: 7, quotation_proposal_criteria_selection_id: 11, score: 8),
        OpenStruct.new(employee_master_id: 8, quotation_proposal_criteria_selection_id: 11, score: 7),
        OpenStruct.new(employee_master_id: 7, quotation_proposal_criteria_selection_id: 12, score: 6)
      ]
    )

    vendor.define_singleton_method(:committee_criteria_scores) { collection }

    assert_equal({ 11 => 15, 12 => 6 }, vendor.criteria_score_totals_for_selection_ids([11, 12]))
  end

  test "missing_committee_score_members returns members without completed scores" do
    vendor = QuotationProposalVendor.new
    members = [
      OpenStruct.new(id: 7, name: "Aaditya"),
      OpenStruct.new(id: 8, name: "Anamika"),
      OpenStruct.new(id: 9, name: "Bhavesh")
    ]
    collection = LoadedCriteriaScoreCollection.new(
      records: [
        OpenStruct.new(employee_master_id: 7, score: 8),
        OpenStruct.new(employee_master_id: 8, score: nil)
      ]
    )

    vendor.define_singleton_method(:committee_member_scores) { collection }

    assert_equal [members[1], members[2]], vendor.missing_committee_score_members(members)
  end

  test "remark helpers expose saved committee remarks" do
    vendor = QuotationProposalVendor.new
    employee = OpenStruct.new(id: 7)
    collection = LoadedCriteriaScoreCollection.new(
      records: [
        OpenStruct.new(employee_master_id: 7, quotation_proposal_criteria_selection_id: 11, score: 8, remark: "Strong warranty support", employee_master: OpenStruct.new(name: "Aaditya")),
        OpenStruct.new(employee_master_id: 8, quotation_proposal_criteria_selection_id: 12, score: 6, remark: "", employee_master: OpenStruct.new(name: "Anamika"))
      ]
    )

    vendor.define_singleton_method(:committee_criteria_scores) { collection }
    vendor.define_singleton_method(:committee_member_scores) do
      [
        OpenStruct.new(employee_master_id: 7, score: 8, remark: "Strong warranty support", employee_master: OpenStruct.new(name: "Aaditya")),
        OpenStruct.new(employee_master_id: 8, score: 6, remark: "", employee_master: OpenStruct.new(name: "Anamika"))
      ]
    end

    assert_equal "Strong warranty support", vendor.remark_for(employee)
    assert_equal [["Aaditya", "Strong warranty support"]], vendor.score_remarks
  end
end
