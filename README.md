# Magic Rails

It's easy to take for granted all of the things that Rails gives to those whom use it. There are layers upon layers of well tested, battle hardened code at the developers disposal and it took a conversation about the pros and cons of different languages to use when teaching software development to give me some perspective on how much both Ruby and Rails does for us everyday.  Ruby hides complexity in a way that a seasoned developer can appreciate where it appears like magic to a newbie and I wonder if a parallel can be made with Rails.  Is it possible that without having built N-tier architected systems with multiple layers of serialisation, without having to deal with the details of HTTP and the request/response cycle that a developer who has only had Rails experience cannot see what the Rails libraries is abstracting us from?  

I've seen a number of Rails codebases and while each is a unique snowflake, one thing many have in common is the ability to allow Rails and it's associated libraries to impose itself upon the design of the application.  I wanted to take a step back, identify some of the things which give me most greivences and offer an alternative approach.  I also wanted to show just how much Rails gives a developer by demonstrating side by side comparisons of an alternative to data modelling. 

## Queries should be done in the model only

Extending `ActiveRecord::Base` leaks a powerful API throughout an application which can lead to tempting code which break good design. Take the classic blog example where you may want to retreive the latest posts by a given author.  You may have seen, or even written code that gets the dataset you need straight into the controller or view:

    Post.where(author: author_id).limit(20).order("created_at DESC").each { ... }
    
For me this is a design violation as well as breaking the "Law of Demeter". The example above tells me structure of the schema that the calling class has no business knowing. It also makes testing using stubs ugly and encourages testing against the database directly. A test would have to chain three methods to stub a return value. It's brittle, as in it's susectible to breaking due to changes outside of the class.  For me it also fails from a narative perspective in that it doesn't susinctly reveal the intent of this part of the application.

I'd much rather see that as a message to the `Post` class.

	def self.latest_for_author id
	  where(author: id).limit(20).order("created_at DESC")
	end
	
	Post.latest_for_author(1)
	
If there were variations of the limit and perhaps offset, they can be passed as option parameters of as an options hash:

	def self.latest_for_author id, limit = 20, offset = 0
	  where(author: id).limit(limit).offset(offset).order("created_at DESC")
	end
	
	Post.latest_for_author(1)
	Post.latest_for_author(1, 20, 0)
	
or

	def self.latest_for_author id, options
	  limit = options[:limit] || 20
	  offset = options[:offset] || 0
	  where(author: id).limit(limit).offset(offset).order("created_at DESC")
	end
	
	Post.latest_for_author(1, offset: 20)
	
In order to get the dataset the call looks like the following, and I think is more informative than using the ActiveRecord DSL	.

    Post.latest_for_author(author_id).each { ... }
    
Testing is also easier, as it puts more emphasis on the messages being sent to objects rather than a chain of calls having to be correct.

	Post.should_receive(:latest_for_author).with(1) { posts }
    
There are a few advantages to this refactor:

- Only the `Post` class knows about the schema
- Any changes to the implementation of what `latest_for_author` are encapsulated in one place
- The method describes the intent more than the implementation
- Stubbing in the tests are easier as there is one clear dependency of a method chain

One further refactor could be done here, and that is to move the query logic out of the Post class once more, but this time into a purpose built query Object:

    LatestPosts.new(author).each { ... }

Here's what [Bryan Helmkamp has to say on query objects](http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/) in his excellent write up on fat ActiveRecord models. Bryan here rightfully points out that once in a purpose object, they warrant little attention to unit testing. Now is the right time to use the database to ensure the right data set is being returned and that N+1 queries are not being performed. 


## APIs should not expose the database

When the only consumer of an applications data model is the applications views then the design is fluid and maleable. Once an application exposes an API to more than one client, and especially if that client is on a different release cycle to the server, such as iPhone application, data models become rigid. Rails discourages N-tier architecture to the benefit of development speed but APIs are contracts between a server and it's client and can be difficult to change. Relying on the default JSON serialisation of an object will only get you so far. At some point a refactor will take place that will cause a breaking change. It could be something simple such as renaming a column, or moving responsibilities from one class to another. 

There are a few ways out of this potential issue. Let's take another look at the `Post` object. The Rails rendering engine will call `as_json` on an object if the request has sent the `content-type` of `application\json` to the server.  Here we override the implementation in `ActiveRecord` to provide a stable, known version:

	def as_json(options={})
		{
			author_id: author.id
			title: title
		}
	end
	
A second option is to model the object explictly and serialise the internal model into a public representation:

	class Api::Post
	  attr_reader :post
	  
	  def initialize(post)
	    @post = post
	  end
	  
	  def as_json(options={})
	    {
	      author_id: post.author.id
	      title: post.title
	    }
	  end
	end
	
The benefit of doing this is a seperation of concerns. An application model doesn't need to know how it'll be represented by an API, command line interface or any other outside communication mechanism. You may lose some of the Rails `respond_with` goodness with this, but that in turn be hidden away by a presenter object:

	respond_to :html, :json

	def show
	  post = Post.find(params[:id])
	  @presenter = PostPresenter.new(post)
	  respond_with @presenter
	end
	
Where `PostPresenter` may look something like:

	class PostPresenter < SimpleDelegator
	  def as_json(options={})
	    Api::Post.new(self).as_json(options)
	  end
	end
	
## URI paths should not include a version

I don't like seeing routes like `/api/v1/posts` and from what we've seen above, we can get rid of some of the issues here. 

## Using partials like a boss by using view classes

#Quotes

[James Hunt - "Rails gives you so much that deliberately not using it feels like shooting yourself in the foot"](http://ohthatjames.github.io/2012/06/17/rails-without-rails/)

[Corey Hains - "Test-driven development is a major player in keeping your design malleable and accepting of new features, but when you stop paying attention to the messages your tests are sending you, you lose this benefit."](http://confreaks.com/videos/641-gogaruco2011-fast-rails-tests)

