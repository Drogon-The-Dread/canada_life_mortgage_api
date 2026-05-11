class AffordabilityCalculator
  LTV_THRESHOLD    = 90.0
  DTI_THRESHOLD    = 43.0
  INCOME_MULTIPLE  = 4.5
  ANNUAL_RATE      = 0.05

  def initialize(application)
    @application = application
  end

  def call
    {
      loan_amount:          loan_amount.round(2),
      loan_to_value:        ltv.round(2),
      debt_to_income_ratio: dti.round(2),
      max_borrowing:        max_borrowing.round(2),
      monthly_repayment:    monthly_repayment.round(2),
      decision:             decision,
      explanation:          explanation
    }
  end

  private

  def loan_amount
    @loan_amount ||= @application.property_value - @application.deposit_amount
  end

  def ltv
    @ltv ||= (loan_amount / @application.property_value) * 100
  end

  def monthly_income
    @monthly_income ||= @application.annual_income / 12.0
  end

  def dti
    @dti ||= (@application.monthly_expenses / monthly_income) * 100
  end

  def max_borrowing
    @max_borrowing ||= @application.annual_income * INCOME_MULTIPLE
  end

  # Standard amortisation formula: P × [r(1+r)^n] / [(1+r)^n - 1]
  # Assumes 5% fixed annual rate for simplicity — no external rate API dependency.
  def monthly_repayment
    r = ANNUAL_RATE / 12.0
    n = @application.term_years * 12
    loan_amount * (r * (1 + r)**n) / ((1 + r)**n - 1)
  end

  def approved?
    ltv <= LTV_THRESHOLD && dti <= DTI_THRESHOLD && loan_amount <= max_borrowing
  end

  def decision
    approved? ? "approved" : "declined"
  end

  def explanation
    if approved?
      "Application approved. Monthly repayment estimated at £#{monthly_repayment.round(2)} " \
        "over #{@application.term_years} years at 5% fixed rate."
    else
      reasons = []
      reasons << "LTV of #{ltv.round(1)}% exceeds the 90% threshold" if ltv > LTV_THRESHOLD
      reasons << "DTI of #{dti.round(1)}% exceeds the 43% threshold" if dti > DTI_THRESHOLD
      reasons << "Loan of £#{loan_amount.round} exceeds maximum borrowing of £#{max_borrowing.round}" if loan_amount > max_borrowing
      "Application declined. #{reasons.join('. ')}."
    end
  end
end
