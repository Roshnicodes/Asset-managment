require "test_helper"

class DocumentMastersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document_master = document_masters(:one)
  end

  test "should get index" do
    get document_masters_url
    assert_response :success
  end

  test "should get new" do
    get new_document_master_url
    assert_response :success
  end

  test "should create document_master" do
    assert_difference("DocumentMaster.count") do
      post document_masters_url, params: { document_master: { name: @document_master.name } }
    end

    assert_redirected_to document_master_url(DocumentMaster.last)
  end

  test "should show document_master" do
    get document_master_url(@document_master)
    assert_response :success
  end

  test "should get edit" do
    get edit_document_master_url(@document_master)
    assert_response :success
  end

  test "should update document_master" do
    patch document_master_url(@document_master), params: { document_master: { name: @document_master.name } }
    assert_redirected_to document_master_url(@document_master)
  end

  test "should destroy document_master" do
    assert_difference("DocumentMaster.count", -1) do
      delete document_master_url(@document_master)
    end

    assert_redirected_to document_masters_url
  end
end
