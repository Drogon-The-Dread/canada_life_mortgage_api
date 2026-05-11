require "test_helper"

class AffordabilityCalculatorTest < ActiveSupport::TestCase
  # Baseline: LTV 83.3%, DTI 22.5%, loan 250k < max 360k → approved
  BASE_ATTRS = {
    annual_income:    80_000,
    monthly_expenses: 1_500,
    deposit_amount:   50_000,
    property_value:   300_000,
    term_years:       25
  }.freeze

  def application(overrides = {})
    MortgageApplication.new(BASE_ATTRS.merge(overrides))
  end

  def result(overrides = {})
    AffordabilityCalculator.new(application(overrides)).call
  end

  # --- Calculation accuracy ---

  test "loan amount is property value minus deposit" do
    assert_in_delta 250_000, result[:loan_amount], 0.01
  end

  test "LTV is loan divided by property value as a percentage" do
    # 250_000 / 300_000 * 100 = 83.33
    assert_in_delta 83.33, result[:loan_to_value], 0.01
  end

  test "DTI is monthly expenses divided by monthly income as a percentage" do
    # 1_500 / (80_000 / 12) * 100 = 22.5
    assert_in_delta 22.5, result[:debt_to_income_ratio], 0.01
  end

  test "max borrowing is 4.5 times annual income" do
    assert_in_delta 360_000, result[:max_borrowing], 0.01
  end

  test "monthly repayment is a positive number" do
    assert result[:monthly_repayment] > 0
  end

  # --- Decision logic ---

  test "approved when all three criteria are met" do
    assert_equal "approved", result[:decision]
  end

  test "declined when LTV exceeds 90 percent" do
    # deposit 5k on 100k property → LTV 95%
    r = result(annual_income: 80_000, monthly_expenses: 1_500,
                deposit_amount: 5_000, property_value: 100_000, term_years: 25)
    assert_equal "declined", r[:decision]
    assert_includes r[:explanation], "LTV"
  end

  test "declined when DTI exceeds 43 percent" do
    # expenses 2_500, income 60k → monthly income 5k → DTI 50%
    # LTV: 250k/300k = 83.3% ok; max_borrowing: 60k*4.5=270k > 250k ok
    r = result(annual_income: 60_000, monthly_expenses: 2_500,
                deposit_amount: 50_000, property_value: 300_000, term_years: 25)
    assert_equal "declined", r[:decision]
    assert_includes r[:explanation], "DTI"
  end

  test "declined when loan exceeds maximum borrowing" do
    # loan 400k; max_borrowing 60k*4.5=270k; LTV 400/500=80% ok; DTI 1k/5k=20% ok
    r = result(annual_income: 60_000, monthly_expenses: 1_000,
                deposit_amount: 100_000, property_value: 500_000, term_years: 25)
    assert_equal "declined", r[:decision]
    assert_includes r[:explanation], "maximum borrowing"
  end

  # --- Explanation copy ---

  test "approved explanation references monthly repayment" do
    assert_includes result[:explanation], "Monthly repayment"
  end

  test "declined explanation describes the reason" do
    r = result(deposit_amount: 5_000, property_value: 100_000)
    assert_includes r[:explanation], "declined"
  end
end
