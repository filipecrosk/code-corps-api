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

require "rails_helper"

describe Post, type: :model do
  describe "schema" do
    it { should have_db_column(:status).of_type(:string) }
    it { should have_db_column(:post_type).of_type(:string) }
    it { should have_db_column(:title).of_type(:string).with_options(null: true) }
    it { should have_db_column(:body).of_type(:text).with_options(null: true) }
    it { should have_db_column(:markdown).of_type(:text).with_options(null: true) }
    it { should have_db_column(:body_preview).of_type(:text).with_options(null: true) }
    it { should have_db_column(:markdown_preview).of_type(:text).with_options(null: true) }
    it { should have_db_column(:project_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:user_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:updated_at) }
    it { should have_db_column(:created_at) }
    it { should have_db_column(:post_likes_count).of_type(:integer) }
    it { should have_db_column(:aasm_state).of_type(:string) }
    it { should have_db_column(:comments_count).of_type(:integer) }
  end

  describe "relationships" do
    it { should have_many(:comments) }
    it { should belong_to(:project) }
    it { should belong_to(:user) }
    it { should have_many(:post_likes) }
    it { should have_many(:post_user_mentions) }
    it { should have_many(:comment_user_mentions) }
  end

  describe "validations" do
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:project) }

    context "title" do
      context "when post is a draft" do
        let(:subject) { create(:post, :draft) }
        it { should_not validate_presence_of(:title) }
      end

      context "when the post is published" do
        let(:subject) { create(:post, :published) }
        it { should validate_presence_of(:title) }
      end

      context "when the post is edited" do
        let(:subject) { create(:post, :edited) }
        it { should validate_presence_of(:title) }
      end
    end

    it { should validate_presence_of(:post_type) }

    context "number" do
      let(:subject) { create(:post) }
      it { should validate_uniqueness_of(:number).scoped_to(:project_id).allow_nil }
    end

    # no sense in testing body or body_preview validations, since the markdown
    # rendering hook will ensure at least body_preview is always present

    context "markdown" do
      context "when markdown_preview has a value" do
        let(:subject) { build(:post, markdown_preview: "Something") }
        it { should_not validate_presence_of(:markdown) }
      end

      context "when markdown_preview has no value" do
        let(:subject) { build(:post, markdown_preview: nil) }
        it { should validate_presence_of(:markdown) }
      end
    end

    context "markdown_preview" do
      context "when markdown has a value" do
        let(:subject) { build(:post, markdown: "Something") }
        it { should_not validate_presence_of(:markdown_preview) }
      end

      context "when markdown has no value" do
        let(:subject) { build(:post, markdown: nil) }
        it { should validate_presence_of(:markdown_preview) }
      end
    end
  end

  describe "behavior" do
    it { should define_enum_for(:status).with({ open: "open", closed: "closed" }) }
    it { should define_enum_for(:post_type).with({ idea: "idea", progress: "progress", task: "task", issue: "issue" }) }
  end

  describe ".state" do
    it "should return the aasm_state" do
      post = create(:post)
      expect(post.state).to eq post.aasm_state
    end
  end

  describe ".edited_at" do
    context "when the post hasn't been edited" do
      it "returns nil" do
        post = create(:post)
        expect(post.edited_at).to eq nil
      end
    end

    context "when the post has been edited" do
      it "returns the updated_at timestamp" do
        post = create(:post)
        post.publish
        post.edit

        expect(post.edited_at).to eq post.updated_at
      end
    end
  end

  describe ".post_like_counts" do
    let(:user) { create(:user) }
    let(:post) { create(:post) }

    context "when there is no PostLike" do
      it "should have the correct counter cache" do
        expect(post.likes_count).to eq 0
      end
    end

    context "when there is a PostLike" do
      it "should have the correct counter cache" do
        create(:post_like, user: user, post: post)
        expect(post.likes_count).to eq 1
      end
    end
  end

  describe "before_validation" do
    it "converts markdown_preview to html for body_preview" do
      post = create(:post, markdown_preview: "# Hello World\n\nHello, world.")
      post.save

      post.reload
      expect(post.body_preview).to eq "<h1>Hello World</h1>\n\n<p>Hello, world.</p>"
    end
  end

  describe "sequencing" do
    context "when a draft" do
      it "does not number the post" do
        project = create(:project)
        first_post = create(:post, project: project)

        expect(first_post.number).to be_nil
      end
    end

    context "when published with bang (auto-save) methods" do
      it "numbers posts for each project" do
        project = create(:project)
        first_post = create(:post, project: project)
        second_post = create(:post, project: project)
        first_post.publish!
        second_post.publish!

        expect(first_post.number).to eq 1
        expect(second_post.number).to eq 2
      end

      it "should not allow a duplicate number to be set for the same project" do
        project = create(:project)
        first_post = create(:post, project: project)
        first_post.publish!

        expect { create(:post, project: project, number: 1) }.to raise_error ActiveRecord::RecordInvalid
      end
    end
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

  describe "#update" do
    context "when previewing" do
      it "should just save a draft post" do
        post = create(:post, :draft)
        post.update(false)

        expect(post.draft?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).to be_nil
        expect(post.body).to be_nil
      end

      it "should just save a published post" do
        post = create(:post, :published)
        post.update(false)

        expect(post.published?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).not_to be_nil
        expect(post.body).not_to be_nil
      end

      it "should just save an edited post" do
        post = create(:post, :edited)
        post.update(false)

        expect(post.edited?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).not_to be_nil
        expect(post.body).not_to be_nil
      end
    end

    context "when publishing" do
      it "publishes a draft post" do
        post = create(:post, :draft)
        post.update(true)

        expect(post.published?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).not_to be_nil
        expect(post.body).not_to be_nil
      end

      it "just saves a published post, sets it to edited state" do
        post = create(:post, :published)
        post.update(true)

        expect(post.edited?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).not_to be_nil
        expect(post.body).not_to be_nil
      end

      it "just saves an edited post" do
        post = create(:post, :edited)
        post.update(true)

        expect(post.edited?).to be true
        expect(post.markdown_preview).not_to be_nil
        expect(post.body_preview).not_to be_nil
        expect(post.markdown).not_to be_nil
        expect(post.body).not_to be_nil
      end
    end
  end

  describe "publishing" do
    let(:post) { create(:post) }

    it "publishes when state is set to 'published'" do
      post.state = "published"
      post.save

      expect(post).to be_published
    end
  end

  describe "default_scope" do
    it "orders by number by default" do
      create_list(:post, 3, :published, :with_number)
      posts = Post.all
      expect(posts.map(&:number)).to eq [3, 2, 1]
    end
  end

  describe "post user mentions" do
    context "when saving a post" do
      it "creates mentions only for existing users" do
        real_user = create(:user, username: "joshsmith")

        post = Post.create(
          project: create(:project),
          user: create(:user),
          markdown_preview: "Hello @joshsmith and @someone_who_doesnt_exist",
          title: "Test"
        )

        post.reload
        mentions = post.post_user_mentions

        expect(mentions.count).to eq 1
        expect(mentions.first.user).to eq real_user
      end

      context "when usernames contain underscores" do
        it "creates mentions and not <em> tags" do
          underscored_user = create(:user, username: "a_real_username")

          post = Post.create(
            project: create(:project),
            user: create(:user),
            markdown_preview: "Hello @a_real_username and @not_a_real_username",
            title: "Test"
          )

          post.reload
          mentions = post.post_user_mentions

          expect(mentions.count).to eq 1
          expect(mentions.first.user).to eq underscored_user
        end
      end
    end
  end
end
