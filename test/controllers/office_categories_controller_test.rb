require "test_helper"

class OfficeCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @office_category = office_categories(:one)
  end

  test "should get index" do
    get office_categories_url
    assert_response :success
  end

  test "should get new" do
    get new_office_category_url
    assert_response :success
  end

  test "should create office_category" do
    assert_difference("OfficeCategory.count") do
      post office_categories_url, params: { office_category: { name: @office_category.name, office_level: @office_category.office_level, parent_id: @office_category.parent_id } }
    end

    assert_redirected_to office_category_url(OfficeCategory.last)
  end

  test "should show office_category" do
    get office_category_url(@office_category)
    assert_response :success
  end

  test "should get edit" do
    get edit_office_category_url(@office_category)
    assert_response :success
  end

  test "should update office_category" do
    patch office_category_url(@office_category), params: { office_category: { name: @office_category.name, office_level: @office_category.office_level, parent_id: @office_category.parent_id } }
    assert_redirected_to office_category_url(@office_category)
  end

  test "should destroy office_category" do
    assert_difference("OfficeCategory.count", -1) do
      delete office_category_url(@office_category)
    end

    assert_redirected_to office_categories_url
  end
end
