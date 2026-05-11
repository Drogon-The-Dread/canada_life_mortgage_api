class CreateMortgageApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :mortgage_applications do |t|
      t.decimal :annual_income,    null: false, precision: 15, scale: 2
      t.decimal :monthly_expenses, null: false, precision: 15, scale: 2
      t.decimal :deposit_amount,   null: false, precision: 15, scale: 2
      t.decimal :property_value,   null: false, precision: 15, scale: 2
      t.integer :term_years,       null: false

      t.timestamps
    end
  end
end
