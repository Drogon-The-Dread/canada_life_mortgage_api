module Api
  module V1
    class MortgageApplicationsController < ApplicationController
      def create
        application = MortgageApplication.new(application_params)

        if application.save
          render json: application, status: :created
        else
          render json: { errors: application.errors }, status: :unprocessable_entity
        end
      end

      def show
        render json: find_application
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mortgage application not found" }, status: :not_found
      end

      def assessment
        result = AffordabilityCalculator.new(find_application).call
        render json: result
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Mortgage application not found" }, status: :not_found
      end

      private

      def find_application
        MortgageApplication.find(params[:id])
      end

      def application_params
        params.require(:mortgage_application).permit(
          :annual_income, :monthly_expenses, :deposit_amount, :property_value, :term_years
        )
      end
    end
  end
end
