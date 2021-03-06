# frozen_string_literal: true

class SnippetsController < Snippets::ApplicationController
  include SnippetsActions
  include PreviewMarkdown
  include ToggleAwardEmoji
  include SpammableActions

  before_action :snippet, only: [:show, :edit, :destroy, :update, :raw, :toggle_award_emoji, :mark_as_spam]

  before_action :authorize_create_snippet!, only: [:new, :create]
  before_action :authorize_read_snippet!, only: [:show, :raw]
  before_action :authorize_update_snippet!, only: [:edit, :update]
  before_action :authorize_admin_snippet!, only: [:destroy]

  skip_before_action :authenticate_user!, only: [:index, :show, :raw]

  layout 'snippets'

  def index
    if params[:username].present?
      @user = UserFinder.new(params[:username]).find_by_username!

      @snippets = SnippetsFinder.new(current_user, author: @user, scope: params[:scope])
        .execute
        .page(params[:page])
        .inc_author

      return if redirect_out_of_range(@snippets)

      @noteable_meta_data = noteable_meta_data(@snippets, 'Snippet')

      render 'index'
    else
      redirect_to(current_user ? dashboard_snippets_path : explore_snippets_path)
    end
  end

  def new
    @snippet = PersonalSnippet.new
  end

  def create
    create_params = snippet_params.merge(files: params.delete(:files))
    service_response = Snippets::CreateService.new(nil, current_user, create_params).execute
    @snippet = service_response.payload[:snippet]

    if service_response.error? && @snippet.errors[:repository].present?
      handle_repository_error(:new)
    else
      recaptcha_check_with_fallback { render :new }
    end
  end

  protected

  alias_method :awardable, :snippet
  alias_method :spammable, :snippet

  def spammable_path
    snippet_path(@snippet)
  end

  def snippet_params
    params.require(:personal_snippet).permit(:title, :content, :file_name, :private, :visibility_level, :description).merge(spammable_params)
  end
end
