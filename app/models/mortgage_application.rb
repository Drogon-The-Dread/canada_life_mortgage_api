class MortgageApplication < ApplicationRecord
  validates :annual_income, :monthly_expenses, :deposit_amount, :property_value, :term_years,
            presence: true
  validates :annual_income, :monthly_expenses, :deposit_amount, :property_value,
            numericality: { greater_than: 0 }, allow_blank: true
  validates :term_years,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 40 },
            allow_blank: true

  validate :deposit_below_property_value
  validate :expenses_below_monthly_income

  private

  def deposit_below_property_value
    return unless deposit_amount && property_value
    errors.add(:deposit_amount, "must be less than property value") if deposit_amount >= property_value
  end

  def expenses_below_monthly_income
    return unless monthly_expenses && annual_income
    errors.add(:monthly_expenses, "must be less than monthly income") if monthly_expenses >= annual_income / 12.0
  end
end
