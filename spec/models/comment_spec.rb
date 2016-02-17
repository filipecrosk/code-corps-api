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

require 'rails_helper'

describe Comment, :type => :model do
  describe "schema" do
    it { should have_db_column(:body).of_type(:text).with_options(null: true) }
    it { should have_db_column(:markdown).of_type(:text).with_options(null: true) }
    it { should have_db_column(:body_preview).of_type(:text).with_options(null: true) }
    it { should have_db_column(:markdown_preview).of_type(:text).with_options(null: true) }
    it { should have_db_column(:post_id).of_type(:integer) }
    it { should have_db_column(:user_id).of_type(:integer) }
    it { should have_db_column(:updated_at) }
    it { should have_db_column(:created_at) }
    it { should have_db_column(:aasm_state).of_type(:string) }
  end

  describe "relationships" do
    it { should belong_to(:post).counter_cache true }
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:post) }
    it { should validate_presence_of(:body) }
    it { should validate_presence_of(:markdown) }
  end

  describe "state machine" do
    let(:post) { Post.new }

    it "sets the state to draft initially" do
      expect(post).to have_state(:draft)
    end

    it "transitions correctly" do
      expect(post).to transition_from(:draft).to(:published).on_event(:publish)
    end
  end

  describe ".state" do
    it "should return the aasm_state" do
      comment = create(:comment)
      expect(comment.state).to eq comment.aasm_state
    end
  end

  describe ".edited_at" do
    context "when the comment hasn't been edited" do
      it "returns nil" do
        comment = create(:comment)
        expect(comment.edited_at).to eq nil
      end
    end

    context "when the comment has been edited" do
      it "returns the updated_at timestamp" do
        comment = create(:comment)
        comment.publish
        comment.edit

        expect(comment.edited_at).to eq comment.updated_at
      end
    end
  end

  describe "#update" do
    it "renders markdown_preview to body_preview" do
      comment = create(:comment, markdown_preview: "# Hello World\n\nHello, world.")
      comment.update
      expect(comment.body_preview).to eq "<h1>Hello World</h1>\n\n<p>Hello, world.</p>"
    end

    context "when previewing" do
      it "should just save a draft comment" do
        comment = create(:comment, :draft)
        expect(comment.update(false)).to be true

        expect(comment.draft?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).to be_nil
        expect(comment.body).to be_nil
      end

      it "should just save a published comment" do
        comment = create(:comment, :published)
        expect(comment.update(false)).to be true

        expect(comment.published?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).not_to be_nil
        expect(comment.body).not_to be_nil
      end

      it "should just save an edited comment" do
        comment = create(:comment, :edited)
        expect(comment.update(false)).to be true

        expect(comment.edited?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).not_to be_nil
        expect(comment.body).not_to be_nil
      end
    end

    context "when publishing" do
      it "publishes a draft comment" do
        comment = create(:comment, :draft)
        expect(comment.update(true)).to be true

        expect(comment.published?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).not_to be_nil
        expect(comment.body).not_to be_nil
      end

      it "just saves a published comment, sets it to edited state" do
        comment = create(:comment, :published)
        expect(comment.update(true)).to be true

        expect(comment.edited?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).not_to be_nil
        expect(comment.body).not_to be_nil
      end

      it "just saves an edited comment" do
        comment = create(:comment, :edited)
        expect(comment.update(true)).to be true

        expect(comment.edited?).to be true
        expect(comment.markdown_preview).not_to be_nil
        expect(comment.body_preview).not_to be_nil
        expect(comment.markdown).not_to be_nil
        expect(comment.body).not_to be_nil
      end
    end
  end

  describe "publishing" do
    let(:comment) { create(:comment) }

    it "publishes when state is set to 'published'" do
      comment.state = "published"
      comment.save

      expect(comment).to be_published
    end
  end

  describe "user mentions" do
    context "when updating a comment" do
      it "creates mentions only for existing users" do
        real_user = create(:user, username: "joshsmith")

        comment = create(:comment, markdown_preview: "Hello @joshsmith and @someone_who_doesnt_exist")

        comment.update
        comment.reload
        mentions = comment.comment_user_mentions

        expect(mentions.count).to eq 1
        expect(mentions.first.user).to eq real_user
      end

      context "when usernames contain underscores" do
        it "creates mentions and not <em> tags" do
          underscored_user = create(:user, username: "a_real_username")

          comment = create(:comment, markdown_preview: "Hello @a_real_username and @not_a_real_username")

          comment.update
          comment.reload
          mentions = comment.comment_user_mentions

          expect(mentions.count).to eq 1
          expect(mentions.first.user).to eq underscored_user
        end
      end
    end
  end
end
