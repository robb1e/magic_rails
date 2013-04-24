class Post
  attr_reader :id

  def initialize args
    @id = args[:id]
  end

  def comments
    Comments.new(post_id: id)
  end

  private
  def model
    @model ||= Db::Post.find(id)
  end
end
