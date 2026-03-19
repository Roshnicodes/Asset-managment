require "test_helper"

class ProductVarietiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variety = product_varieties(:one)
  end

  test "should get index" do
    get product_varieties_url
    assert_response :success
  end

  test "should get new" do
    get new_product_variety_url
    assert_response :success
  end

  test "should create product_variety" do
    assert_difference("ProductVariety.count") do
      post product_varieties_url, params: { product_variety: { name: @product_variety.name, product_id: @product_variety.product_id } }
    end

    assert_redirected_to product_variety_url(ProductVariety.last)
  end

  test "should show product_variety" do
    get product_variety_url(@product_variety)
    assert_response :success
  end

  test "should get edit" do
    get edit_product_variety_url(@product_variety)
    assert_response :success
  end

  test "should update product_variety" do
    patch product_variety_url(@product_variety), params: { product_variety: { name: @product_variety.name, product_id: @product_variety.product_id } }
    assert_redirected_to product_variety_url(@product_variety)
  end

  test "should destroy product_variety" do
    assert_difference("ProductVariety.count", -1) do
      delete product_variety_url(@product_variety)
    end

    assert_redirected_to product_varieties_url
  end
end
