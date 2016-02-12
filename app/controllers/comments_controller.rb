# == Schema Information
#
# Table name: comments
#
#  id         :integer          not null, primary key
#  body       :text             not null
#  user_id    :integer          not null
#  post_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  markdown   :text             not null
#  aasm_state :string
#

class CommentsController < ApplicationController
  before_action :doorkeeper_authorize!, only: [:create, :update]

  def index
    comments = Comment.where(post: params[:post_id]).includes(:user, :post)
    authorize comments

    render json: comments
  end

  def show
    comment = Comment.find(params[:id])

    authorize comment

    render json: comment
  end

  def create
    comment = Comment.new(create_params)

    authorize comment

    if comment.update publish?
      GenerateCommentUserNotificationsWorker.perform_async(comment.id) if publish?
      render json: comment
    else
      render_validation_errors comment.errors
    end
  end

  def update
    comment = Comment.find(params[:id])

    authorize comment

    comment.assign_attributes(update_params)

    if comment.update publish?
      GenerateCommentUserNotificationsWorker.perform_async(comment.id) if publish?
      render json: comment
    else
      render_validation_errors comment.errors
    end
  end

  private
    def publish?
      true unless record_attributes.fetch(:preview, false)
    end

    def create_params
      record_attributes.permit(:markdown_preview).merge(relationships)
    end

    def update_params
      record_attributes.permit(:markdown_preview)
    end

    def post_id
      record_relationships.fetch(:post, {}).fetch(:data, {})[:id]
    end

    def user_id
      current_user.id
    end

    def relationships
      { post_id: post_id, user_id: user_id }
    end
end
