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

FactoryGirl.define do

  factory :comment do
    sequence(:markdown) { |n| "Comment #{n}" }
    sequence(:markdown_preview) { |n| "Comment #{n}" }

    association :post
    association :user

    trait :draft do
      aasm_state :draft
      markdown nil
      body nil
      markdown_preview "Comment content"
      body_preview "Comment content"
    end

    trait :published do
      aasm_state :published
      markdown "Comment content"
      body "Comment content"
      markdown_preview "Comment content"
      body_preview "Comment content"
    end

    trait :edited do
      aasm_state :edited
      markdown "Comment content"
      body "Comment content"
      markdown_preview "Comment content"
      body_preview "Comment content"
    end

    trait :with_user_mentions do
      transient do
        mention_count 5
      end

      after :create do |comment, evaluator|
        create_list(:comment_user_mention, evaluator.mention_count, comment: comment)
      end
    end
  end

end
