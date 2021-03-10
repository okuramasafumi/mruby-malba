##
## Malba Test
##

module MalbaTest
  class User
    attr_reader :id
    attr_accessor :articles, :profile

    def initialize(id)
      @id = id
      @articles = []
    end
  end

  class Profile
    attr_accessor :user_id, :email, :first_name, :last_name

    def initialize(user_id, email, first_name, last_name)
      @user_id = user_id
      @email = email
      @first_name = first_name
      @last_name = last_name
    end
  end


  class Article
    attr_accessor :id, :user_id, :title, :body

    def initialize(id, user_id, title, body)
      @id = id
      @user_id = user_id
      @title = title
      @body = body
    end
  end

  class UserSerializer
    include Malba::Serializer
    set key: :user
  end

  class ProfileResource
    include Malba::Resource

    attributes :email

    attribute :full_name do |profile|
      if params[:profile_full_name_with_comma]
        "#{profile.first_name}, #{profile.last_name}"
      else
        "#{profile.first_name} #{profile.last_name}"
      end
    end
  end

  class ArticleResource
    include Malba::Resource

    attributes :title, :body
  end

  class UserResource
    include Malba::Resource

    serializer UserSerializer

    attributes :id

    one :profile, resource: ProfileResource
    many :articles, resource: ArticleResource
  end

  class UserResourceWithParams
    include Malba::Resource
    serializer UserSerializer

    attributes :id

    attribute :logging_in do |user|
      user.id == params[:current_user_id]
    end

    one :profile, resource: ProfileResource
    many :articles,
      proc { |articles, params| articles.select { |a| params[:article_ids].include?(a.id) } },
      resource: ArticleResource
  end

  class SimpleProfileResource < ProfileResource
    ignoring :full_name
  end
end

assert('Malba.serialize') do
  user = MalbaTest::User.new(1)
  article = MalbaTest::Article.new(1, 1, 'Hello World!', 'Hello World!!!')
  user.articles = [article]
  assert_equal(
    '{"id":1,"articles":[{"title":"Hello World!","body":"Hello World!!!"}]}',
    Malba.serialize(user) do
      attributes :id
      many :articles do
        attributes :title, :body
      end
    end
  )
end

assert('Malba associations') do
  user = MalbaTest::User.new(1)
  profile = MalbaTest::Profile.new(1, 'test@example.com', 'Masafumi', 'Okura')
  user.profile = profile
  article = MalbaTest::Article.new(1, 1, 'Hello World!', 'Hello World!!!')
  user.articles = [article]
  assert_equal(
    '{"user":{"id":1,"profile":{"email":"test@example.com","full_name":"Masafumi Okura"},"articles":[{"title":"Hello World!","body":"Hello World!!!"}]}}',
    MalbaTest::UserResource.new(user).serialize
  )
end

assert('Malba params') do
  user = MalbaTest::User.new(1)
  profile = MalbaTest::Profile.new(1, 'test@example.com', 'Masafumi', 'Okura')
  user.profile = profile
  article = MalbaTest::Article.new(1, 1, 'Hello World!', 'Hello World!!!')
  user.articles = [article]
  assert_equal(
    '{"user":{"id":1,"logging_in":true,"profile":{"email":"test@example.com","full_name":"Masafumi, Okura"},"articles":[]}}',
    MalbaTest::UserResourceWithParams.new(user, params: {profile_full_name_with_comma: true, article_ids: [2], current_user_id: 1}).serialize
  )
end

assert('Malba ignoring') do
  profile = MalbaTest::Profile.new(1, 'test@example.com', 'Masafumi ', 'Okura')
  assert_equal '{"email":"test@example.com"}', MalbaTest::SimpleProfileResource.new(profile).serialize
end

assert('Malba collection') do
  profile1 = MalbaTest::Profile.new(1, 'test@example.com', 'Masafumi ', 'Okura')
  profile2 = MalbaTest::Profile.new(2, 'test@example.org', 'John ', 'Doe')
  assert_equal '[{"email":"test@example.com"},{"email":"test@example.org"}]', MalbaTest::SimpleProfileResource.new([profile1, profile2]).serialize
end
