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

class CommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :body_preview, :markdown, :markdown_preview, :state, :edited_at

  belongs_to :post
  belongs_to :user
end
