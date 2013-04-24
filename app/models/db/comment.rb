module Db
  class Comment < ActiveRecord::Base
    attr_accessible :post
    belongs_to :post
  end
end
