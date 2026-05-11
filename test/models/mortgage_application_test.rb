require "test_helper"

class MortgageApplicationTest < ActiveSupport::TestCase
  VALID_ATTRS = {
    annual_income:    60_000,
    monthly_expenses: 1_500,
    deposit_amount:   40_000,
    property_value:   250_000,
    term_years:       25
  }.freeze

  def build(overrides = {})
    MortgageApplication.new(VALID_ATTRS.merge(overrides))
  end

  # --- Happy path ---

  test "valid with all required attributes" do
    assert build.valid?
  end

  # --- Presence validations ---

  %i[annual_income monthly_expenses deposit_amount property_value term_years].each do |field|
    test "invalid without #{field}" do
      record = build(field => nil)
      refute record.valid?
      assert record.errors[field].any?
    end
  end

  # --- Numericality: must be positive ---

  %i[annual_income monthly_expenses deposit_amount property_value].each do |field|
    test "invalid when #{field} is zero" do
      refute build(field => 0).valid?
    end

    test "invalid when #{field} is negative" do
      refute build(field => -1).valid?
    end
  end

  # --- Term years constraints ---

  test "invalid when term_years is zero" do
    refute build(term_years: 0).valid?
  end

  test "invalid when term_years is 41" do
    refute build(term_years: 41).valid?
  end

  test "valid when term_years is 40" do
    assert build(term_years: 40).valid?
  end

  # --- Cross-field: deposit vs property value ---

  test "invalid when deposit equals property value" do
    record = build(deposit_amount: 250_000, property_value: 250_000)
    refute record.valid?
    assert record.errors[:deposit_amount].any?
  end

  test "invalid when deposit exceeds property value" do
    refute build(deposit_amount: 300_000, property_value: 250_000).valid?
  end

  # --- Cross-field: expenses vs income ---

  test "invalid when monthly expenses equal monthly income" do
    # annual_income 60_000 → monthly 5_000; expenses at 5_000 → invalid
    record = build(annual_income: 60_000, monthly_expenses: 5_000)
    refute record.valid?
    assert record.errors[:monthly_expenses].any?
  end

  test "invalid when monthly expenses exceed monthly income" do
    record = build(annual_income: 60_000, monthly_expenses: 6_000)
    refute record.valid?
  end
end
