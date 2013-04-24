class Comments
  include Enumerable

  attr_reader :post_id

  def initialize args
    @post_id = args[:post_id]
  end

  def each(&block)
    Db::Comment.where(post_id: post_id).each do |comment|
      block.call(Comment.new(comment))
    end
  end

end
