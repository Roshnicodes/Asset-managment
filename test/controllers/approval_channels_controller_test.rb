require "test_helper"

class ApprovalChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @approval_channel = approval_channels(:one)
  end

  test "should get index" do
    get approval_channels_url
    assert_response :success
  end

  test "should get new" do
    get new_approval_channel_url
    assert_response :success
  end

  test "should create approval_channel" do
    assert_difference("ApprovalChannel.count") do
      post approval_channels_url, params: { approval_channel: { approval_type: @approval_channel.approval_type, form_name: @approval_channel.form_name, level_1_approver: @approval_channel.level_1_approver, level_2_approver: @approval_channel.level_2_approver, level_3_approver: @approval_channel.level_3_approver } }
    end

    assert_redirected_to approval_channel_url(ApprovalChannel.last)
  end

  test "should show approval_channel" do
    get approval_channel_url(@approval_channel)
    assert_response :success
  end

  test "should get edit" do
    get edit_approval_channel_url(@approval_channel)
    assert_response :success
  end

  test "should update approval_channel" do
    patch approval_channel_url(@approval_channel), params: { approval_channel: { approval_type: @approval_channel.approval_type, form_name: @approval_channel.form_name, level_1_approver: @approval_channel.level_1_approver, level_2_approver: @approval_channel.level_2_approver, level_3_approver: @approval_channel.level_3_approver } }
    assert_redirected_to approval_channel_url(@approval_channel)
  end

  test "should destroy approval_channel" do
    assert_difference("ApprovalChannel.count", -1) do
      delete approval_channel_url(@approval_channel)
    end

    assert_redirected_to approval_channels_url
  end
end
