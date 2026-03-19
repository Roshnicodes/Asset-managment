require "test_helper"

class RegistrationTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @registration_type = registration_types(:one)
  end

  test "should get index" do
    get registration_types_url
    assert_response :success
  end

  test "should get new" do
    get new_registration_type_url
    assert_response :success
  end

  test "should create registration_type" do
    assert_difference("RegistrationType.count") do
      post registration_types_url, params: { registration_type: { name: @registration_type.name } }
    end

    assert_redirected_to registration_type_url(RegistrationType.last)
  end

  test "should show registration_type" do
    get registration_type_url(@registration_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_registration_type_url(@registration_type)
    assert_response :success
  end

  test "should update registration_type" do
    patch registration_type_url(@registration_type), params: { registration_type: { name: @registration_type.name } }
    assert_redirected_to registration_type_url(@registration_type)
  end

  test "should destroy registration_type" do
    assert_difference("RegistrationType.count", -1) do
      delete registration_type_url(@registration_type)
    end

    assert_redirected_to registration_types_url
  end
end
