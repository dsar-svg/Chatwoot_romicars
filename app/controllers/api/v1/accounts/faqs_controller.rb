# frozen_string_literal: true

class Api::V1::Accounts::FaqsController < Api::V1::Accounts::BaseController
  before_action :fetch_faq, only: [:show, :update, :destroy]

  def index
    @faqs = Current.account.faqs
                    .by_search(params[:search])
                    .by_category(params[:category])
                    .ordered
  end

  def show; end

  def create
    @faq = Current.account.faqs.new(faq_params)
    @faq.save!
    render :show
  end

  def update
    @faq.update!(faq_params)
    render :show
  end

  def destroy
    @faq.destroy!
    head :ok
  end

  private

  def fetch_faq
    @faq = Current.account.faqs.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:question, :answer, :category, :keywords, :active, :priority)
  end
end
