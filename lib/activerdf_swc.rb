require 'rubygems'
require 'active_rdf'

class SWCAdapter < FetchingAdapter
  ConnectionPool.register_adapter(:swc, self)
  
  def initialize(params={})
    @uris_retrieved = []
    @max_steps = params[:max_steps] || 1
    super
    # hack to keep data cached between runs...
    if (@db)
      @db.execute('select distinct c from triple').flatten.each { |u| @uris_retrieved << $1 if u =~ /<(.*?)>/ }
    end
  end
  
  def query(query, &block)
    # Split SPARQL queries into a set of triple patterns
    triples = query_to_triples(query)
    
    triples.each do |triple|
      # Dereference and fetch URIs in each triple      
      uris = triple.map { |r| r.respond_to?(:uri) ? r.uri : nil }.compact
      uris.each { |uri| fetch(uri) }
      
      # Follow rdfs:seeAlso links related to the URIs in the triple
      see_also_query = Query.new.select(:x, :y).where(:x, RDFS::seeAlso, :y)
      # 2) Add retrieved graphs to the local graph set.
      fetch_see_also_results(super(see_also_query), uris)
    end
    
    triples.each do |triple|
      # 3) match the triple pattern against all graphs in the local graph set
      triple_query = Query.new.select.where(triple[0],triple[1],triple[2])
      triple.each { |r| triple_query.select(r) if r.kind_of? Symbol }

      steps = 0
      while (steps<@max_steps)
        steps+=1
        triple_results = super(triple_query)
        # 4) for each triple that matches the triple pattern
        triple_results.each do |result|
          # 4) look up all new URIs that appear in the triple. Add retrieved graphs to the local graph set.
          result.each { |r| p [r.class, r]; fetch(r.uri) if r.respond_to? :uri }
        end

        # Look up any new URI y where the graph set includes the triple { x rdfs:seeAlso y } and x is a URI from a matching triple.
        # Add retrieved graphs to the local graph set.
        fetch_see_also_results(super(see_also_query), uris)
      end
    end

    super
  end
  
  # def query(query, &block)
  #   # Split SPARQL queries into a set of triple patterns
  #   triples = query_to_triples(query)
  #   puts '##########################'
  #   triples.each do |triple|
  #     puts '----------------------'
  #     puts "triple: #{triple.inspect}"
  #     # 1) look up URIs that appear in the triple pattern
  #     uris = triple.map { |r| r.respond_to?(:uri) ? r.uri : nil }.compact
  #     next if uris.empty?
  #     puts "triple uris: #{uris.inspect}"
  #     # 1) Add retrieved graphs to the local graph set.
  #     uris.each { |uri| fetch(uri) }
  #     
  #     # 2) look up any URI y where the graph set includes the triple { x rdfs:seeAlso y } and x is a URI from the triple pattern.
  #     see_also_query = Query.new.select(:x, :y).where(:x, RDFS::seeAlso, :y)
  #     # 2) Add retrieved graphs to the local graph set.
  #     fetch_see_also_results(super(see_also_query), uris)
  # 
  #     # 3) match the triple pattern against all graphs in the local graph set
  #     triple_query = Query.new.select.where(triple[0],triple[1],triple[2])
  #     triple.each { |r| triple_query.select(r) if r.kind_of? Symbol }
  #     
  #     steps = 0
  #     while (steps<@max_steps)
  #       steps+=1
  #       triple_results = super(triple_query)
  #       # 4) for each triple that matches the triple pattern
  #       triple_results.each do |result|
  #         # 4) look up all new URIs that appear in the triple. Add retrieved graphs to the local graph set.
  #         result.each { |r| p [r.class, r]; fetch(r.uri) if r.respond_to? :uri }
  #       end
  #       
  #       # Look up any new URI y where the graph set includes the triple { x rdfs:seeAlso y } and x is a URI from a matching triple.
  #       # Add retrieved graphs to the local graph set.
  #       fetch_see_also_results(super(see_also_query), uris)
  #     end
  #   end
  #   super
  # end
  
  def fetch(uri)
    return if uri =~ %r[http://www.activerdf.org/bnode/]
    uri = $1 if uri =~ /(.*?)\#.*/
    puts "-> #{uri}"
    return if @uris_retrieved.include? uri
    super
    @uris_retrieved << uri 
  end
  
  private
  
  def fetch_see_also_results(results, uris)
    return if uris.empty?
    results.each do |r|
      x, y = r.first.uri, r.last.uri
      fetch(y) if uris.include? x
    end
  end
  
  def query_to_triples(query)
    query.where_clauses
  end
end
