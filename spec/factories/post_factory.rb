# == Schema Information
#
# Table name: posts
#
#  id               :integer          not null, primary key
#  status           :string           default("open")
#  post_type        :string           default("task")
#  title            :string           not null
#  body             :text             not null
#  user_id          :integer          not null
#  project_id       :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  post_likes_count :integer          default(0)
#  markdown         :text             not null
#  number           :integer
#  aasm_state       :string
#

FactoryGirl.define do

  factory :post do
    sequence(:title) { |n| "Post #{n}" }
    sequence(:markdown) { |n| "Post content #{n}" }
    sequence(:markdown_preview) { |n| "Post content #{n}" }
    sequence(:body) { |n| "<p>Post content #{n}</p>" }
    sequence(:body_preview) { |n| "<p>Post content #{n}</p>" }

    association :user
    association :project

    trait :draft do
      aasm_state :draft
      markdown nil
      body nil
      markdown_preview "Post content"
      body_preview "Post content"
    end

    trait :published do
      aasm_state :published
      markdown "Post content"
      body "Post content"
      markdown_preview "Post content"
      body_preview "Post content"
    end

    trait :edited do
      aasm_state :edited
      markdown "Post content"
      body "Post content"
      markdown_preview "Post content"
      body_preview "Post content"
    end

    trait :with_user_mentions do
      transient do
        mention_count 5
      end

      after :create do |post, evaluator|
        create_list(:post_user_mention, evaluator.mention_count, post: post)
      end
    end

    trait :with_number do
      sequence(:number) { |n| n }
    end
  end

end
