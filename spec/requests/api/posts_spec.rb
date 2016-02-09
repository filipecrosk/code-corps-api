require "rails_helper"

describe "Posts API" do
  context "GET /projects/:id/posts" do
    context "when the project doesn't exist" do
      it "responds with a 404" do
        get "#{host}/projects/1/posts"
        expect(last_response.status).to eq 404
        expect(json).to be_a_valid_json_api_error.with_id "RECORD_NOT_FOUND"
      end
    end

    context "when successful" do
      before do
        @project = create(:project, organization: create(:organization))
        create_list(:post, 3, :published, project: @project, post_type: "issue")
        create_list(:post, 10, :published, project: @project, post_type: "task")
      end

      it "returns only published posts" do
        create_list(:post, 5, project: @project)
        get "#{host}/projects/#{@project.id}/posts"
        collection = Post.published.page(1).per(10)
        expect(json).to(
          serialize_collection(collection).
            with(PostSerializerWithoutIncludes).
            with_meta(total_records: 13, total_pages: 2, page_size: 10, current_page: 1)
        )
      end

      context "when no page is specified" do
        before do
          get "#{host}/projects/#{@project.id}/posts"
        end

        it "responds with a 200" do
          expect(last_response.status).to eq 200
        end

        it "returns the first page of 10 Post records, serialized with PostSerializerWithoutIncludes" do
          collection = Post.page(1).per(10)
          expect(json).to(
            serialize_collection(collection).
              with(PostSerializerWithoutIncludes).
              with_links_to("#{host}/projects/#{@project.id}/posts").
              with_meta(total_records: 13, total_pages: 2, page_size: 10, current_page: 1)
          )
        end
      end

      describe "specifying page parameters" do
        it "accepts different page numbers" do
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 1, size: 5 }}
          expect(json.data.length).to eq 5
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 3, size: 3 }}
          expect(json.data.length).to eq 3
        end

        it "accepts different page sizes" do
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 1, size: 3 }}
          expect(json.data.length).to eq 3
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 1, size: 4 }}
          expect(json.data.length).to eq 4
        end

        it "renders links in the response" do
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 2, size: 5 } }
          expect(json.links).not_to be_nil
          expect(json.links.self).not_to be_nil
          expect(json.links.first).not_to be_nil
          expect(json.links.prev).not_to be_nil
          expect(json.links.last).not_to be_nil
          expect(json.links.last).not_to be_nil
        end

        it "renders a meta in the response" do
          get "#{host}/projects/#{@project.id}/posts/", { page: { number: 2, size: 5 } }
          expect(json.meta).not_to be_nil
          expect(json.meta.total_records).to eq 13
          expect(json.meta.total_pages).to eq 3
          expect(json.meta.page_size).to eq 5
          expect(json.meta.current_page).to eq 2
        end
      end

      context "when 'post_type' parameter is specified" do
        it "only returns posts of that type, with proper meta" do
          get "#{host}/projects/#{@project.id}/posts", post_type: "issue"
          collection = Post.where(project: @project, post_type: "issue")
          expect(json).to serialize_collection(collection).
            with(PostSerializerWithoutIncludes).
            with_meta(total_records: 3, total_pages: 1, page_size: 10, current_page: 1)
        end
      end

      it "returns posts in order by number" do
        get "#{host}/projects/#{@project.id}/posts"

        numbers_array = json.data.map(&:attributes).map(&:number)

        expect(numbers_array).to eq [13, 12, 11, 10, 9, 8, 7, 6, 5, 4]
      end
    end
  end

  context "GET /projects/:project_id/posts/:number" do
    context "when the project doesn't exist" do
      it "responds with a 404" do
        get "#{host}/projects/1/posts/1"
        expect(last_response.status).to eq 404
        expect(json).to be_a_valid_json_api_error.with_id "RECORD_NOT_FOUND"
      end
    end

    context "when the post doesn't exist" do
      before do
        @project = create(:project, organization: create(:organization))
      end

      it "responds with a 404" do
        get "#{host}/projects/#{@project.id}/posts/1"
        expect(last_response.status).to eq 404
        expect(json).to be_a_valid_json_api_error.with_id "RECORD_NOT_FOUND"
      end
    end

    context "when successful" do
      before do
        @project = create(:project, organization: create(:organization))
        create(:user, username: "joshsmith")
        @post = create(:post, :published, project: @project, markdown: "Mentioning @joshsmith")
        create_list(:comment, 5, post: @post)
        get "#{host}/projects/#{@project.id}/posts/#{@post.number}"
      end

      it "responds with a 200" do
        expect(last_response.status).to eq 200
      end

      it "returns the post, serialized with PostSerializer, with users, comments and mentions included" do
        expect(json).to serialize_object(Post.last)
          .with(PostSerializer)
          .with_includes(["users", "comments", "post_user_mentions", "comment_user_mentions",
                          "comments_count"])
      end
    end
  end

  context "POST /posts" do
    context "when unauthenticated" do
      it "should return a 401 with a proper error" do
        post "#{host}/posts", { data: { type: "posts" } }
        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      before do
        @user = create(:user, email: "test_user@mail.com", password: "password")
        @organization = create(:organization)
        @project = create(:project, organization: @organization)
        create(:organization_membership, member: @user, organization: @organization, role: "contributor")
        @token = authenticate(email: "test_user@mail.com", password: "password")
      end

      it "requires a 'project' to be specified" do
        params = { data: { type: "posts", attributes: { title: "Post title", post_type: "issue" } } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 422
        expect(json).to be_a_valid_json_api_validation_error
      end

      it "requires a 'title' to be specified" do
        params = { data: { type: "posts",
          attributes: { post_type: "issue" },
          relationships: { project: { data: { id: @project.id } } }
        } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 422
        expect(json).to be_a_valid_json_api_validation_error
      end

      it "requires a 'body' to be specified" do
        params = { data: { type: "posts",
          attributes: { title: "Post title", post_type: "issue" },
          relationships: { project: { data: { id: @project.id } } }
        } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 422
        expect(json).to be_a_valid_json_api_validation_error
      end

      it "does not accept a 'number' to be set directly" do
        params = { data: { type: "posts",
          attributes: { title: "Post title", markdown: "Post body", number: 3 },
          relationships: { project: { data: { id: @project.id } } }
        } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 200

        expect(json.data.attributes.number).to eq nil
      end

      it "does not require a 'post_type' to be specified" do
        params = { data: { type: "posts",
          attributes: { title: "Post title", markdown: "Post body" },
          relationships: { project: { data: { id: @project.id } } }
        } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 200
      end

      it "ignores the 'status' parameter" do
        params = { data: { type: "posts",
          attributes: { title: "Post title", post_type: "issue", status: "closed", markdown: "Post body" },
          relationships: { project: { data: { id: @project.id } } }
        } }
        authenticated_post "/posts", params, @token

        expect(last_response.status).to eq 200
        expect(Post.last.open?).to be true
      end

      context "when it succeeds" do
        before do
          create(:project, id: 1)

          @mentioned_1 = create(:user)
          @mentioned_2 = create(:user)

          @params = { data: {
            type: "posts",
            attributes: {
              title: "Post title",
              markdown: "@#{@mentioned_1.username} @#{@mentioned_2.username}",
              post_type: "issue"
            },
            relationships: {
              project: { data: { id: @project.id, type: "projects" } }
            }
          } }
        end

        def make_request
           authenticated_post "/posts", @params, @token
        end

        def make_request_with_sidekiq_inline
          Sidekiq::Testing::inline! { make_request }
        end

        it "creates a draft post" do
          expect{ make_request }.to change{ Post.draft.count }.by 1

          post = Post.last
          expect(post.title).to eq "Post title"
          expect(post.body).to eq "<p>@#{@mentioned_1.username} @#{@mentioned_2.username}</p>"
          expect(post.issue?).to be true
        end

        it "returns the created post, serialized with PostSerializer" do
          make_request

          expect(json).to serialize_object(Post.last).with(PostSerializer)
        end

        it "sets user to current user" do
          make_request

          expect(Post.last.user_id).to eq @user.id
        end

        it "sets status to 'open'" do
          make_request

          expect(Post.last.open?).to be true
        end

        it "creates mentions" do
          expect{ make_request }.to change { PostUserMention.count }.by 2
        end

        it "doesn't create noficiations" do
          expect{ make_request_with_sidekiq_inline }.not_to change{ Notification.pending.count }
          expect{ make_request_with_sidekiq_inline }.not_to change{ Notification.sent.count }
        end

        it "doesn't send emails" do
          expect{ make_request_with_sidekiq_inline }.not_to change{ ActionMailer::Base.deliveries.count }
        end

        context "when type is set to 'published'" do
          before do
            @params[:data][:attributes][:state] = "published"
          end

          it "creates a published post" do
            expect{ make_request }.to change{ Post.published.count }.by 1
          end

          it "creates mentions" do
            expect{ make_request_with_sidekiq_inline }.to change { PostUserMention.count }.by 2
          end

          it "creates notifications for each mentioned user" do
            expect{ make_request_with_sidekiq_inline }.to change{ Notification.sent.count }.by 2
          end

          it "sends mails for each mentioned user" do
            expect{ make_request_with_sidekiq_inline }.to change{ ActionMailer::Base.deliveries.count }.by 2
          end
        end
      end
    end
  end

  context "PATCH /posts/:id" do
    context "when unauthenticated" do
      it "should return a 401 with a proper error" do
        patch "#{host}/posts/1", { data: { type: "posts" } }
        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      before do
        @user = create(:user, email: "test_user@mail.com", password: "password")
        @organization = create(:organization)
        @project = create(:project, organization: @organization)
        create(:organization_membership, member: @user, organization: @organization, role: "contributor")
        @token = authenticate(email: "test_user@mail.com", password: "password")
      end

      context "when the post doesn't exist" do
        it "responds with a 404" do
          authenticated_patch "/posts/1", { data: { type: "posts" } }, @token

          expect(last_response.status).to eq 404
          expect(json).to be_a_valid_json_api_error.with_id "RECORD_NOT_FOUND"
        end
      end

      context "when the post does exist" do
        before do
          @post = create(:post, project: @project, user: @user)
          @mentioned_1 = create(:user)
          @mentioned_2 = create(:user)
        end

        context "when the attributes are valid" do
          before do
            @params = { data: {
              attributes: { title: "Edited title", markdown: "@#{@mentioned_1.username} @#{@mentioned_2.username}" },
              relationships: { project: { data: { id: @project.id, type: "projects" } } }
            } }
          end

          def make_request
            authenticated_patch "/posts/#{@post.id}", @params, @token
          end

          def make_request_with_sidekiq_inline
            Sidekiq::Testing::inline! { make_request }
          end

          context "when updating a draft" do
            it "responds with a 200" do
              make_request
              expect(last_response.status).to eq 200
            end

            it "responds with the post, serialized with PostSerializer" do
              make_request
              expect(json).to serialize_object(@post.reload).with(PostSerializer)
            end

            it "updates the post" do
              make_request

              @post.reload

              expect(@post.title).to eq "Edited title"
              expect(@post.markdown).to eq "@#{@mentioned_1.username} @#{@mentioned_2.username}"
              expect(@post.body).to eq "<p>@#{@mentioned_1.username} @#{@mentioned_2.username}</p>"
            end

            it "creates mentions" do
              expect{ make_request }.to change { PostUserMention.count }.by 2
            end

            it "doesn't create noficiations" do
              expect{ make_request_with_sidekiq_inline }.not_to change{ Notification.pending.count }
              expect{ make_request_with_sidekiq_inline }.not_to change{ Notification.sent.count }
            end

            it "doesn't send emails" do
              expect{ make_request_with_sidekiq_inline }.not_to change{ ActionMailer::Base.deliveries.count }
            end
          end

          context "when editing a published post" do
            before do
              @post.publish!
            end

            it "updates the post" do
              make_request

              @post.reload
              expect(@post).to be_edited
            end

            it "creates mentions" do
              expect{ make_request_with_sidekiq_inline }.to change { PostUserMention.count }.by 2
            end

            it "creates notifications for each mentioned user" do
              expect{ make_request_with_sidekiq_inline }.to change{ Notification.sent.count }.by 2
            end

            it "sends mails for each mentioned user" do
              expect{ make_request_with_sidekiq_inline }.to change{ ActionMailer::Base.deliveries.count }.by 2
            end
          end
        end

        context "when the attributes are invalid" do
          before do
            invalid_attributes = {
              data: {
                attributes: {
                  title: "", markdown: ""
                },
                relationships: {
                  project: { data: { id: @project.id, type: "projects" } }
                }
              }
            }
            authenticated_patch "/posts/#{@post.id}", invalid_attributes, @token
          end

          it "responds with a 422 validation error" do
            expect(last_response.status).to eq 422
            expect(json).to be_a_valid_json_api_validation_error
          end
        end
      end
    end
  end

  context "POST /posts" do
    context "when unauthenticated" do
      it "responds with a proper 401" do
        post "#{host}/posts", data: { type: "posts" }
        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      let(:user) { create :user, password: "password" }
      let(:organization) { create :organization }
      let(:project) { create :project, organization: organization }
      let(:token) { authenticate email: user.email, password: "password" }

      before do
        create(
          :organization_membership,
          member: user, organization: organization, role: "contributor")
      end

      context "when requesting a preview" do
        it "creates a draft with _preview fields present, actual fields empty"
      end

      context "when requesting an actual save" do
        it "creates a published post with all fields present"
      end
    end
  end

  context "PATCH /posts/:id" do
    let(:user) { create :user, password: "password" }
    let(:organization) { create :organization }
    let(:project) { create :project, organization: organization }
    let(:post) { create :post, user: user, project: project, state: :draft }

    context "when unauthenticated" do
      it "responds with a proper 401" do
        patch "#{host}/posts/#{post.id}"
        expect(last_response.status).to eq 401
        expect(json).to be_a_valid_json_api_error.with_id "NOT_AUTHORIZED"
      end
    end

    context "when authenticated" do
      let(:token) { authenticate email: user.email, password: "password" }

      before do
        create(
          :organization_membership,
          member: user, organization: organization, role: "contributor")
      end

      context "when post is a draft" do
        context "when requesting a preview" do
          it "updates _preview fields, doesn't touch actual fields or number"
        end

        context "when requesting an actual save" do
          it "updates all fields, including number"
        end
      end

      context "when post is published" do
        before do
          post.publish!
        end

        context "when requesting a preview" do
          it "updates _preview fields, doesn't touch actual fields or number"
        end

        context "when requesting an actual save" do
          it "updates all fields, except number"
        end
      end
    end
  end
end
