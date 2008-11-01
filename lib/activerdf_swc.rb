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
      
      # Fetch rdfs:seeAlso links related to the URIs in the triple
      see_also_query = Query.new.select(:x, :y).where(:x, RDFS::seeAlso, :y)
      fetch_see_also_results(super(see_also_query), uris)
    end
    
    test_query = Query.new
    triples.each { |t| t.each { |s| test_query.select(s) if s.kind_of? Symbol } }
    query.where_clauses.each { |w| test_query.where(w[0], w[1], w[2]) }
    results = super(test_query)
    results.each do |row|
      row.each do |column|
        fetch(column.uri) if column.respond_to? :uri
      end
    end
    
    super
  end
  
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
