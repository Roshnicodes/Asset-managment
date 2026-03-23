class To < ApplicationRecord
  belongs_to :fco

  delegate :block, to: :fco, allow_nil: true
  delegate :district, :state, to: :fco
end
