class BanksController < ApplicationController
  before_action :require_payment_advice_studio_access!
  before_action :set_bank, only: :destroy

  def create
    bank = Bank.create(bank_params)

    if bank.persisted?
      render json: bank_payload(bank), status: :created
    else
      render json: { errors: bank.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @bank.destroy

    head :no_content
  end

  private

  def set_bank
    @bank = Bank.find(params[:id])
  end

  def bank_params
    params.expect(bank: %i[name])
  end

  def bank_payload(bank)
    { id: bank.id, name: bank.name }
  end
end
