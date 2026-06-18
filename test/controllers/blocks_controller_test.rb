require "test_helper"

class BlocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @block = blocks(:one)
  end

  test "should get index" do
    get blocks_url
    assert_response :success
  end

  test "should get new" do
    get new_block_url
    assert_response :success
  end

  test "should create block" do
    assert_difference("Block.count") do
      post blocks_url, params: { block: { district_id: @block.district_id, name: @block.name } }
    end

    assert_redirected_to blocks_url
  end

  test "should show block" do
    get block_url(@block)
    assert_response :success
  end

  test "should get edit" do
    get edit_block_url(@block)
    assert_response :success
  end

  test "should update block" do
    patch block_url(@block), params: { block: { district_id: @block.district_id, name: @block.name } }
    assert_redirected_to blocks_url
  end

  test "should destroy block" do
    block = Block.create!(name: "Unused Block", district: districts(:one))

    assert_difference("Block.count", -1) do
      delete block_url(block)
    end

    assert_redirected_to blocks_url
  end

  test "should not crash when destroying block used by another record" do
    assert_no_difference("Block.count") do
      delete block_url(@block)
    end

    assert_redirected_to blocks_url
    assert_match "Cannot delete", flash[:alert]
  end
end
