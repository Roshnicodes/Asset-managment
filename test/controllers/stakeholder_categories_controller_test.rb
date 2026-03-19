require "test_helper"

class StakeholderCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @stakeholder_category = stakeholder_categories(:one)
  end

  test "should get index" do
    get stakeholder_categories_url
    assert_response :success
  end

  test "should get new" do
    get new_stakeholder_category_url
    assert_response :success
  end

  test "should create stakeholder_category" do
    assert_difference("StakeholderCategory.count") do
      post stakeholder_categories_url, params: { stakeholder_category: { name: @stakeholder_category.name, office_category_id: @stakeholder_category.office_category_id } }
    end

    assert_redirected_to stakeholder_category_url(StakeholderCategory.last)
  end

  test "should show stakeholder_category" do
    get stakeholder_category_url(@stakeholder_category)
    assert_response :success
  end

  test "should get edit" do
    get edit_stakeholder_category_url(@stakeholder_category)
    assert_response :success
  end

  test "should update stakeholder_category" do
    patch stakeholder_category_url(@stakeholder_category), params: { stakeholder_category: { name: @stakeholder_category.name, office_category_id: @stakeholder_category.office_category_id } }
    assert_redirected_to stakeholder_category_url(@stakeholder_category)
  end

  test "should destroy stakeholder_category" do
    assert_difference("StakeholderCategory.count", -1) do
      delete stakeholder_category_url(@stakeholder_category)
    end

    assert_redirected_to stakeholder_categories_url
  end
end
